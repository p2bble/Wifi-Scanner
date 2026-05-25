import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  static final _rc = FirebaseRemoteConfig.instance;

  static const _defaults = {
    'shadow_rssi_threshold': -75,
    'quality_ping_count': 30,
  };

  static Future<void> init() async {
    if (kIsWeb) return;
    await _rc.setDefaults(_defaults);
    await _rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    await _rc.fetchAndActivate();
  }

  // 음영 감지 RSSI 기준 (dBm, 음수). Firebase Console에서 조정 가능.
  static int get shadowRssiThreshold =>
      kIsWeb ? -75 : _rc.getInt('shadow_rssi_threshold');

  // 품질 측정 ping 횟수. Firebase Console에서 조정 가능.
  static int get qualityPingCount =>
      kIsWeb ? 30 : _rc.getInt('quality_ping_count');
}
