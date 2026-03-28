class SignalRecord {
  final DateTime timestamp;
  final int rssi;
  final String ssid;
  final String note;

  SignalRecord({
    required this.timestamp,
    required this.rssi,
    required this.ssid,
    this.note = '',
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
}
