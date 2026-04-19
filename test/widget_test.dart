import 'package:flutter_test/flutter_test.dart';
import 'package:blink_to_speak/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Just verify the app can be created without crashing
    await tester.pumpWidget(const BlinkToSpeakApp());
  });
}
