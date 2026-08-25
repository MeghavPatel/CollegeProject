import 'package:flutter/material.dart';
import 'package:hp_bill/providers/invoice_provider.dart';
import 'package:hp_bill/providers/sync_provider.dart';
import 'package:hp_bill/providers/transaction_provider.dart';
import 'package:hp_bill/screens/admin_screen.dart';
import 'package:hp_bill/screens/cash_bank_entry_screen.dart';
import 'package:hp_bill/screens/history_screen.dart';
import 'package:hp_bill/screens/ledger_lookup_screen.dart';
import 'package:hp_bill/screens/outstanding_screen.dart';
import 'package:hp_bill/screens/sales_invoice_list_screen.dart';
import 'package:hp_bill/screens/sales_invoice_screen.dart';
import 'package:hp_bill/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) return;
        await context.read<InvoiceProvider>().fetchInvoices();
        if (!mounted) return;
        await context.read<InvoiceProvider>().fetchStoreDetails();
        if (!mounted) return;
        await context.read<TransactionProvider>().fetchTransactions();

        // Start real-time Firestore listeners for cross-device live sync
        if (!mounted) return;
        context.read<InvoiceProvider>().startRealtimeSync();
        if (!mounted) return;
        context.read<TransactionProvider>().startRealtimeSync();
      } catch (e) {
        debugPrint("Dashboard init notice: $e");
      }
    });
  }

  bool _isRefreshing = false;

  Future<void> _handleManualRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await context.read<InvoiceProvider>().manualCloudRefresh();
      if (mounted) {
        await context.read<TransactionProvider>().fetchTransactions();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Dashboard refreshed & synced with Cloud!"),
            backgroundColor: AppTheme.accentTeal,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Refresh error: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _openHistoryOverlay() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const HistoryOverlay(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoiceProv = context.watch<InvoiceProvider>();
    final transProv = context.watch<TransactionProvider>();
    final syncProv = context.watch<SyncProvider>();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.dashboardBgGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- HEADER WITH SETTINGS & HISTORY ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Text(
                                  "hp",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.primaryPurple,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                invoiceProv.storeName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "Billing & POS Dashboard",
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // Refresh button
                          GestureDetector(
                            onTap: _handleManualRefresh,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.cardBg,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.accentBorder),
                                boxShadow: AppTheme.softShadow,
                              ),
                              child: _isRefreshing
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.accentTeal,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.sync_rounded,
                                      color: AppTheme.accentTeal,
                                      size: 20,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // History button
                          GestureDetector(
                            onTap: _openHistoryOverlay,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.cardBg,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.accentBorder),
                                boxShadow: AppTheme.softShadow,
                              ),
                              child: const Icon(
                                Icons.history_rounded,
                                color: AppTheme.primaryPurple,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Settings button
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AdminScreen()),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.cardBg,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.accentBorder),
                                boxShadow: AppTheme.softShadow,
                              ),
                              child: const Icon(
                                Icons.settings_rounded,
                                color: AppTheme.textSecondary,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // --- CLOUD ONLINE STATUS ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accentTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.accentTeal.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.accentTeal,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "Cloud Sync • Online",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // --- OUTSTANDING METRICS PANEL ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryPurple, AppTheme.accentDeepPurple],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.hourglass_bottom_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "TOTAL OUTSTANDING",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withValues(alpha: 0.75),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currencyFormatter.format(transProv.totalOutstanding),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // --- CORE MODULE TILES (GRID) ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    "Quick Operations",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                    children: [
                      // 1. Create Invoice
                      _buildDashboardTile(
                        context: context,
                        title: "Create Invoice",
                        subtitle: "Create new bill",
                        icon: Icons.post_add_rounded,
                        accentColor: AppTheme.accentTeal,
                        onTap: () async {
                          await invoiceProv.initializeNewInvoice();
                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SalesInvoiceScreen()),
                          );
                        },
                      ),
                      // 2. Sales Invoice (Old Invoices List)
                      _buildDashboardTile(
                        context: context,
                        title: "Sales Invoice",
                        subtitle: "Edit & delete invoices",
                        icon: Icons.receipt_long_rounded,
                        accentColor: AppTheme.primaryPurple,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SalesInvoiceListScreen()),
                          );
                        },
                      ),
                      // 3. Cash/Bank Entry
                      _buildDashboardTile(
                        context: context,
                        title: "Cash/Bank",
                        subtitle: "Quick log entry",
                        icon: Icons.account_balance_wallet_rounded,
                        accentColor: AppTheme.accentBlue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CashBankEntryScreen()),
                          );
                        },
                      ),
                      // 4. Outstanding
                      _buildDashboardTile(
                        context: context,
                        title: "Outstanding",
                        subtitle: "Pending balances",
                        icon: Icons.hourglass_bottom_rounded,
                        accentColor: AppTheme.accentDeepPurple,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const OutstandingScreen()),
                          );
                        },
                      ),
                      // 5. Ledger Lookup
                      _buildDashboardTile(
                        context: context,
                        title: "A/c. Ledger",
                        subtitle: "Recent ledgers",
                        icon: Icons.manage_accounts_rounded,
                        accentColor: AppTheme.accentIndigo,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LedgerLookupScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.accentBorder),
          boxShadow: AppTheme.tileShadow(accentColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: accentColor,
                size: 26,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
