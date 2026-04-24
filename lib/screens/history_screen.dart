import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/scan_history.dart';
import '../services/database_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _db = DatabaseService();
  List<ScanHistory> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final records = await _db.getRecent(limit: 200);
    if (mounted) setState(() {
      _records = records;
      _loading = false;
    });
  }

  Future<void> _deleteOne(int id) async {
    await _db.delete(id);
    await _load();
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('전체 삭제'),
        content: const Text('모든 측정 기록을 삭제할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await _db.clearAll();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.history, size: 22),
            SizedBox(width: 8),
            Text('측정 히스토리'),
          ],
        ),
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: '전체 삭제',
              onPressed: _clearAll,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: 12),
                      _buildTrendChart(),
                      const SizedBox(height: 12),
                      _buildRecordList(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('측정 기록이 없습니다',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          SizedBox(height: 8),
          Text('연결 정보 탭에서 품질 측정 또는\n속도 측정을 실행하면 자동 저장됩니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final total = _records.length;
    final withGrade = _records.where((r) => r.grade != null).toList();
    final withSpeed = _records.where((r) => r.speedMbps != null).toList();

    final goodCount = withGrade.where((r) => r.grade == '양호').length;
    final warnCount = withGrade.where((r) => r.grade == '주의').length;
    final badCount = withGrade.where((r) => r.grade == '위험').length;

    final avgSpeed = withSpeed.isEmpty
        ? null
        : withSpeed.map((r) => r.speedMbps!).reduce((a, b) => a + b) /
            withSpeed.length;

    final avgRssi = _records.isEmpty
        ? null
        : (_records.map((r) => r.rssi).reduce((a, b) => a + b) /
                _records.length)
            .round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('전체 $total회 측정',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (_records.isNotEmpty)
              Text(
                '${_fmt(_records.last.measuredAt)} ~ ${_fmt(_records.first.measuredAt)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statChip('평균 RSSI',
                    avgRssi != null ? '${avgRssi}dBm' : '-', Colors.blue),
                if (avgSpeed != null)
                  _statChip('평균 속도',
                      '${avgSpeed.toStringAsFixed(1)}Mbps', Colors.teal),
                if (withGrade.isNotEmpty) ...[
                  _statChip('✅ 양호', '$goodCount', Colors.green),
                  _statChip('🟡 주의', '$warnCount', Colors.orange),
                  _statChip('❌ 위험', '$badCount', Colors.red),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildTrendChart() {
    // 최근 50개, 시간 오름차순
    final data = _records.reversed.take(50).toList();
    if (data.length < 2) return const SizedBox.shrink();

    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.rssi.toDouble());
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 8),
              child: Text('RSSI 트렌드 (최근 50회)',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 160,
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
                        getDotPainter: (spot, _, __, ___) =>
                            FlDotCirclePainter(
                          radius: 3,
                          color: spot.y < -75 ? Colors.red : Colors.blue,
                          strokeWidth: 0,
                          strokeColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: -75,
                        color: Colors.red.withAlpha(120),
                        strokeWidth: 1,
                        dashArray: [6, 4],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          labelResolver: (_) => '음영 -75dBm',
                          style: const TextStyle(
                              fontSize: 9, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 20,
                        reservedSize: 38,
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

  Widget _buildRecordList() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text('측정 기록',
                style:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _records.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 16),
            itemBuilder: (context, i) {
              final r = _records[i];
              return Dismissible(
                key: ValueKey(r.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => _deleteOne(r.id!),
                child: ListTile(
                  dense: true,
                  leading: Text(r.gradeEmoji,
                      style: const TextStyle(fontSize: 22)),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(r.ssid,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (r.grade != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: r.gradeColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(r.grade!,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: r.gradeColor,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    _buildSubtitle(r),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  trailing: Text(
                    _fmtFull(r.measuredAt),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    textAlign: TextAlign.end,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _buildSubtitle(ScanHistory r) {
    final parts = <String>[
      '${r.rssi}dBm  ${r.band}  Ch${r.channel}',
      if (r.avgMs != null) '지연 ${r.avgMs}ms',
      if (r.jitterMs != null) 'Jitter ${r.jitterMs}ms',
      if (r.lossRate != null) '손실 ${r.lossRate!.toStringAsFixed(1)}%',
      if (r.speedMbps != null)
        '${r.speedMbps!.toStringAsFixed(1)}Mbps',
    ];
    return parts.join('  •  ');
  }

  String _fmt(DateTime dt) => DateFormat('MM/dd').format(dt);
  String _fmtFull(DateTime dt) =>
      '${DateFormat('MM/dd').format(dt)}\n${DateFormat('HH:mm').format(dt)}';
}
