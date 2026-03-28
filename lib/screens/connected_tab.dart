import 'package:flutter/material.dart';
import '../models/wifi_data.dart';
import '../services/wifi_service.dart';

class ConnectedTab extends StatefulWidget {
  final ConnectedNetworkInfo? connectedInfo;
  final List<ApInfo> apList;

  const ConnectedTab({
    super.key,
    required this.connectedInfo,
    required this.apList,
  });

  @override
  State<ConnectedTab> createState() => _ConnectedTabState();
}

class _ConnectedTabState extends State<ConnectedTab> {
  final _wifiService = WifiService();
  int? _gatewayPing;
  int? _internetPing;
  bool _pinging = false;

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
    setState(() {
      _gatewayPing = results[0];
      _internetPing = results[1];
      _pinging = false;
    });
  }

  ApInfo? get _connectedAp {
    if (widget.connectedInfo == null) return null;
    try {
      return widget.apList.firstWhere(
        (ap) => ap.ssid == widget.connectedInfo!.ssid,
      );
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
            Text('WiFi에 연결되지 않았습니다', style: TextStyle(fontSize: 16, color: Colors.grey)),
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
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (ap != null) ...[
              _infoRow('신호 세기', '${ap.rssi} dBm  ${ap.signalEmoji} ${ap.signalLabel}'),
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
            const Text('네트워크 정보', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            _infoRow('IP 주소', info.ipAddress.isEmpty ? '-' : info.ipAddress),
            _infoRow('게이트웨이', info.gateway.isEmpty ? '-' : info.gateway),
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
                const Text('응답 속도 (Ping)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (_pinging)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
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
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Text(value, style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }
}
