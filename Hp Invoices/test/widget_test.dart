import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hp_bill/main.dart';
import 'package:hp_bill/providers/invoice_provider.dart';
import 'package:hp_bill/providers/sync_provider.dart';
import 'package:hp_bill/providers/transaction_provider.dart';
import 'package:hp_bill/services/database_helper.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Unlock with 0394 and render DashboardScreen', (WidgetTester tester) async {
    await DatabaseHelper.instance.init();

    final syncProv = SyncProvider();
    final invoiceProv = InvoiceProvider();
    final transProv = TransactionProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: syncProv),
          ChangeNotifierProvider.value(value: invoiceProv),
          ChangeNotifierProvider.value(value: transProv),
        ],
        child: const LavenderMartPOS(),
      ),
    );

    await tester.pump(const Duration(seconds: 1));

    // Verify master password screen is shown
    expect(find.textContaining('HP Bill POS'), findsOneWidget);

    // Enter master password '0394'
    await tester.enterText(find.byType(TextField), '0394');
    await tester.pump(const Duration(milliseconds: 100));

    // Tap Unlock
    await tester.tap(find.text('Unlock'));
    await tester.pump(const Duration(seconds: 1));

    // Check if DashboardScreen elements are visible
    expect(find.textContaining('Billing & POS Dashboard'), findsOneWidget);
    expect(find.textContaining('Quick Operations'), findsOneWidget);

    syncProv.dispose();
    invoiceProv.dispose();
    transProv.dispose();
  });
}
