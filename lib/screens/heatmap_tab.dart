import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wifi_scan/wifi_scan.dart';
import '../models/heatmap_point.dart';
import '../models/wifi_data.dart';

class HeatmapTab extends StatefulWidget {
  final ConnectedNetworkInfo? connectedInfo;

  const HeatmapTab({super.key, required this.connectedInfo});

  @override
  State<HeatmapTab> createState() => _HeatmapTabState();
}

class _HeatmapTabState extends State<HeatmapTab> {
  File? _floorPlanImage;
  final List<HeatmapPoint> _points = [];
  bool _pinMode = false;      // 탭으로 핀 찍기 모드
  int? _currentRssi;
  Timer? _rssiTimer;
  final _noteController = TextEditingController();
  final _transformController = TransformationController();

  // 이미지 실제 렌더 크기를 트래킹하기 위한 키
  final _imageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _startRssiPolling();
  }

  @override
  void dispose() {
    _rssiTimer?.cancel();
    _noteController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _startRssiPolling() {
    _rssiTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final rssi = await _fetchRssi();
      if (mounted) setState(() => _currentRssi = rssi);
    });
  }

  Future<int?> _fetchRssi() async {
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _floorPlanImage = File(picked.path);
        _points.clear();
        _transformController.value = Matrix4.identity();
      });
    }
  }

  void _onImageTap(TapDownDetails details, BoxConstraints constraints) {
    if (!_pinMode || _currentRssi == null) return;

    // InteractiveViewer 내부에서의 실제 좌표 역산
    final matrix = _transformController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();

    // 탭 위치를 이미지 좌표로 변환
    final tapX = (details.localPosition.dx - translation.x) / scale;
    final tapY = (details.localPosition.dy - translation.y) / scale;

    // 이미지 렌더 크기 조회
    final RenderBox? renderBox =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final imgSize = renderBox.size;

    // 비율로 저장 (이미지 크기 독립적)
    final xRatio = (tapX / imgSize.width).clamp(0.0, 1.0);
    final yRatio = (tapY / imgSize.height).clamp(0.0, 1.0);

    setState(() {
      _points.add(HeatmapPoint(
        xRatio: xRatio,
        yRatio: yRatio,
        rssi: _currentRssi!,
        timestamp: DateTime.now(),
        note: _noteController.text.trim(),
      ));
    });
    if (_noteController.text.isNotEmpty) _noteController.clear();
  }

  void _removeLastPoint() {
    if (_points.isEmpty) return;
    setState(() => _points.removeLast());
  }

  void _clearPoints() {
    setState(() => _points.clear());
  }

  Color _rssiColor(int rssi) {
    if (rssi >= -50) return Colors.green;
    if (rssi >= -60) return Colors.lightGreen;
    if (rssi >= -70) return Colors.yellow.shade700;
    if (rssi >= -80) return Colors.orange;
    return Colors.red;
  }

  String _rssiLabel(int rssi) {
    if (rssi >= -50) return '매우 좋음';
    if (rssi >= -60) return '좋음';
    if (rssi >= -70) return '보통';
    if (rssi >= -80) return '나쁨';
    return '매우 나쁨';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        if (_currentRssi != null) _buildRssiBar(),
        Expanded(
          child: _floorPlanImage == null ? _buildNoImageState() : _buildMap(),
        ),
        if (_points.isNotEmpty) _buildLegend(),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: kIsWeb ? null : _pickImage,
            icon: const Icon(Icons.map, size: 18),
            label: Text(_floorPlanImage == null ? '도면 불러오기' : '도면 변경'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
          if (_floorPlanImage != null) ...[
            FilterChip(
              label: Text(_pinMode ? '핀 찍기 ON' : '핀 찍기 OFF'),
              selected: _pinMode,
              onSelected: (v) => setState(() => _pinMode = v),
              selectedColor: Colors.blue.withAlpha(60),
              avatar: Icon(
                _pinMode ? Icons.push_pin : Icons.push_pin_outlined,
                size: 16,
                color: _pinMode ? Colors.blue : null,
              ),
            ),
            const Spacer(),
            if (_points.isNotEmpty) ...[
              IconButton(
                icon: const Icon(Icons.undo, size: 20),
                onPressed: _removeLastPoint,
                tooltip: '마지막 포인트 삭제',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_sweep, size: 20),
                onPressed: _clearPoints,
                tooltip: '전체 삭제',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildRssiBar() {
    final rssi = _currentRssi!;
    final color = _rssiColor(rssi);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: color.withAlpha(30),
      child: Row(
        children: [
          Icon(Icons.wifi, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            '현재 신호: $rssi dBm  — ${_rssiLabel(rssi)}',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: color),
          ),
          if (_pinMode) ...[
            const Spacer(),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  hintText: '위치 메모',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoImageState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('물류센터 도면을 불러오세요',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('갤러리에서 평면도 이미지를 선택하면\n탭한 위치에 신호 강도를 색상으로 표시합니다',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center),
          if (kIsWeb) ...[
            const SizedBox(height: 12),
            const Text('Android 앱에서만 사용 가능합니다',
                style: TextStyle(fontSize: 12, color: Colors.orange)),
          ],
        ],
      ),
    );
  }

  Widget _buildMap() {
    return GestureDetector(
      onTapDown: (details) {
        if (_pinMode) {
          // InteractiveViewer의 레이아웃 크기 기준으로 좌표 보정
          final RenderBox? box =
              context.findRenderObject() as RenderBox?;
          if (box == null) return;
          _onImageTap(details, BoxConstraints.tight(box.size));
        }
      },
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: 0.5,
        maxScale: 5.0,
        child: Stack(
          children: [
            Image.file(
              _floorPlanImage!,
              key: _imageKey,
              fit: BoxFit.contain,
              width: double.infinity,
            ),
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return CustomPaint(
                    painter: _HeatmapPainter(
                      points: _points,
                      rssiColor: _rssiColor,
                      imageSize: Size(constraints.maxWidth, constraints.maxHeight),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Text('${_points.length}개 포인트',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          _legendItem(Colors.green, '≥ -50'),
          _legendItem(Colors.lightGreen, '≥ -60'),
          _legendItem(Colors.yellow.shade700, '≥ -70'),
          _legendItem(Colors.orange, '≥ -80'),
          _legendItem(Colors.red, '< -80'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final List<HeatmapPoint> points;
  final Color Function(int rssi) rssiColor;
  final Size imageSize;

  _HeatmapPainter({
    required this.points,
    required this.rssiColor,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in points) {
      final x = p.xRatio * size.width;
      final y = p.yRatio * size.height;
      final color = rssiColor(p.rssi);

      // 반투명 후광 (신호 범위 시각화)
      canvas.drawCircle(
        Offset(x, y),
        22,
        Paint()
          ..color = color.withAlpha(50)
          ..style = PaintingStyle.fill,
      );

      // 외곽선
      canvas.drawCircle(
        Offset(x, y),
        10,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      // 내부 채움
      canvas.drawCircle(
        Offset(x, y),
        8,
        Paint()
          ..color = color.withAlpha(200)
          ..style = PaintingStyle.fill,
      );

      // RSSI 수치 텍스트
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${p.rssi}',
          style: TextStyle(
            fontSize: 9,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                  offset: const Offset(0, 0),
                  blurRadius: 2,
                  color: Colors.black.withAlpha(180)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );

      // 메모가 있는 경우 핀 아이콘 위에 표시
      if (p.note.isNotEmpty) {
        final notePainter = TextPainter(
          text: TextSpan(
            text: '📍${p.note}',
            style: const TextStyle(fontSize: 9, color: Colors.black87),
          ),
          textDirection: TextDirection.ltr,
        );
        notePainter.layout(maxWidth: 80);
        // 배경 사각형
        final noteRect = Rect.fromLTWH(
          x + 12,
          y - notePainter.height / 2,
          notePainter.width + 4,
          notePainter.height + 2,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(noteRect, const Radius.circular(3)),
          Paint()..color = Colors.white.withAlpha(200),
        );
        notePainter.paint(canvas, Offset(x + 14, y - notePainter.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) => old.points != points;
}
