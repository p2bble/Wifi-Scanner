import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/wifi_data.dart';

class ApListTab extends StatelessWidget {
  final List<ApInfo> apList;
  final String? connectedSsid;

  const ApListTab({
    super.key,
    required this.apList,
    this.connectedSsid,
  });

  @override
  Widget build(BuildContext context) {
    if (apList.isEmpty) {
      if (kIsWeb) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.smartphone, size: 56, color: Colors.grey),
              SizedBox(height: 16),
              Text('AP 스캔은 Android 앱에서만 지원됩니다',
                  style: TextStyle(fontSize: 15, color: Colors.grey)),
              SizedBox(height: 8),
              Text('브라우저(iOS/웹) 환경에서는 보안 정책상\n주변 WiFi 목록을 읽을 수 없습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        );
      }
      return const Center(
        child: Text('주변 AP를 탐지하지 못했습니다.\n새로고침을 시도해보세요.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: apList.length,
      itemBuilder: (context, index) {
        final ap = apList[index];
        final isConnected = ap.ssid == connectedSsid;
        return _ApTile(ap: ap, isConnected: isConnected);
      },
    );
  }
}

class _ApTile extends StatelessWidget {
  final ApInfo ap;
  final bool isConnected;

  const _ApTile({required this.ap, required this.isConnected});

  Color _signalColor() {
    if (ap.rssi >= -60) return Colors.green;
    if (ap.rssi >= -70) return Colors.orange;
    return Colors.red;
  }

  IconData _signalIcon() {
    if (ap.rssi >= -60) return Icons.signal_wifi_4_bar;
    if (ap.rssi >= -70) return Icons.network_wifi_3_bar;
    return Icons.signal_wifi_bad;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: isConnected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        leading: Icon(_signalIcon(), color: _signalColor(), size: 32),
        title: Row(
          children: [
            Expanded(
              child: Text(
                ap.ssid,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isConnected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('연결됨', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
          ],
        ),
        subtitle: Text(
          '${ap.rssi} dBm  •  ${ap.band}  •  Ch${ap.channel}  •  ${ap.wifiStandard}  •  ${ap.isSecure ? "🔒" : "🔓"}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          ap.signalLabel,
          style: TextStyle(
            fontSize: 12,
            color: _signalColor(),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
