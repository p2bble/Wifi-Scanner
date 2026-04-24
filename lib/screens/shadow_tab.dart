import 'dart:async';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import '../models/signal_record.dart';
import '../models/wifi_data.dart';
import '../services/notification_service.dart';
import '../services/wifi_service.dart';

class ShadowTab extends StatefulWidget {
  final ConnectedNetworkInfo? connectedInfo;
  final void Function(List<SignalRecord>)? onRecordsUpdated;

  const ShadowTab({
    super.key,
    required this.connectedInfo,
    this.onRecordsUpdated,
  });

  @override
  State<ShadowTab> createState() => _ShadowTabState();
}

class _ShadowTabState extends State<ShadowTab> {
  final List<SignalRecord> _records = [];
  final _wifiService = WifiService();
  Timer? _timer;
  bool _isRecording = false;
  final _noteController = TextEditingController();
  String _lastBssid = '';

  @override
  void dispose() {
    _timer?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  Future<int?> _getCurrentRssi() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final results = await WiFiScan.instance.getScannedResults();
      final ssid = widget.connectedInfo?.ssid ?? '';
      if (ssid.isEmpty) return null;
      final ap = results.firstWhere(
        (r) => r.ssid == ssid,
        orElse: () => results.first,
      );
      return ap.level;
    } catch (_) {
      return null;
    }
  }

  void _startRecording() {
    _lastBssid = widget.connectedInfo?.bssid ?? '';
    setState(() => _isRecording = true);
    _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final rssi = await _getCurrentRssi();
      if (rssi == null || !mounted) return;

      final bssid = await _wifiService.getCurrentBssid();

      // 로밍 감지: BSSID가 변경됨
      bool isRoaming = false;
      String fromBssid = '';
      int? pingMs;

      if (_lastBssid.isNotEmpty && bssid.isNotEmpty && _lastBssid != bssid) {
        isRoaming = true;
        fromBssid = _lastBssid;
        // 로밍 직후 게이트웨이 ping 측정 (통신 단절 확인)
        final gw = widget.connectedInfo?.gateway ?? '';
        if (gw.isNotEmpty) {
          pingMs = await _wifiService.pingGateway(gw);
        }
      }

      if (bssid.isNotEmpty) _lastBssid = bssid;

      // 음영 감지 시 로컬 알림 발송 (30초 쿨다운)
      if (rssi < -75) {
        NotificationService.showShadowAlert(rssi);
      }

      if (mounted) {
        setState(() {
          _records.add(SignalRecord(
            timestamp: DateTime.now(),
            rssi: rssi,
            ssid: widget.connectedInfo?.ssid ?? '',
            bssid: bssid,
            isRoamingEvent: isRoaming,
            roamingFromBssid: fromBssid,
            pingMs: pingMs,
          ));
        });
        widget.onRecordsUpdated?.call(List.unmodifiable(_records));
      }
    });
  }

  void _stopRecording() {
    _timer?.cancel();
    setState(() => _isRecording = false);
  }

  void _addNote() {
    final note = _noteController.text.trim();
    if (note.isEmpty || _records.isEmpty) return;
    final last = _records.last;
    setState(() {
      _records[_records.length - 1] = SignalRecord(
        timestamp: last.timestamp,
        rssi: last.rssi,
        ssid: last.ssid,
        bssid: last.bssid,
        note: note,
        isRoamingEvent: last.isRoamingEvent,
        roamingFromBssid: last.roamingFromBssid,
        pingMs: last.pingMs,
      );
    });
    _noteController.clear();
  }

  void _clearRecords() {
    _stopRecording();
    setState(() {
      _records.clear();
      _lastBssid = '';
    });
  }

  String get _stats {
    if (_records.isEmpty) return '';
    final rssies = _records.map((r) => r.rssi).toList();
    final min = rssies.reduce((a, b) => a < b ? a : b);
    final max = rssies.reduce((a, b) => a > b ? a : b);
    final avg = (rssies.reduce((a, b) => a + b) / rssies.length).round();
    return 'Min: ${min}dBm  |  Max: ${max}dBm  |  평균: ${avg}dBm';
  }

  List<SignalRecord> get _shadowPoints =>
      _records.where((r) => r.rssi < -75).toList();

  List<MapEntry<int, SignalRecord>> get _roamingEvents => _records
      .asMap()
      .entries
      .where((e) => e.value.isRoamingEvent)
      .toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildControlBar(),
        Expanded(
          child: _records.isEmpty ? _buildEmptyState() : _buildContent(),
        ),
      ],
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isRecording ? '● 측정 중...' : '측정 대기',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isRecording ? Colors.red : Colors.grey,
                  ),
                ),
                if (_records.isNotEmpty)
                  Text(
                    '${_records.length}개 기록  $_stats',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ),
          if (_records.isNotEmpty && !_isRecording)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearRecords,
              tooltip: '기록 초기화',
            ),
          const SizedBox(width: 4),
          ElevatedButton.icon(
            onPressed: widget.connectedInfo == null
                ? null
                : (_isRecording ? _stopRecording : _startRecording),
            icon: Icon(_isRecording ? Icons.stop : Icons.play_arrow),
            label: Text(_isRecording ? '중지' : '시작'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRecording ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.route, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('이동하면서 신호 변화를 기록합니다',
              style: TextStyle(color: Colors.grey, fontSize: 15)),
          const SizedBox(height: 8),
          const Text('음영 구간(−75dBm 이하) 및 AP 로밍을 자동 감지합니다',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          if (widget.connectedInfo == null) ...[
            const SizedBox(height: 16),
            const Text('WiFi에 연결 후 사용 가능합니다',
                style: TextStyle(color: Colors.orange, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildChart(),
        const SizedBox(height: 12),
        if (_shadowPoints.isNotEmpty) _buildShadowAlert(),
        if (_roamingEvents.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildRoamingCard(),
        ],
        const SizedBox(height: 12),
        _buildNoteInput(),
        const SizedBox(height: 12),
        _buildRecordList(),
      ],
    );
  }

  Widget _buildChart() {
    final spots = _records.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.rssi.toDouble());
    }).toList();

    final roamingLines = _roamingEvents.map((e) {
      return VerticalLine(
        x: e.key.toDouble(),
        color: Colors.purple.withAlpha(180),
        strokeWidth: 2,
        dashArray: [4, 3],
        label: VerticalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          labelResolver: (_) => '로밍',
          style: const TextStyle(fontSize: 9, color: Colors.purple),
        ),
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Row(
                children: [
                  const Text('신호 이력 (RSSI)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  if (_roamingEvents.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple.withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.purple.withAlpha(80)),
                      ),
                      child: Text(
                        '로밍 ${_roamingEvents.length}회',
                        style: const TextStyle(fontSize: 10, color: Colors.purple),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: -100,
                  maxY: -30,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 2,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, p1, p2, p3) {
                          // 로밍 이벤트 포인트는 보라색 다이아몬드
                          final idx = spot.x.toInt();
                          if (idx < _records.length && _records[idx].isRoamingEvent) {
                            return FlDotCirclePainter(
                              radius: 5,
                              color: Colors.purple,
                              strokeWidth: 0,
                              strokeColor: Colors.transparent,
                            );
                          }
                          return FlDotCirclePainter(
                            radius: 3,
                            color: spot.y < -75 ? Colors.red : Colors.blue,
                            strokeWidth: 0,
                            strokeColor: Colors.transparent,
                          );
                        },
                      ),
                    ),
                  ],
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: -75,
                        color: Colors.red.withAlpha(128),
                        strokeWidth: 1,
                        dashArray: [6, 4],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          labelResolver: (_) => '음영 기준 -75dBm',
                          style: const TextStyle(
                              fontSize: 10, color: Colors.red),
                        ),
                      ),
                    ],
                    verticalLines: roamingLines,
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 20,
                        reservedSize: 40,
                        getTitlesWidget: (val, _) => Text(
                          '${val.toInt()}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (val) => FlLine(
                      color: Colors.grey.withAlpha(40),
                      strokeWidth: 1,
                    ),
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShadowAlert() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '음영 구간 ${_shadowPoints.length}회 감지',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  Text(
                    '−75dBm 이하 구간: 로봇/장비 통신 불안정 가능',
                    style:
                        TextStyle(fontSize: 12, color: Colors.red.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoamingCard() {
    final events = _roamingEvents;
    final pings = events.map((e) => e.value.pingMs).whereType<int>().toList();
    final avgPing = pings.isEmpty
        ? null
        : (pings.reduce((a, b) => a + b) / pings.length).round();
    final maxPing = pings.isEmpty ? null : pings.reduce((a, b) => a > b ? a : b);
    final noResponse = events.where((e) => e.value.pingMs == null).length;

    return Card(
      color: Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.swap_horiz, color: Colors.purple.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  'AP 로밍 이벤트 ${events.length}회',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (avgPing != null)
              _roamingStat('로밍 직후 평균 지연', '${avgPing}ms',
                  avgPing > 100 ? Colors.red : Colors.green),
            if (maxPing != null)
              _roamingStat('최대 지연', '${maxPing}ms',
                  maxPing > 200 ? Colors.red : Colors.orange),
            if (noResponse > 0)
              _roamingStat('응답 없음 (패킷 손실)', '$noResponse회', Colors.red),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...events.map((e) => _roamingEventRow(e.key, e.value)),
          ],
        ),
      ),
    );
  }

  Widget _roamingStat(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
              width: 140,
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.black54))),
          Text(value,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _roamingEventRow(int index, SignalRecord r) {
    final time =
        '${r.timestamp.hour.toString().padLeft(2, '0')}:${r.timestamp.minute.toString().padLeft(2, '0')}:${r.timestamp.second.toString().padLeft(2, '0')}';
    final pingStr =
        r.pingMs != null ? '${r.pingMs}ms' : '응답없음';
    final pingColor =
        r.pingMs == null ? Colors.red : (r.pingMs! > 100 ? Colors.orange : Colors.green);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz, size: 14, color: Colors.purple),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '$time  ${r.roamingFromBssid.length > 17 ? r.roamingFromBssid.substring(0, 17) : r.roamingFromBssid} → ${r.shortBssid}',
              style: const TextStyle(fontSize: 11, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(pingStr,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: pingColor)),
        ],
      ),
    );
  }

  Widget _buildNoteInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  hintText: '현재 위치 메모 (예: 창고 입구, 코너 지점)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _addNote,
              child: const Text('메모'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordList() {
    final reversed = _records.reversed.toList();
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text('측정 기록',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reversed.length > 30 ? 30 : reversed.length,
            itemBuilder: (context, index) {
              final r = reversed[index];
              final isShadow = r.rssi < -75;
              return ListTile(
                dense: true,
                leading: r.isRoamingEvent
                    ? const Icon(Icons.swap_horiz, color: Colors.purple, size: 22)
                    : Text(r.signalEmoji,
                        style: const TextStyle(fontSize: 18)),
                title: Row(
                  children: [
                    Text('${r.rssi} dBm',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: r.isRoamingEvent
                              ? Colors.purple
                              : (isShadow ? Colors.red : null),
                        )),
                    const SizedBox(width: 8),
                    if (r.isRoamingEvent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.purple.withAlpha(30),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          '로밍${r.pingMs != null ? "  ${r.pingMs}ms" : "  응답없음"}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.purple,
                              fontWeight: FontWeight.bold),
                        ),
                      )
                    else ...[
                      Text(r.signalLabel,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      if (isShadow)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Text('음영',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ],
                ),
                subtitle: r.note.isNotEmpty
                    ? Text('📍 ${r.note}',
                        style: const TextStyle(
                            color: Colors.blue, fontSize: 12))
                    : (r.isRoamingEvent
                        ? Text(
                            '${r.roamingFromBssid} → ${r.bssid}',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.purple),
                            overflow: TextOverflow.ellipsis,
                          )
                        : null),
                trailing: Text(
                  '${r.timestamp.hour.toString().padLeft(2, '0')}:'
                  '${r.timestamp.minute.toString().padLeft(2, '0')}:'
                  '${r.timestamp.second.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              );
            },
          ),
          if (_records.length > 30)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Center(
                child: Text(
                  '최근 30개 표시 중 (전체 ${_records.length}개)',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
