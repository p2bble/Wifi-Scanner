import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:wifi_scan/wifi_scan.dart';
import '../models/wifi_data.dart';
import '../models/network_quality.dart';

class WifiService {
  final _networkInfo = NetworkInfo();

  Future<List<ApInfo>> scanAccessPoints() async {
    if (kIsWeb || !Platform.isAndroid) return [];

    final can = await WiFiScan.instance.canStartScan(askPermissions: true);
    if (can != CanStartScan.yes) return [];

    await WiFiScan.instance.startScan();
    await Future.delayed(const Duration(seconds: 2));

    final results = await WiFiScan.instance.getScannedResults();
    return results.map((r) => ApInfo(
      ssid: r.ssid.isEmpty ? '(숨겨진 네트워크)' : r.ssid,
      bssid: r.bssid,
      rssi: r.level,
      frequency: r.frequency,
      capabilities: r.capabilities,
    )).toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
  }

  Future<String> getCurrentBssid() async {
    if (kIsWeb || !Platform.isAndroid) return '';
    try {
      return await _networkInfo.getWifiBSSID() ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<ConnectedNetworkInfo?> getConnectedInfo() async {
    try {
      final ssid = await _networkInfo.getWifiName() ?? '';
      final bssid = await _networkInfo.getWifiBSSID() ?? '';
      final ip = await _networkInfo.getWifiIP() ?? '';
      final gateway = await _networkInfo.getWifiGatewayIP() ?? '';

      return ConnectedNetworkInfo(
        ssid: ssid.replaceAll('"', ''),
        bssid: bssid,
        ipAddress: ip,
        gateway: gateway,
      );
    } catch (_) {
      return null;
    }
  }

  // 게이트웨이: TCP 소켓, 인터넷: HTTP HEAD 요청
  Future<int?> pingGateway(String gateway) async {
    if (gateway.isEmpty) return null;
    try {
      final stopwatch = Stopwatch()..start();
      final socket = await Socket.connect(
        gateway, 80,
        timeout: const Duration(seconds: 3),
      );
      stopwatch.stop();
      socket.destroy();
      return stopwatch.elapsedMilliseconds;
    } catch (_) {}
    // TCP 80 실패 시 DNS lookup으로 폴백
    try {
      final stopwatch = Stopwatch()..start();
      await InternetAddress.lookup(gateway)
          .timeout(const Duration(seconds: 3));
      stopwatch.stop();
      return stopwatch.elapsedMilliseconds;
    } catch (_) {}
    return null;
  }

  Future<int?> pingInternet() async {
    // Google generate_204 — 빠르고 ICMP/방화벽 영향 없음
    const testUrl = 'http://clients3.google.com/generate_204';
    try {
      final stopwatch = Stopwatch()..start();
      final response = await http
          .head(Uri.parse(testUrl))
          .timeout(const Duration(seconds: 5));
      stopwatch.stop();
      if (response.statusCode == 204 || response.statusCode == 200) {
        return stopwatch.elapsedMilliseconds;
      }
    } catch (_) {}
    return null;
  }

  // 단일 TCP 연결 측정 — 폴백 없음 (패킷 손실 판별 목적)
  Future<int?> _pingTcp(String host,
      {Duration timeout = const Duration(milliseconds: 300)}) async {
    if (host.isEmpty) return null;
    try {
      final sw = Stopwatch()..start();
      final socket = await Socket.connect(host, 80, timeout: timeout);
      sw.stop();
      socket.destroy();
      return sw.elapsedMilliseconds;
    } catch (_) {
      return null; // timeout or refused = 손실로 처리
    }
  }

  /// 정밀 품질 측정: [count]회 연속 TCP ping → 평균/지터/손실률 계산
  /// [onProgress]: (완료 횟수, 전체 횟수) 진행 상황 콜백
  Future<NetworkQuality> measureQuality(
    String host, {
    int count = 30,
    Duration interval = const Duration(milliseconds: 100),
    void Function(int done, int total)? onProgress,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      return NetworkQuality(
        host: host,
        total: 0,
        received: 0,
        lossRate: 100,
        measuredAt: DateTime.now(),
      );
    }

    final results = <int?>[];
    for (int i = 0; i < count; i++) {
      results.add(await _pingTcp(host));
      onProgress?.call(i + 1, count);
      if (i < count - 1) await Future.delayed(interval);
    }

    final responded = results.whereType<int>().toList();
    final lossRate =
        (results.where((r) => r == null).length / count) * 100.0;

    if (responded.isEmpty) {
      return NetworkQuality(
        host: host,
        total: count,
        received: 0,
        lossRate: lossRate,
        measuredAt: DateTime.now(),
      );
    }

    final avg = responded.reduce((a, b) => a + b) / responded.length;
    final minMs = responded.reduce((a, b) => a < b ? a : b);
    final maxMs = responded.reduce((a, b) => a > b ? a : b);

    // Jitter: 연속 편차 평균 (RFC 3550 — VoIP/실시간 제어 표준)
    double jitter = 0;
    if (responded.length > 1) {
      final diffs = <int>[
        for (int i = 1; i < responded.length; i++)
          (responded[i] - responded[i - 1]).abs()
      ];
      jitter = diffs.reduce((a, b) => a + b) / diffs.length;
    }

    return NetworkQuality(
      host: host,
      total: count,
      received: responded.length,
      lossRate: lossRate,
      avgMs: avg.round(),
      jitterMs: jitter.round(),
      minMs: minMs,
      maxMs: maxMs,
      measuredAt: DateTime.now(),
    );
  }

  Map<int, List<ApInfo>> groupByChannel(List<ApInfo> aps) {
    final Map<int, List<ApInfo>> map = {};
    for (final ap in aps) {
      map.putIfAbsent(ap.channel, () => []).add(ap);
    }
    return map;
  }
}
