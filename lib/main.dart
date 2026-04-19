import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models/wifi_data.dart';
import 'services/wifi_service.dart';
import 'screens/connected_tab.dart';
import 'screens/ap_list_tab.dart';
import 'screens/channel_tab.dart';
import 'screens/report_tab.dart';
import 'screens/shadow_tab.dart';
import 'screens/heatmap_tab.dart';
import 'models/signal_record.dart';

void main() {
  runApp(const WifiScoutApp());
}

class WifiScoutApp extends StatelessWidget {
  const WifiScoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WiFi 진단기',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _wifiService = WifiService();

  List<ApInfo> _apList = [];
  ConnectedNetworkInfo? _connectedInfo;
  List<SignalRecord> _shadowRecords = [];
  bool _isScanning = false;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndScan();
  }

  Future<void> _requestPermissionsAndScan() async {
    if (!kIsWeb) {
      await [
        Permission.location,
        Permission.locationWhenInUse,
      ].request();
    }
    await _scan();
  }

  Future<void> _scan() async {
    setState(() => _isScanning = true);
    try {
      final apList = await _wifiService.scanAccessPoints();
      final connectedInfo = await _wifiService.getConnectedInfo();
      setState(() {
        _apList = apList;
        _connectedInfo = connectedInfo;
      });
    } finally {
      setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ConnectedTab(connectedInfo: _connectedInfo, apList: _apList),
      ApListTab(apList: _apList, connectedSsid: _connectedInfo?.ssid),
      ChannelTab(apList: _apList),
      ShadowTab(
        connectedInfo: _connectedInfo,
        onRecordsUpdated: (records) =>
            setState(() => _shadowRecords = records),
      ),
      ReportTab(
        connectedInfo: _connectedInfo,
        apList: _apList,
        shadowRecords: _shadowRecords,
      ),
      HeatmapTab(connectedInfo: _connectedInfo),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.wifi_find, size: 24),
            SizedBox(width: 8),
            Text('WiFi 진단기', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _scan,
              tooltip: '다시 스캔',
            ),
        ],
      ),
      body: tabs[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _connectedInfo != null,
              child: const Icon(Icons.wifi),
            ),
            label: '연결 정보',
          ),
          NavigationDestination(
            icon: Badge(
              label: _apList.isNotEmpty ? Text('${_apList.length}') : null,
              isLabelVisible: _apList.isNotEmpty,
              child: const Icon(Icons.list),
            ),
            label: '주변 AP',
          ),
          const NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: '채널 현황',
          ),
          const NavigationDestination(
            icon: Icon(Icons.route),
            label: '음영 추적',
          ),
          const NavigationDestination(
            icon: Icon(Icons.summarize),
            label: '리포트',
          ),
          const NavigationDestination(
            icon: Icon(Icons.map),
            label: '히트맵',
          ),
        ],
      ),
    );
  }
}
