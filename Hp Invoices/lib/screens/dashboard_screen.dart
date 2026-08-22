import 'package:flutter/material.dart';
import 'package:hp_bill/providers/invoice_provider.dart';
import 'package:hp_bill/providers/sync_provider.dart';
import 'package:hp_bill/providers/transaction_provider.dart';
import 'package:hp_bill/screens/admin_screen.dart';
import 'package:hp_bill/screens/cash_bank_entry_screen.dart';
import 'package:hp_bill/screens/history_screen.dart';
import 'package:hp_bill/screens/ledger_lookup_screen.dart';
import 'package:hp_bill/screens/outstanding_screen.dart';
import 'package:hp_bill/screens/sales_invoice_screen.dart';
import 'package:hp_bill/screens/sales_invoices_list_screen.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InvoiceProvider>().fetchInvoices();
      context.read<InvoiceProvider>().fetchStoreDetails();
      context.read<TransactionProvider>().fetchTransactions();
    });
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
      backgroundColor: AppTheme.surface,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.dashboardBgGradient,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- TOP HEADER ---
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryEmerald,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryEmerald.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  "IG",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              invoiceProv.storeName.isNotEmpty ? invoiceProv.storeName : "Invoice Generator",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "Billing & POS Dashboard",
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // History Action
                        GestureDetector(
                          onTap: _openHistoryOverlay,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainerLowest,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.outlineVariant),
                              boxShadow: AppTheme.softShadow,
                            ),
                            child: const Icon(
                              Icons.history_rounded,
                              color: AppTheme.primaryEmerald,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Settings / Admin Action
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminScreen()),
                            );
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainerLowest,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.outlineVariant),
                              boxShadow: AppTheme.softShadow,
                            ),
                            child: const Icon(
                              Icons.settings_rounded,
                              color: AppTheme.secondarySlate,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // --- ONLINE / OFFLINE STATUS PILL ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: GestureDetector(
                  onTap: () {
                    syncProv.toggleConnection();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(syncProv.isOnline
                            ? "Connected online. Syncing data..."
                            : "Working offline. Changes cached locally."),
                        backgroundColor: syncProv.isOnline ? AppTheme.primaryEmerald : AppTheme.secondarySlate,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: syncProv.isOnline
                          ? AppTheme.primaryEmerald.withValues(alpha: 0.1)
                          : AppTheme.secondarySlate.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: syncProv.isOnline
                            ? AppTheme.primaryEmerald.withValues(alpha: 0.3)
                            : AppTheme.secondarySlate.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: syncProv.isOnline ? AppTheme.tertiaryMint : AppTheme.secondarySlate,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          syncProv.isOnline ? "Online" : "Offline",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: syncProv.isOnline ? AppTheme.primaryEmerald : AppTheme.secondarySlate,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // --- OUTSTANDING HERO CARD ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: AppTheme.heroCardGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryEmerald.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Watermark wallet icon
                      Positioned(
                        right: -10,
                        top: -15,
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 110,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
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
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withValues(alpha: 0.8),
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    currencyFormatter.format(transProv.totalOutstanding),
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // --- QUICK OPERATIONS TITLE ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  "Quick Operations",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // --- QUICK OPERATIONS GRID ---
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.2,
                    children: [
                      // 1. Create Invoice
                      _buildDashboardTile(
                        context: context,
                        title: "Create Invoice",
                        subtitle: "Create new bill",
                        icon: Icons.post_add_rounded,
                        iconBgColor: AppTheme.primaryLight.withValues(alpha: 0.4),
                        accentColor: AppTheme.primaryEmerald,
                        onTap: () async {
                          await invoiceProv.initializeNewInvoice();
                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SalesInvoiceScreen()),
                          );
                        },
                      ),
                      // 2. Sales Invoice (View/Edit/Delete invoices)
                      _buildDashboardTile(
                        context: context,
                        title: "Sales Invoice",
                        subtitle: "Edit & delete invoices",
                        icon: Icons.receipt_long_rounded,
                        iconBgColor: AppTheme.secondaryContainer,
                        accentColor: AppTheme.secondarySlate,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SalesInvoicesListScreen()),
                          );
                        },
                      ),
                      // 3. Cash/Bank Entry
                      _buildDashboardTile(
                        context: context,
                        title: "Cash/Bank",
                        subtitle: "Quick log entry",
                        icon: Icons.account_balance_rounded,
                        iconBgColor: AppTheme.secondaryContainer,
                        accentColor: AppTheme.secondarySlate,
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
                        icon: Icons.pending_actions_rounded,
                        iconBgColor: AppTheme.secondaryContainer,
                        accentColor: AppTheme.secondarySlate,
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
                        iconBgColor: AppTheme.secondaryContainer,
                        accentColor: AppTheme.secondarySlate,
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
              ),
            ],
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
    required Color iconBgColor,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.outlineVariant),
            boxShadow: AppTheme.tileShadow(accentColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 24,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
