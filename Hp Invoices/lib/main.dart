import 'package:flutter/material.dart';
import 'package:hp_bill/providers/invoice_provider.dart';
import 'package:hp_bill/providers/sync_provider.dart';
import 'package:hp_bill/providers/transaction_provider.dart';
import 'package:hp_bill/screens/master_password_screen.dart';
import 'package:hp_bill/services/database_helper.dart';
import 'package:hp_bill/theme/app_theme.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the persistent database helper (loads from SharedPreferences)
  await DatabaseHelper.instance.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SyncProvider()),
        ChangeNotifierProvider(create: (_) => InvoiceProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
      ],
      child: const LavenderMartPOS(),
    ),
  );
}

class LavenderMartPOS extends StatelessWidget {
  const LavenderMartPOS({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HP Bill POS',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const MasterPasswordScreen(),
    );
  }
}
