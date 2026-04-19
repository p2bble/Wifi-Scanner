class SignalRecord {
  final DateTime timestamp;
  final int rssi;
  final String ssid;
  final String bssid;
  final String note;
  final bool isRoamingEvent;
  final String roamingFromBssid; // 이전 AP BSSID
  final int? pingMs;             // 로밍 직후 ping (ms)

  SignalRecord({
    required this.timestamp,
    required this.rssi,
    required this.ssid,
    this.bssid = '',
    this.note = '',
    this.isRoamingEvent = false,
    this.roamingFromBssid = '',
    this.pingMs,
  });

  String get signalLabel {
    if (rssi >= -50) return '매우 좋음';
    if (rssi >= -60) return '좋음';
    if (rssi >= -70) return '보통';
    if (rssi >= -80) return '나쁨';
    return '매우 나쁨';
  }

  String get signalEmoji {
    if (rssi >= -50) return '🟢';
    if (rssi >= -60) return '🟡';
    if (rssi >= -70) return '🟠';
    return '🔴';
  }

  // BSSID 앞 3바이트만 표시 (제조사 식별)
  String get shortBssid {
    if (bssid.isEmpty) return '';
    final parts = bssid.split(':');
    if (parts.length >= 3) return '${parts[0]}:${parts[1]}:${parts[2]}:…';
    return bssid;
  }
}
