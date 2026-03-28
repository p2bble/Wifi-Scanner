class ApInfo {
  final String ssid;
  final String bssid;
  final int rssi;
  final int frequency;
  final String capabilities;

  ApInfo({
    required this.ssid,
    required this.bssid,
    required this.rssi,
    required this.frequency,
    required this.capabilities,
  });

  int get channel {
    if (frequency >= 2412 && frequency <= 2484) {
      if (frequency == 2484) return 14;
      return (frequency - 2412) ~/ 5 + 1;
    } else if (frequency >= 5180) {
      return (frequency - 5000) ~/ 5;
    }
    return 0;
  }

  String get band {
    if (frequency >= 2400 && frequency < 2500) return '2.4GHz';
    if (frequency >= 5000 && frequency < 6000) return '5GHz';
    if (frequency >= 6000) return '6GHz';
    return '알 수 없음';
  }

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

  bool get isSecure => capabilities.contains('WPA') || capabilities.contains('WEP');

  // WiFi 표준 추정 (capabilities 문자열 + 주파수 기반)
  String get wifiStandard {
    if (capabilities.contains('EHT')) return 'WiFi 7 (802.11be)';
    if (capabilities.contains('HE') || capabilities.contains('[RSN-EAP-CCMP-SUITE-B-192]')) {
      return 'WiFi 6 (802.11ax)';
    }
    if (capabilities.contains('VHT')) return 'WiFi 5 (802.11ac)';
    if (capabilities.contains('HT')) {
      return frequency >= 5000 ? 'WiFi 4 (802.11n/5G)' : 'WiFi 4 (802.11n)';
    }
    if (frequency >= 5000) return '802.11a';
    return '802.11b/g';
  }
}

class ConnectedNetworkInfo {
  final String ssid;
  final String bssid;
  final String ipAddress;
  final String gateway;

  ConnectedNetworkInfo({
    required this.ssid,
    required this.bssid,
    required this.ipAddress,
    required this.gateway,
  });
}
