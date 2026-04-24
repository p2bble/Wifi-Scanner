import 'package:flutter/material.dart';
import '../models/network_quality.dart';
import '../models/scan_history.dart';
import '../models/wifi_data.dart';
import '../services/database_service.dart';
import '../services/wifi_service.dart';

class ConnectedTab extends StatefulWidget {
  final ConnectedNetworkInfo? connectedInfo;
  final List<ApInfo> apList;
  final void Function(NetworkQuality)? onQualityMeasured;

  const ConnectedTab({
    super.key,
    required this.connectedInfo,
    required this.apList,
    this.onQualityMeasured,
  });

  @override
  State<ConnectedTab> createState() => _ConnectedTabState();
}

class _ConnectedTabState extends State<ConnectedTab> {
  final _wifiService = WifiService();
  final _db = DatabaseService();

  // 빠른 ping (연결 정보 탭 진입 시 1회 측정)
  int? _gatewayPing;
  int? _internetPing;
  bool _pinging = false;

  // 정밀 품질 측정
  NetworkQuality? _quality;
  bool _measuring = false;
  int _measureProgress = 0;
  static const _measureCount = 30;

  // 속도 측정
  double? _speedMbps;
  bool _speedTesting = false;
  bool _speedSaved = false;

  @override
  void initState() {
    super.initState();
    _runPing();
  }

  Future<void> _runPing() async {
    if (widget.connectedInfo == null) return;
    setState(() => _pinging = true);
    final gw = widget.connectedInfo!.gateway;
    final results = await Future.wait([
      _wifiService.pingGateway(gw),
      _wifiService.pingInternet(),
    ]);
    if (mounted) {
      setState(() {
        _gatewayPing = results[0];
        _internetPing = results[1];
        _pinging = false;
      });
    }
  }

  Future<void> _startQualityMeasure() async {
    final gw = widget.connectedInfo?.gateway ?? '';
    if (gw.isEmpty) return;

    setState(() {
      _measuring = true;
      _measureProgress = 0;
      _quality = null;
    });

    final result = await _wifiService.measureQuality(
      gw,
      count: _measureCount,
      interval: const Duration(milliseconds: 100),
      onProgress: (done, total) {
        if (mounted) setState(() => _measureProgress = done);
      },
    );

    if (mounted) {
      setState(() {
        _quality = result;
        _measuring = false;
      });
      widget.onQualityMeasured?.call(result);
      _saveHistory(quality: result);
    }
  }

  Future<void> _startSpeedTest() async {
    setState(() {
      _speedTesting = true;
      _speedMbps = null;
      _speedSaved = false;
    });
    final mbps = await _wifiService.measureSpeed();
    if (mounted) {
      setState(() {
        _speedMbps = mbps;
        _speedTesting = false;
      });
      if (mbps != null) _saveHistory(speedMbps: mbps);
    }
  }

  Future<void> _saveHistory({NetworkQuality? quality, double? speedMbps}) async {
    final info = widget.connectedInfo;
    final ap = _connectedAp;
    if (info == null) return;

    await _db.insert(ScanHistory(
      measuredAt: DateTime.now(),
      ssid: info.ssid,
      bssid: info.bssid,
      rssi: ap?.rssi ?? 0,
      band: ap?.band ?? '-',
      channel: ap?.channel ?? 0,
      wifiStandard: ap?.wifiStandard ?? '-',
      grade: quality?.grade,
      avgMs: quality?.avgMs,
      jitterMs: quality?.jitterMs,
      lossRate: quality?.lossRate,
      speedMbps: speedMbps ?? _speedMbps,
    ));
    if (speedMbps != null && mounted) setState(() => _speedSaved = true);
  }

  ApInfo? get _connectedAp {
    if (widget.connectedInfo == null) return null;
    try {
      return widget.apList
          .firstWhere((ap) => ap.ssid == widget.connectedInfo!.ssid);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.connectedInfo;
    final ap = _connectedAp;

    if (info == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('WiFi에 연결되지 않았습니다',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _runPing,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSignalCard(info, ap),
          const SizedBox(height: 12),
          _buildNetworkCard(info),
          const SizedBox(height: 12),
          _buildPingCard(),
          const SizedBox(height: 12),
          _buildQualityCard(),
          const SizedBox(height: 12),
          _buildSpeedCard(),
        ],
      ),
    );
  }

  Widget _buildSignalCard(ConnectedNetworkInfo info, ApInfo? ap) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wifi, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    info.ssid.isEmpty ? '(알 수 없음)' : info.ssid,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (ap != null) ...[
              _infoRow('신호 세기',
                  '${ap.rssi} dBm  ${ap.signalEmoji} ${ap.signalLabel}'),
              _infoRow('WiFi 표준', ap.wifiStandard),
              _infoRow('주파수 대역', '${ap.band} (${ap.frequency} MHz)'),
              _infoRow('채널', '${ap.channel}번'),
              _infoRow('보안', ap.isSecure ? '🔒 암호화됨' : '🔓 개방망'),
            ],
            _infoRow('BSSID', info.bssid),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkCard(ConnectedNetworkInfo info) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('네트워크 정보',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            _infoRow('IP 주소',
                info.ipAddress.isEmpty ? '-' : info.ipAddress),
            _infoRow(
                '게이트웨이', info.gateway.isEmpty ? '-' : info.gateway),
          ],
        ),
      ),
    );
  }

  Widget _buildPingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('응답 속도 (빠른 Ping)',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                if (_pinging)
                  const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2))
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _runPing,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const Divider(height: 20),
            _pingRow('게이트웨이', _gatewayPing),
            _pingRow('인터넷 (8.8.8.8)', _internetPing),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('통신 품질 정밀 측정',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                Tooltip(
                  message:
                      'TCP Ping $_measureCount회 연속 측정\n평균 지연 · 지터(편차) · 패킷 손실률 계산\n소요 시간: 약 3~4초',
                  child: Icon(Icons.info_outline,
                      size: 16, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '게이트웨이 TCP Ping $_measureCount회 · Jitter(RFC 3550) · 패킷 손실률',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const Divider(height: 20),

            if (_measuring) ...[
              _buildMeasuringState(),
            ] else if (_quality != null) ...[
              _buildQualityResult(_quality!),
              const SizedBox(height: 14),
              _buildMeasureButton(rerun: true),
            ] else ...[
              _buildQualityIdle(),
              const SizedBox(height: 14),
              _buildMeasureButton(rerun: false),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMeasuringState() {
    final progress = _measureProgress / _measureCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Text(
              '측정 중... $_measureProgress / $_measureCount',
              style: const TextStyle(fontSize: 13, color: Colors.blue),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Colors.grey.shade200,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '잠시만 기다려주세요 — 약 ${(_measureCount * 0.1).toStringAsFixed(0)}초 소요',
          style:
              TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildQualityIdle() {
    return Text(
      '로봇 실시간 제어에 중요한 지터(Jitter)와\n패킷 손실률(Packet Loss)을 정밀 측정합니다.',
      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
    );
  }

  Widget _buildQualityResult(NetworkQuality q) {
    return Column(
      children: [
        _qualityRow(
          '평균 지연',
          q.avgMs != null ? '${q.avgMs} ms' : '-',
          _pingColor(q.avgMs),
          sub: q.minMs != null && q.maxMs != null
              ? 'min ${q.minMs}ms / max ${q.maxMs}ms'
              : null,
        ),
        const SizedBox(height: 8),
        _qualityRow(
          '지터 (편차)',
          q.jitterMs != null ? '${q.jitterMs} ms' : '-',
          _jitterColor(q.jitterMs),
          sub: q.jitterMs != null
              ? (q.jitterMs! < 5
                  ? '실시간 제어 적합'
                  : q.jitterMs! < 15
                      ? '경미한 편차'
                      : '제어 불안정 위험')
              : null,
        ),
        const SizedBox(height: 8),
        _qualityRow(
          '패킷 손실',
          q.lossLabel,
          q.lossColor,
          sub: '${q.received}/${q.total}회 응답',
        ),
        const Divider(height: 20),
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: q.gradeColor.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: q.gradeColor.withAlpha(80)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${q.gradeEmoji} 종합 등급: ${q.grade}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: q.gradeColor,
                        fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                q.gradeDesc,
                style: TextStyle(
                    fontSize: 12, color: q.gradeColor.withAlpha(200)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMeasureButton({required bool rerun}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: widget.connectedInfo?.gateway.isEmpty ?? true
            ? null
            : _startQualityMeasure,
        icon: Icon(rerun ? Icons.refresh : Icons.speed, size: 18),
        label: Text(rerun ? '다시 측정' : '정밀 측정 시작 ($_measureCount회)'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _qualityRow(String label, String value, Color color,
      {String? sub}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style:
                  const TextStyle(color: Colors.grey, fontSize: 13)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color)),
              if (sub != null)
                Text(sub,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ],
    );
  }

  Color _pingColor(int? ms) {
    if (ms == null) return Colors.grey;
    if (ms < 10) return Colors.green;
    if (ms < 30) return Colors.orange;
    return Colors.red;
  }

  Color _jitterColor(int? ms) {
    if (ms == null) return Colors.grey;
    if (ms < 5) return Colors.green;
    if (ms < 15) return Colors.orange;
    return Colors.red;
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildSpeedCard() {
    String speedText;
    Color speedColor;
    String? speedSub;

    if (_speedTesting) {
      speedText = '측정 중...';
      speedColor = Colors.grey;
      speedSub = 'Cloudflare 2MB 다운로드 중 (최대 20초)';
    } else if (_speedMbps != null) {
      final mbps = _speedMbps!;
      speedText = '${mbps.toStringAsFixed(1)} Mbps';
      if (mbps >= 50) {
        speedColor = Colors.green;
        speedSub = '우수 — 고화질 스트리밍 / AMR 원격제어 적합';
      } else if (mbps >= 10) {
        speedColor = Colors.orange;
        speedSub = '양호 — 일반 업무 적합';
      } else if (mbps >= 1) {
        speedColor = Colors.deepOrange;
        speedSub = '느림 — 대용량 전송 지연 가능';
      } else {
        speedColor = Colors.red;
        speedSub = '매우 느림 — AP 재배치 또는 채널 변경 권장';
      }
      if (_speedSaved) speedSub = '$speedSub  ✅ 히스토리 저장됨';
    } else {
      speedText = '-';
      speedColor = Colors.grey;
      speedSub = 'Cloudflare 서버 기준 실제 다운로드 속도 측정';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('다운로드 속도 측정',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Cloudflare 서버에서 2MB 파일 다운로드\n실제 WiFi 처리량(Throughput)을 Mbps로 표시',
                  child:
                      Icon(Icons.info_outline, size: 16, color: Colors.grey.shade500),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_speedTesting)
                  const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Icon(Icons.speed,
                      size: 28,
                      color: _speedMbps != null ? speedColor : Colors.grey),
                const SizedBox(width: 12),
                Text(
                  speedText,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: speedColor),
                ),
              ],
            ),
            if (speedSub != null) ...[
              const SizedBox(height: 4),
              Text(speedSub,
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_speedTesting || widget.connectedInfo == null)
                    ? null
                    : _startSpeedTest,
                icon: Icon(
                    _speedMbps != null ? Icons.refresh : Icons.network_check,
                    size: 18),
                label: Text(_speedMbps != null ? '다시 측정' : '속도 측정 시작'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pingRow(String label, int? ms) {
    String value;
    Color color;
    if (_pinging) {
      value = '측정 중...';
      color = Colors.grey;
    } else if (ms == null) {
      value = '응답 없음 ❌';
      color = Colors.red;
    } else if (ms < 20) {
      value = '${ms}ms  🟢 매우 좋음';
      color = Colors.green;
    } else if (ms < 50) {
      value = '${ms}ms  🟡 좋음';
      color = Colors.orange;
    } else {
      value = '${ms}ms  🔴 느림';
      color = Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.grey, fontSize: 13)),
          ),
          Text(value,
              style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }
}
