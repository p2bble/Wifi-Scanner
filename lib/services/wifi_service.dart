import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:wifi_scan/wifi_scan.dart';
import '../models/wifi_data.dart';

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

  Map<int, List<ApInfo>> groupByChannel(List<ApInfo> aps) {
    final Map<int, List<ApInfo>> map = {};
    for (final ap in aps) {
      map.putIfAbsent(ap.channel, () => []).add(ap);
    }
    return map;
  }
}
