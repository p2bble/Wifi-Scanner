import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/wifi_data.dart';
import '../models/signal_record.dart';
import '../models/network_quality.dart';

enum EnvType { home, office, factory }

extension EnvTypeExt on EnvType {
  String get label => switch (this) {
        EnvType.home => '🏠 가정',
        EnvType.office => '🏢 사무실',
        EnvType.factory => '🏭 공장/현장',
      };

  // 환경별 신호 판정 기준 (RSSI)
  String signalJudge(int rssi) => switch (this) {
        EnvType.home => rssi >= -60
            ? '✅ 양호 (가정 사용 문제없음)'
            : rssi >= -75
                ? '🟡 보통 (스트리밍 등 일부 영향 가능)'
                : '❌ 불량 (연결 불안정)',
        EnvType.office => rssi >= -65
            ? '✅ 양호 (업무 사용 적합)'
            : rssi >= -75
                ? '🟡 보통 (화상회의 등 끊김 가능)'
                : '❌ 불량 (업무 장애 가능성)',
        EnvType.factory => rssi >= -65
            ? '✅ 양호 (장비 통신 안정)'
            : rssi >= -72
                ? '🟡 주의 (로봇/IoT 통신 지연 가능)'
                : '❌ 위험 (AMR·설비 통신 장애 위험)',
      };

  // 환경별 채널 혼잡 해석
  String channelJudge(int congested24, int congested5) {
    if (congested24 == 0 && congested5 == 0) {
      return '✅ 채널 여유 — 현재 환경 적합';
    }
    return switch (this) {
      EnvType.home => '🟡 일부 채널 혼잡 — 가정 사용에 큰 지장 없음',
      EnvType.office => '⚠️ 채널 혼잡 — AP 채널 재배치 검토 권장',
      EnvType.factory =>
        '❌ 채널 혼잡 — 로봇/설비 통신 간섭 위험, 전파 조사 필요',
    };
  }

  // 환경별 통신 품질 해석
  String qualityJudge(NetworkQuality q) {
    if (q.received == 0) return '❓ 측정 실패 — 게이트웨이 응답 없음';
    final grade = q.grade;
    if (this == EnvType.factory) {
      return switch (grade) {
        '양호' => '✅ ${q.gradeEmoji} 양호 — AMR 실시간 제어 적합 (지터 ${q.jitterMs ?? "-"}ms / 손실 ${q.lossRate.toStringAsFixed(1)}%)',
        '주의' => '🟡 주의 — 간헐적 제어 지연 가능 (지터 ${q.jitterMs ?? "-"}ms / 손실 ${q.lossRate.toStringAsFixed(1)}%)',
        _ => '❌ 위험 — 로봇 통신 장애 위험, 즉시 조치 필요 (지터 ${q.jitterMs ?? "-"}ms / 손실 ${q.lossRate.toStringAsFixed(1)}%)',
      };
    }
    return switch (grade) {
      '양호' => '✅ 양호 — 정상 통신 가능 (평균 ${q.avgMs ?? "-"}ms / 손실 ${q.lossRate.toStringAsFixed(1)}%)',
      '주의' => '🟡 주의 — 일부 서비스 영향 가능 (지터 ${q.jitterMs ?? "-"}ms / 손실 ${q.lossRate.toStringAsFixed(1)}%)',
      _ => '❌ 불량 — 통신 품질 저하 (지터 ${q.jitterMs ?? "-"}ms / 손실 ${q.lossRate.toStringAsFixed(1)}%)',
    };
  }

  // 환경별 음영 해석
  String shadowJudge(int shadowCount) {
    if (shadowCount == 0) return '✅ 음영 구간 없음';
    return switch (this) {
      EnvType.home =>
        '🟡 음영 $shadowCount회 — AP 위치 조정 또는 중계기 검토',
      EnvType.office =>
        '⚠️ 음영 $shadowCount회 — 해당 구간 AP 추가 설치 권장',
      EnvType.factory =>
        '❌ 음영 $shadowCount회 — AMR 경로 재설계 또는 AP 증설 필요 (안전 위험)',
    };
  }
}

class ReportTab extends StatefulWidget {
  final ConnectedNetworkInfo? connectedInfo;
  final List<ApInfo> apList;
  final List<SignalRecord> shadowRecords;
  final NetworkQuality? quality;

  const ReportTab({
    super.key,
    required this.connectedInfo,
    required this.apList,
    this.shadowRecords = const [],
    this.quality,
  });

  @override
  State<ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<ReportTab> {
  final _locationController = TextEditingController();
  EnvType _envType = EnvType.office;

  String _buildReport() {
    final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    final location = _locationController.text.trim().isEmpty
        ? '미입력'
        : _locationController.text.trim();

    final info = widget.connectedInfo;
    final apList = widget.apList;
    final env = _envType;

    final band24 = apList.where((ap) => ap.band == '2.4GHz').toList();
    final band5 = apList.where((ap) => ap.band == '5GHz').toList();

    final Map<int, int> ch24Map = {};
    for (final ap in band24) {
      ch24Map[ap.channel] = (ch24Map[ap.channel] ?? 0) + 1;
    }
    final Map<int, int> ch5Map = {};
    for (final ap in band5) {
      ch5Map[ap.channel] = (ch5Map[ap.channel] ?? 0) + 1;
    }

    ApInfo? connectedAp;
    if (info != null) {
      try {
        connectedAp = apList.firstWhere((ap) => ap.ssid == info.ssid);
      } catch (_) {}
    }

    final congested24 =
        ch24Map.values.where((v) => v >= 3).length;
    final congested5 =
        ch5Map.values.where((v) => v >= 3).length;
    final records = widget.shadowRecords;
    final shadowCount =
        records.where((r) => r.rssi < -75).length;

    final buf = StringBuffer();
    buf.writeln('📡 현장 WiFi 환경 리포트');
    buf.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buf.writeln('📅 $now');
    buf.writeln('📍 측정 위치: $location');
    buf.writeln('🏷️ 측정 환경: ${env.label}');
    buf.writeln();

    if (info != null) {
      buf.writeln('[연결 정보]');
      buf.writeln('SSID: ${info.ssid.isEmpty ? "(알 수 없음)" : info.ssid}');
      if (connectedAp != null) {
        buf.writeln(
            '신호: ${connectedAp.rssi}dBm (${connectedAp.signalLabel}) ${connectedAp.signalEmoji}');
        buf.writeln('주파수: ${connectedAp.band} / Ch${connectedAp.channel}');
        buf.writeln('보안: ${connectedAp.isSecure ? "🔒 암호화됨" : "🔓 개방망"}');
        buf.writeln('판정: ${env.signalJudge(connectedAp.rssi)}');
      }
      buf.writeln('IP: ${info.ipAddress.isEmpty ? "-" : info.ipAddress}');
      buf.writeln('게이트웨이: ${info.gateway.isEmpty ? "-" : info.gateway}');
      buf.writeln();
    }

    buf.writeln('[주변 AP 현황]');
    buf.writeln(
        '총 ${apList.length}개 탐지 (2.4GHz: ${band24.length}개 / 5GHz: ${band5.length}개)');
    buf.writeln();

    if (ch24Map.isNotEmpty) {
      buf.writeln('[2.4GHz 채널 혼잡도]');
      ch24Map.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key))
        ..forEach((e) {
          final congested = e.value >= 3 ? ' ⚠️ 혼잡' : '';
          buf.writeln('  Ch${e.key}: ${e.value}개 AP$congested');
        });
      buf.writeln();
    }

    if (ch5Map.isNotEmpty) {
      buf.writeln('[5GHz 채널 혼잡도]');
      ch5Map.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key))
        ..forEach((e) {
          final congested = e.value >= 3 ? ' ⚠️ 혼잡' : '';
          buf.writeln('  Ch${e.key}: ${e.value}개 AP$congested');
        });
      buf.writeln();
    }

    buf.writeln('[신호 강도 상위 5개]');
    final top5 = apList.take(5).toList();
    for (final ap in top5) {
      buf.writeln(
          '  ${ap.signalEmoji} ${ap.ssid}  ${ap.rssi}dBm  Ch${ap.channel} (${ap.band})');
    }

    if (records.isNotEmpty) {
      buf.writeln();
      final rssies = records.map((r) => r.rssi).toList();
      final minR = rssies.reduce((a, b) => a < b ? a : b);
      final maxR = rssies.reduce((a, b) => a > b ? a : b);
      final avgR =
          (rssies.reduce((a, b) => a + b) / rssies.length).round();
      final notes = records.where((r) => r.note.isNotEmpty).toList();

      buf.writeln('[음영 추적 결과]');
      buf.writeln('  총 ${records.length}회 측정');
      buf.writeln('  Min: ${minR}dBm  Max: ${maxR}dBm  평균: ${avgR}dBm');
      buf.writeln('  판정: ${env.shadowJudge(shadowCount)}');
      if (notes.isNotEmpty) {
        buf.writeln('  위치 메모:');
        for (final r in notes) {
          buf.writeln('    📍 ${r.note}  (${r.rssi}dBm)');
        }
      }
    }

    if (widget.quality != null) {
      final q = widget.quality!;
      buf.writeln();
      buf.writeln('[통신 품질 정밀 측정]');
      buf.writeln('  대상: ${q.host}  (TCP Ping ${q.total}회)');
      buf.writeln('  평균 지연: ${q.avgMs != null ? "${q.avgMs}ms" : "-"}');
      buf.writeln('  지터 (편차): ${q.jitterMs != null ? "${q.jitterMs}ms" : "-"}');
      buf.writeln('  패킷 손실: ${q.lossLabel}  (${q.received}/${q.total}회 응답)');
      buf.writeln('  범위: min ${q.minMs ?? "-"}ms / max ${q.maxMs ?? "-"}ms');
      buf.writeln('  판정: ${env.qualityJudge(q)}');
    }

    buf.writeln();
    buf.writeln('[종합 판정]');
    buf.writeln('  ${env.channelJudge(congested24, congested5)}');
    if (records.isNotEmpty) {
      buf.writeln('  ${env.shadowJudge(shadowCount)}');
    }
    if (widget.quality != null) {
      buf.writeln('  ${env.qualityJudge(widget.quality!)}');
    }

    buf.writeln();
    buf.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buf.writeln('📱 WiFi 진단기로 측정');

    return buf.toString();
  }

  String _buildCsv() {
    final buf = StringBuffer();
    buf.writeln('SSID,BSSID,RSSI(dBm),Band,Channel,WiFi Standard,Secure');
    for (final ap in widget.apList) {
      final ssid = '"${ap.ssid.replaceAll('"', '""')}"';
      buf.writeln('$ssid,${ap.bssid},${ap.rssi},${ap.band},${ap.channel},${ap.wifiStandard},${ap.isSecure}');
    }
    return buf.toString();
  }

  Future<void> _shareAsCsv() async {
    final csv = _buildCsv();
    final now = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/wifi_scan_$now.csv');
    await file.writeAsString(csv);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'WiFi 스캔 결과 $now',
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _buildReport();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('측정 환경',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                SegmentedButton<EnvType>(
                  segments: const [
                    ButtonSegment(
                        value: EnvType.home,
                        label: Text('🏠 가정'),
                        icon: Icon(Icons.home, size: 16)),
                    ButtonSegment(
                        value: EnvType.office,
                        label: Text('🏢 사무실'),
                        icon: Icon(Icons.business, size: 16)),
                    ButtonSegment(
                        value: EnvType.factory,
                        label: Text('🏭 공장'),
                        icon: Icon(Icons.factory, size: 16)),
                  ],
                  selected: {_envType},
                  onSelectionChanged: (s) =>
                      setState(() => _envType = s.first),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('측정 위치 입력',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    hintText: '예) 1층 로비, 창고 A구역, 2번 작업장',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('리포트 미리보기',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                const Divider(height: 20),
                Text(
                  report,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 12, height: 1.6),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => Share.share(report),
          icon: const Icon(Icons.share),
          label: const Text('리포트 공유'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: widget.apList.isEmpty ? null : _shareAsCsv,
          icon: const Icon(Icons.download),
          label: const Text('CSV로 내보내기'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }
}
