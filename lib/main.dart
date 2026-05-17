import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/wifi_data.dart';
import 'services/analytics_service.dart';
import 'services/wifi_service.dart';
import 'services/notification_service.dart';
import 'screens/connected_tab.dart';
import 'screens/ap_list_tab.dart';
import 'screens/channel_tab.dart';
import 'screens/report_tab.dart';
import 'screens/shadow_tab.dart';
import 'screens/heatmap_tab.dart';
import 'screens/history_screen.dart';
import 'models/signal_record.dart';
import 'models/network_quality.dart';

final _themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await Firebase.initializeApp();
  }
  await NotificationService.init();

  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('dark_mode') ?? false;
  _themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  runApp(const WifiScoutApp());
}

class WifiScoutApp extends StatelessWidget {
  const WifiScoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeNotifier,
      builder: (context, themeMode, _) => MaterialApp(
        title: 'WiFi 진단기',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: themeMode,
        home: const HomePage(),
      ),
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
  NetworkQuality? _lastQuality;
  bool _isScanning = false;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndScan();
  }

  Future<void> _toggleTheme() async {
    final isDark = _themeNotifier.value == ThemeMode.dark;
    _themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', !isDark);
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
      AnalyticsService.logScanCompleted(
        apCount: apList.length,
        band24: apList.where((a) => a.band == '2.4GHz').length,
        band5: apList.where((a) => a.band == '5GHz').length,
        band6: apList.where((a) => a.band == '6GHz').length,
      );
    } finally {
      setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ConnectedTab(
        connectedInfo: _connectedInfo,
        apList: _apList,
        onQualityMeasured: (q) => setState(() => _lastQuality = q),
      ),
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
        quality: _lastQuality,
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
          ValueListenableBuilder<ThemeMode>(
            valueListenable: _themeNotifier,
            builder: (_, mode, __) => IconButton(
              icon: Icon(
                  mode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
              tooltip: mode == ThemeMode.dark ? '라이트 모드' : '다크 모드',
              onPressed: _toggleTheme,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '측정 히스토리',
            onPressed: () {
              AnalyticsService.logHistoryViewed();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
          ),
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
        onDestinationSelected: (i) {
          setState(() => _selectedIndex = i);
          AnalyticsService.logTabSelected(i);
        },
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
