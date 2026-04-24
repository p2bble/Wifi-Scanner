import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/wifi_data.dart';

class ChannelTab extends StatelessWidget {
  final List<ApInfo> apList;

  const ChannelTab({super.key, required this.apList});

  // 최적 채널 추천 (가장 AP 수가 적고, 인접 채널 간섭도 낮은 채널)
  Map<String, dynamic> _recommendChannel(List<ApInfo> aps, List<int> candidates) {
    if (aps.isEmpty) return {'channel': candidates.first, 'reason': 'AP 없음'};
    final Map<int, int> countMap = {};
    for (final ap in aps) {
      countMap[ap.channel] = (countMap[ap.channel] ?? 0) + 1;
    }
    int bestCh = candidates.first;
    int bestScore = 999;
    for (final ch in candidates) {
      // 해당 채널 + 인접 ±2 채널의 AP 수 합산
      int score = 0;
      for (int offset = -2; offset <= 2; offset++) {
        score += countMap[ch + offset] ?? 0;
      }
      if (score < bestScore) {
        bestScore = score;
        bestCh = ch;
      }
    }
    final count = countMap[bestCh] ?? 0;
    final reason = count == 0 ? '사용 중인 AP 없음 — 최적' : '$count개 AP 사용 중 — 가장 여유';
    return {'channel': bestCh, 'reason': reason};
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb && apList.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 56, color: Colors.grey),
            SizedBox(height: 16),
            Text('채널 분석은 Android 앱에서만 지원됩니다',
                style: TextStyle(fontSize: 15, color: Colors.grey)),
            SizedBox(height: 8),
            Text('브라우저(iOS/웹) 환경에서는 보안 정책상\n주변 AP 채널 정보를 읽을 수 없습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    final band24 = apList.where((ap) => ap.band == '2.4GHz').toList();
    final band5 = apList.where((ap) => ap.band == '5GHz').toList();
    final band6 = apList.where((ap) => ap.band == '6GHz').toList();

    // 2.4GHz 비겹침 채널: 1, 6, 11
    final rec24 = _recommendChannel(band24, [1, 6, 11]);
    // 5GHz 주요 채널
    final rec5 = _recommendChannel(band5, [36, 40, 44, 48, 149, 153, 157, 161]);
    // 6GHz PSC(Preferred Scanning Channel) — 16채널 간격
    final rec6 = band6.isNotEmpty
        ? _recommendChannel(band6, [5, 21, 37, 53, 69, 85, 101, 117, 133, 149, 165, 181, 197, 213, 229])
        : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRecommendCard(rec24, rec5, rec6),
        const SizedBox(height: 16),
        _buildBandSection('2.4GHz 채널 현황', band24, Colors.orange),
        const SizedBox(height: 16),
        _buildBandSection('5GHz 채널 현황', band5, Colors.blue),
        if (band6.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildBandSection('6GHz 채널 현황 (Wi-Fi 6E/7)', band6, Colors.teal),
        ],
      ],
    );
  }

  Widget _buildRecommendCard(
    Map<String, dynamic> rec24,
    Map<String, dynamic> rec5,
    Map<String, dynamic>? rec6,
  ) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text('최적 채널 추천',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),
            _recommendRow('2.4GHz', rec24['channel'], rec24['reason'], Colors.orange),
            const SizedBox(height: 8),
            _recommendRow('5GHz', rec5['channel'], rec5['reason'], Colors.blue),
            if (rec6 != null) ...[
              const SizedBox(height: 8),
              _recommendRow('6GHz', rec6['channel'], rec6['reason'], Colors.teal),
            ],
            const SizedBox(height: 8),
            const Text(
              '* AP 공유기의 채널 설정에서 변경하세요',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            if (rec6 != null)
              const Text(
                '* 6GHz는 PSC(Preferred Scanning Channel) 기준 추천',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _recommendRow(String band, int channel, String reason, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(band,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Text('Ch $channel  ',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        Expanded(
          child: Text(reason,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _buildBandSection(String title, List<ApInfo> aps, Color color) {
    if (aps.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('탐지된 AP 없음', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final Map<int, List<ApInfo>> channelMap = {};
    for (final ap in aps) {
      channelMap.putIfAbsent(ap.channel, () => []).add(ap);
    }

    final sortedChannels = channelMap.keys.toList()..sort();
    final maxCount = channelMap.values.map((v) => v.length).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${aps.length}개 AP 탐지', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: (maxCount + 1).toDouble(),
                  barGroups: sortedChannels.map((ch) {
                    final count = channelMap[ch]!.length;
                    final isCongested = count >= 3;
                    return BarChartGroupData(
                      x: ch,
                      barRods: [
                        BarChartRodData(
                          toY: count.toDouble(),
                          color: isCongested ? Colors.red : color,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) => Text(
                          'Ch${val.toInt()}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (val, meta) => Text(
                          '${val.toInt()}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...sortedChannels.map((ch) => _channelRow(ch, channelMap[ch]!, color)),
          ],
        ),
      ),
    );
  }

  Widget _channelRow(int channel, List<ApInfo> aps, Color color) {
    final isCongested = aps.length >= 3;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text('Ch $channel', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              aps.map((ap) => ap.ssid).join(', '),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isCongested ? Colors.red.withAlpha(25) : color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${aps.length}개 ${isCongested ? "⚠️ 혼잡" : ""}',
              style: TextStyle(
                fontSize: 12,
                color: isCongested ? Colors.red : color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
