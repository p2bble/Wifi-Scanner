import 'package:flutter/material.dart';

class ScanHistory {
  final int? id;
  final DateTime measuredAt;
  final String ssid;
  final String bssid;
  final int rssi;
  final String band;
  final int channel;
  final String wifiStandard;
  final String? grade;      // 양호 / 주의 / 위험
  final int? avgMs;
  final int? jitterMs;
  final double? lossRate;
  final double? speedMbps;

  const ScanHistory({
    this.id,
    required this.measuredAt,
    required this.ssid,
    required this.bssid,
    required this.rssi,
    required this.band,
    required this.channel,
    required this.wifiStandard,
    this.grade,
    this.avgMs,
    this.jitterMs,
    this.lossRate,
    this.speedMbps,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'measuredAt': measuredAt.millisecondsSinceEpoch,
        'ssid': ssid,
        'bssid': bssid,
        'rssi': rssi,
        'band': band,
        'channel': channel,
        'wifiStandard': wifiStandard,
        'grade': grade,
        'avgMs': avgMs,
        'jitterMs': jitterMs,
        'lossRate': lossRate,
        'speedMbps': speedMbps,
      };

  factory ScanHistory.fromMap(Map<String, dynamic> m) => ScanHistory(
        id: m['id'] as int?,
        measuredAt: DateTime.fromMillisecondsSinceEpoch(m['measuredAt'] as int),
        ssid: m['ssid'] as String,
        bssid: m['bssid'] as String,
        rssi: m['rssi'] as int,
        band: m['band'] as String,
        channel: m['channel'] as int,
        wifiStandard: m['wifiStandard'] as String,
        grade: m['grade'] as String?,
        avgMs: m['avgMs'] as int?,
        jitterMs: m['jitterMs'] as int?,
        lossRate: m['lossRate'] as double?,
        speedMbps: m['speedMbps'] as double?,
      );

  Color get gradeColor => switch (grade) {
        '양호' => Colors.green,
        '주의' => Colors.orange,
        '위험' => Colors.red,
        _ => Colors.grey,
      };

  String get gradeEmoji => switch (grade) {
        '양호' => '✅',
        '주의' => '🟡',
        '위험' => '❌',
        _ => '📊',
      };

  String get rssiLabel {
    if (rssi >= -60) return '좋음';
    if (rssi >= -70) return '보통';
    if (rssi >= -80) return '나쁨';
    return '매우 나쁨';
  }
}
