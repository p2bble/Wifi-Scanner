import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_scout/main.dart';

void main() {
  testWidgets('WifiScoutApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const WifiScoutApp());
    expect(find.text('WiFi Scout'), findsOneWidget);
  });
}
