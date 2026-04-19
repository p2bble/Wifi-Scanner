class HeatmapPoint {
  // 이미지 크기 대비 비율 (0.0 ~ 1.0) — 줌/이미지 크기에 독립적
  final double xRatio;
  final double yRatio;
  final int rssi;
  final DateTime timestamp;
  final String note;

  HeatmapPoint({
    required this.xRatio,
    required this.yRatio,
    required this.rssi,
    required this.timestamp,
    this.note = '',
  });
}
