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
          backgroundColor: AppTheme.accentDeepPurple,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.check_circle_outline_rounded, color: AppTheme.accentTeal),
              SizedBox(width: 8),
              Text("Settle Outstanding"),
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
                    backgroundColor: AppTheme.accentTeal,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentTeal),
              child: const Text("Settle Now"),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteRecord(BuildContext context, TransactionProvider prov, OutstandingSummary item) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 8),
              Text("Delete Outstanding"),
            ],
          ),
          content: Text(
            "Wipe all ledger statements, invoices, and transactions for ${item.customerName} to clear their outstanding balance?\n\nThis action is irreversible.",
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                prov.deleteLedgerForCustomer(item.customerName);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Outstanding record deleted successfully."),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final transProv = context.watch<TransactionProvider>();
    final list = transProv.getOutstandingSummaries();

    final filteredList = list.where((item) =>
        item.customerName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Accounts Outstanding"),
      ),
      body: Column(
        children: [
          // Search & Summary Header
          Container(
            padding: const EdgeInsets.all(20),
            color: AppTheme.accentDeepPurple.withValues(alpha: 0.04),
            child: Column(
              children: [
                // Outstanding Info Panel + PDF Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Total Outstanding",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currencyFormatter.format(transProv.totalOutstanding),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.accentDeepPurple),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.accentDeepPurple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${filteredList.length} Accounts",
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentDeepPurple),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // DAILY PDF BACKUP BUTTON
                        GestureDetector(
                          onTap: _isGeneratingPdf ? null : () => _generateDailyPdf(list),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.primaryPurple, AppTheme.accentDeepPurple],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isGeneratingPdf)
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                else
                                  const Icon(Icons.picture_as_pdf_rounded, size: 14, color: Colors.white),
                                const SizedBox(width: 6),
                                const Text(
                                  "Daily PDF Backup",
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Search bar
                TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Search customer name...",
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.accentDeepPurple),
                    fillColor: AppTheme.cardBg,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ],
            ),
          ),

          // Outstandings List
          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 56, color: AppTheme.accentTeal.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        const Text(
                          "No outstanding balances found.",
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: filteredList.length,
                    itemBuilder: (ctx, index) {
                      final item = filteredList[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LedgerLookupScreen(initialCustomerName: item.customerName),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppTheme.accentDeepPurple.withValues(alpha: 0.08),
                                  child: const Icon(
                                    Icons.account_circle_outlined,
                                    color: AppTheme.accentDeepPurple,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.customerName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Last Activity: ${DateFormat('dd-MMM-yyyy').format(item.lastTransactionDate)}",
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "${item.balance > 0 ? '-' : '+'} ${currencyFormatter.format(item.balance.abs())}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                        color: item.balance > 0 ? Colors.redAccent : AppTheme.accentTeal,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Tick / Pay Button
                                        GestureDetector(
                                          onTap: () => _confirmSettlement(context, transProv, item),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: AppTheme.accentTeal.withValues(alpha: 0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.check_circle_outline_rounded,
                                              size: 16,
                                              color: AppTheme.accentTeal,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Delete Button
                                        GestureDetector(
                                          onTap: () => _confirmDeleteRecord(context, transProv, item),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.redAccent.withValues(alpha: 0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 16,
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Remind Button
                                        GestureDetector(
                                          onTap: () => _sendReminder(item),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: AppTheme.accentDeepPurple.withValues(alpha: 0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.notifications_none_rounded,
                                              size: 16,
                                              color: AppTheme.accentDeepPurple,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
