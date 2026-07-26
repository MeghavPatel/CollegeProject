import 'package:flutter_test/flutter_test.dart';
import 'package:hp_bill/main.dart';

void main() {
  testWidgets('Smoke test for LavenderMartPOS dashboard loading', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const LavenderMartPOS());

    // Verify that the master password screen title loads successfully
    expect(find.textContaining('HP Bill POS'), findsOneWidget);
  });
}
