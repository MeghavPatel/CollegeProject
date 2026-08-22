import 'package:flutter/material.dart';
import 'package:hp_bill/providers/transaction_provider.dart';
import 'package:hp_bill/screens/ledger_lookup_screen.dart';
import 'package:hp_bill/services/print_service.dart';
import 'package:hp_bill/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class OutstandingScreen extends StatefulWidget {
  const OutstandingScreen({Key? key}) : super(key: key);

  @override
  State<OutstandingScreen> createState() => _OutstandingScreenState();
}

class _OutstandingScreenState extends State<OutstandingScreen> {
  final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ');
  String _searchQuery = '';
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().fetchTransactions();
    });
  }

  void _sendReminder(OutstandingSummary outstanding) {
    final message = 
        "Dear *${outstanding.customerName}*,\n\n"
        "This is a friendly reminder regarding your outstanding balance of *${currencyFormatter.format(outstanding.balance)}*.\n\n"
        "Please settle this at your earliest convenience. Thank you! 🙏";
    
    Share.share(message, subject: "Payment Reminder");
  }

  Future<void> _generateDailyPdf(List<OutstandingSummary> summaries) async {
    setState(() => _isGeneratingPdf = true);
    try {
      await PrintService.instance.printOutstandingReport(summaries);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Daily outstanding PDF generated!"),
          backgroundColor: AppTheme.primaryEmerald,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("PDF generation failed: $e")),
      );
    }
    setState(() => _isGeneratingPdf = false);
  }

  void _confirmSettlement(BuildContext context, TransactionProvider prov, OutstandingSummary item) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: const [
              Icon(Icons.check_circle_outline_rounded, color: AppTheme.primaryEmerald),
              SizedBox(width: 8),
              Text("Settle Outstanding", style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          content: Text(
            "Mark ${item.customerName}'s balance of ${currencyFormatter.format(item.balance)} as PAID?\n\nThis will log a receipt entry straight into their ledger.",
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                prov.settleOutstanding(item.customerName, item.balance);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Balance for ${item.customerName} marked as settled!"),
                    backgroundColor: AppTheme.primaryEmerald,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryEmerald),
              child: const Text("Settle Now"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final transProv = context.watch<TransactionProvider>();
    final outstandingList = transProv.getOutstandingSummary();

    final filteredList = outstandingList.where((item) {
      return item.customerName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text("Accounts Outstanding"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Summary & Actions Card matching Stitch UI ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.outlineVariant),
                boxShadow: AppTheme.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "TOTAL OUTSTANDING",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currencyFormatter.format(transProv.totalOutstanding),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryEmerald,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.group_rounded, size: 14, color: AppTheme.secondarySlate),
                            const SizedBox(width: 4),
                            Text(
                              "${outstandingList.length} Accounts",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isGeneratingPdf
                          ? null
                          : () => _generateDailyPdf(outstandingList),
                      icon: _isGeneratingPdf
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                      label: const Text("Daily PDF Backup"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryEmerald,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --- Search Bar ---
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                hintText: "Search customer name...",
                prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primaryEmerald),
              ),
            ),

            const SizedBox(height: 16),

            // --- List Header ---
            Text(
              "Pending Accounts",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            if (filteredList.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 48,
                      color: AppTheme.tertiaryMint,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "No outstanding balances found!",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      "All customer ledgers are clear and settled.",
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredList.length,
                itemBuilder: (ctx, index) {
                  final item = filteredList[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.outlineVariant),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item.customerName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              currencyFormatter.format(item.balance),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.errorRed,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${item.invoiceCount} invoices • Last updated recently",
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.errorContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "PENDING",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1, color: AppTheme.accentBorder),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // View Ledger button
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LedgerLookupScreen(
                                      initialCustomerName: item.customerName,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.receipt_long_rounded, size: 16, color: AppTheme.primaryEmerald),
                              label: const Text(
                                "View Ledger",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryEmerald,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _sendReminder(item),
                                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                                  label: const Text("Reminder", style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () => _confirmSettlement(context, transProv, item),
                                  icon: const Icon(Icons.check_rounded, size: 14),
                                  label: const Text("Settle", style: TextStyle(fontSize: 11)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryEmerald,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
