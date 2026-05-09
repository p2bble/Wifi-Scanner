import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final _analytics = FirebaseAnalytics.instance;

  static const _tabNames = [
    'connected',
    'ap_list',
    'channel',
    'shadow',
    'report',
    'heatmap',
  ];

  static Future<void> logTabSelected(int index) async {
    if (kIsWeb) return;
    final name = index < _tabNames.length ? _tabNames[index] : 'unknown';
    await _analytics.logScreenView(screenName: name);
  }

  static Future<void> logScanCompleted({
    required int apCount,
    required int band24,
    required int band5,
    required int band6,
  }) async {
    if (kIsWeb) return;
    await _analytics.logEvent(
      name: 'wifi_scan_completed',
      parameters: {
        'ap_count': apCount,
        'band_2_4_count': band24,
        'band_5_count': band5,
        'band_6_count': band6,
      },
    );
  }

  static Future<void> logQualityMeasured({
    required double avgMs,
    required double jitterMs,
    required double packetLoss,
  }) async {
    if (kIsWeb) return;
    await _analytics.logEvent(
      name: 'quality_measured',
      parameters: {
        'avg_latency_ms': avgMs.round(),
        'jitter_ms': jitterMs.round(),
        'packet_loss_pct': packetLoss.round(),
      },
    );
  }

  static Future<void> logSpeedTested(double speedMbps) async {
    if (kIsWeb) return;
    await _analytics.logEvent(
      name: 'speed_tested',
      parameters: {'speed_mbps': speedMbps.round()},
    );
  }

  static Future<void> logShadowTrackingStarted() async {
    if (kIsWeb) return;
    await _analytics.logEvent(name: 'shadow_tracking_started');
  }

  static Future<void> logReportShared() async {
    if (kIsWeb) return;
    await _analytics.logEvent(name: 'report_shared');
  }

  static Future<void> logHeatmapPointAdded() async {
    if (kIsWeb) return;
    await _analytics.logEvent(name: 'heatmap_point_added');
  }

  static Future<void> logHistoryViewed() async {
    if (kIsWeb) return;
    await _analytics.logEvent(name: 'history_viewed');
  }
}
