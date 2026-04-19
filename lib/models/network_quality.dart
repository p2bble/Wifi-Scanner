import 'package:flutter/material.dart';

class NetworkQuality {
  final String host;
  final int total;       // 총 전송 횟수
  final int received;    // 응답 받은 횟수
  final double lossRate; // 패킷 손실률 (%)
  final int? avgMs;      // 평균 지연 (ms)
  final int? jitterMs;   // 지터 — 연속 편차 평균, RFC 3550 방식 (ms)
  final int? minMs;
  final int? maxMs;
  final DateTime measuredAt;

  const NetworkQuality({
    required this.host,
    required this.total,
    required this.received,
    required this.lossRate,
    required this.measuredAt,
    this.avgMs,
    this.jitterMs,
    this.minMs,
    this.maxMs,
  });

  // AMR 관점 3단계 등급
  // 기준: 로봇 실시간 제어(안전 관련) 기준으로 엄격하게 설정
  String get grade {
    if (received == 0) return '측정 실패';
    if (lossRate >= 5 ||
        (jitterMs != null && jitterMs! >= 30) ||
        (avgMs != null && avgMs! >= 100)) {
      return '위험';
    }
    if (lossRate >= 1 ||
        (jitterMs != null && jitterMs! >= 15) ||
        (avgMs != null && avgMs! >= 30)) {
      return '주의';
    }
    return '양호';
  }

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
        _ => '❓',
      };

  String get gradeDesc => switch (grade) {
        '양호' => 'AMR 실시간 제어 적합',
        '주의' => '간헐적 제어 지연 가능 — AP 위치 재검토 권장',
        '위험' => '로봇 통신 장애 위험 — 즉시 조치 필요',
        _ => '측정 불가',
      };

  String get lossLabel {
    if (lossRate == 0) return '0%  (손실 없음)';
    if (lossRate < 1) return '${lossRate.toStringAsFixed(1)}%  (경미)';
    if (lossRate < 5) return '${lossRate.toStringAsFixed(1)}%  ⚠️ 주의';
    return '${lossRate.toStringAsFixed(1)}%  ❌ 위험';
  }

  Color get lossColor {
    if (lossRate == 0) return Colors.green;
    if (lossRate < 1) return Colors.orange;
    return Colors.red;
  }
}
