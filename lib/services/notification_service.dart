import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static DateTime? _lastShadowNotif;

  static const _shadowChannelId = 'wifi_shadow';
  static const _shadowChannelName = 'WiFi 음영 알림';

  static Future<void> init() async {
    if (_initialized || kIsWeb || !Platform.isAndroid) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);

    // Android 13+ 알림 권한 요청
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  // 음영 감지 알림 — 30초 쿨다운으로 스팸 방지
  static Future<void> showShadowAlert(int rssi) async {
    if (!_initialized) return;

    final now = DateTime.now();
    if (_lastShadowNotif != null &&
        now.difference(_lastShadowNotif!).inSeconds < 30) return;
    _lastShadowNotif = now;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _shadowChannelId,
        _shadowChannelName,
        channelDescription: 'WiFi 신호 음영 구간 감지 시 알림',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: false,
        enableVibration: true,
      ),
    );

    await _plugin.show(
      1,
      '⚠️ WiFi 음영 구간 감지',
      '신호 강도 ${rssi}dBm — 장비 통신 불안정 가능',
      details,
    );
  }
}
