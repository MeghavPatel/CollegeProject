import 'package:flutter/material.dart';
import 'package:hp_bill/models/ledger_entry.dart';
import 'package:hp_bill/providers/invoice_provider.dart';
import 'package:hp_bill/providers/transaction_provider.dart';
import 'package:hp_bill/screens/pdf_viewer_screen.dart';
import 'package:hp_bill/services/print_service.dart';
import 'package:hp_bill/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class LedgerLookupScreen extends StatefulWidget {
  final String? initialCustomerName;
  const LedgerLookupScreen({Key? key, this.initialCustomerName}) : super(key: key);

  @override
  State<LedgerLookupScreen> createState() => _LedgerLookupScreenState();
}

class _LedgerLookupScreenState extends State<LedgerLookupScreen> {
  final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ');
  final dateFormatter = DateFormat('dd-MMM-yyyy');
  final _searchController = TextEditingController();

  // PDF Export filter
  String _selectedExportFilter = 'Daily';
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    // CRITICAL NAVIGATION FIX: Always clear active ledger search when entering the screen
    // so it consistently opens to the "Recently Accessed Ledgers" list view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final transProv = context.read<TransactionProvider>();
      transProv.clearLedgerSearch();
      transProv.fetchTransactions();
      context.read<InvoiceProvider>().fetchInvoices();
      if (widget.initialCustomerName != null) {
        _searchController.text = widget.initialCustomerName!;
        transProv.fetchLedger(widget.initialCustomerName!);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    // CRITICAL NAVIGATION FIX: Clear active ledger search when leaving the screen
    // so it doesn't get stuck displaying a single customer's data next time.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TransactionProvider>().clearLedgerSearch();
      }
    });
    super.dispose();
  }

  List<LedgerEntry> _getFilteredEntries(List<LedgerEntry> ledger) {
    final now = DateTime.now();
    switch (_selectedExportFilter) {
      case 'Daily':
        return ledger.where((e) =>
            e.date.year == now.year &&
            e.date.month == now.month &&
            e.date.day == now.day).toList();
      case 'Monthly':
        return ledger.where((e) =>
            e.date.year == now.year &&
            e.date.month == now.month).toList();
      case 'Yearly':
        return ledger.where((e) =>
            e.date.year == now.year).toList();
      default:
        return ledger;
    }
  }

  Future<void> _exportLedgerPdf(String customerName, List<LedgerEntry> entries) async {
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No entries found for the selected filter period.")),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      await PrintService.instance.printLedgerReport(
        customerName,
        entries,
        _selectedExportFilter,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$_selectedExportFilter ledger PDF generated!"),
          backgroundColor: AppTheme.accentIndigo,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("PDF generation failed: $e")),
      );
    }
    setState(() => _isExporting = false);
  }

  void _confirmDeleteLedger(BuildContext context, TransactionProvider prov, String customerName) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 8),
              Text("Delete Ledger Log"),
            ],
          ),
          content: Text(
            "Are you sure you want to permanently delete all transaction history, invoices, and ledger logs for $customerName?\n\nThis action cannot be undone.",
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                prov.deleteLedgerForCustomer(customerName);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Ledger for $customerName has been deleted.")),
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

  void _deleteLedgerEntry(BuildContext context, TransactionProvider transProv, LedgerEntry entry) async {
    final invoiceProv = context.read<InvoiceProvider>();
    final activeClient = transProv.activeSearchCustomer;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Delete Entry"),
          content: Text("Are you sure you want to permanently delete this entry: \"${entry.description}\"? This will update the customer's balance."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                
                try {
                  if (entry.id.startsWith('L-QE-')) {
                    final qeId = entry.id.replaceFirst('L-QE-', '');
                    await transProv.deleteQuickEntry(qeId);
                  } else if (entry.invoiceId != null) {
                    await invoiceProv.deleteInvoice(entry.invoiceId!);
                    await transProv.fetchTransactions();
                  }

                  // Reload the current client's ledger view
                  if (activeClient != null) {
                    await transProv.fetchLedger(activeClient);
                  }

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Entry deleted successfully.")),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed to delete entry: $e")),
                  );
                }
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
    final activeClient = transProv.activeSearchCustomer;
    final ledger = transProv.selectedCustomerLedger;
    final recentCustomers = transProv.customers;

    return Scaffold(
      appBar: AppBar(
        title: const Text("A/c. Ledger Statements"),
      ),
      body: Column(
        children: [
          // Search Card
          Container(
            padding: const EdgeInsets.all(20),
            color: AppTheme.accentIndigo.withValues(alpha: 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Statement Ledger Lookup",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.accentIndigo),
                ),
                const SizedBox(height: 10),
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    return recentCustomers.where((String option) {
                      return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (String selection) {
                    _searchController.text = selection;
                    transProv.fetchLedger(selection);
                  },
                  fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: textController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: "Search customer (e.g. Aman Sharma, Riya Patel)...",
                        prefixIcon: const Icon(Icons.person_search_rounded, color: AppTheme.accentIndigo),
                        suffixIcon: textController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                                onPressed: () {
                                  textController.clear();
                                  transProv.clearLedgerSearch();
                                },
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Ledger statements list OR Recently Accessed Ledgers
          Expanded(
            child: activeClient == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                        child: Text(
                          "Recently Accessed Ledgers",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Expanded(
                        child: recentCustomers.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.find_in_page_outlined, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                                    const SizedBox(height: 12),
                                    const Text(
                                      "No ledger records found.\nCreate an invoice or quick entry to begin.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: recentCustomers.length,
                                itemBuilder: (ctx, index) {
                                  final name = recentCustomers[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: InkWell(
                                      onTap: () {
                                        _searchController.text = name;
                                        transProv.fetchLedger(name);
                                      },
                                      onLongPress: () => _confirmDeleteLedger(context, transProv, name),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: AppTheme.accentIndigo.withValues(alpha: 0.08),
                                              child: const Icon(Icons.person_outline_rounded, color: AppTheme.accentIndigo),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  const Text(
                                                    "Long-press to delete ledger",
                                                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      // Client info card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        color: AppTheme.cardBg,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activeClient,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const Text("Account Statement", style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text("Net Balance Due", style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                                Text(
                                  ledger.isNotEmpty ? currencyFormatter.format(ledger.last.runningBalance) : "₹ 0.00",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: ledger.isNotEmpty && ledger.last.runningBalance > 0
                                        ? AppTheme.accentDeepPurple
                                        : AppTheme.accentTeal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // --- PDF EXPORT FILTER BAR ---
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: const BoxDecoration(
                          color: AppTheme.cardBg,
                          border: Border(
                            top: BorderSide(color: AppTheme.accentBorder),
                            bottom: BorderSide(color: AppTheme.accentBorder),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Filter chips
                            Expanded(
                              child: Row(
                                children: [
                                  _buildFilterChip('Daily'),
                                  const SizedBox(width: 8),
                                  _buildFilterChip('Monthly'),
                                  const SizedBox(width: 8),
                                  _buildFilterChip('Yearly'),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Export button
                            GestureDetector(
                              onTap: _isExporting
                                  ? null
                                  : () => _exportLedgerPdf(activeClient, _getFilteredEntries(ledger)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppTheme.accentIndigo, AppTheme.primaryPurple],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accentIndigo.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isExporting)
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
                                      "Export PDF",
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // List of entries
                      Expanded(
                        child: ledger.isEmpty
                            ? const Center(child: Text("No transactions logged for this client."))
                            : ListView.builder(
                                padding: const EdgeInsets.all(20),
                                itemCount: ledger.length,
                                itemBuilder: (ctx, index) {
                                  final entry = ledger[index];
                                  final isDebit = entry.type == LedgerEntryType.debit;

                                  // Fetch associated invoice details to check payment status
                                  final invoiceProv = context.watch<InvoiceProvider>();
                                  final inv = entry.invoiceId != null
                                      ? invoiceProv.invoices.where((i) => i.id == entry.invoiceId).firstOrNull
                                      : null;
                                  final isPaidInvoice = inv != null && inv.isPaid;
                                  final displayAsDebit = isDebit && !isPaidInvoice;

                                  final descriptionText = entry.description;
                                  final isInvoice = entry.invoiceId != null;
                                  final dayStr = DateFormat('dd').format(entry.date);
                                  final monthStr = DateFormat('MMM').format(entry.date).toUpperCase();


                                  // Paid/Unpaid badge (only for invoices)
                                  Widget? paidBadge;
                                  if (isInvoice) {
                                    paidBadge = Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isPaidInvoice
                                            ? AppTheme.accentTeal.withOpacity(0.08)
                                            : Colors.orangeAccent.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isPaidInvoice ? "PAID" : "UNPAID",
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isPaidInvoice ? AppTheme.accentTeal : Colors.orange.shade800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    );
                                  }

                                  final cardContent = Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cardBg,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppTheme.accentBorder),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.015),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Date block
                                              Container(
                                                width: 50,
                                                height: 52,
                                                decoration: BoxDecoration(
                                                  color: AppTheme.accentIndigo.withOpacity(0.05),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: AppTheme.accentIndigo.withOpacity(0.12)),
                                                ),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      dayStr,
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.w900,
                                                        color: AppTheme.accentIndigo,
                                                        height: 1.1,
                                                      ),
                                                    ),
                                                    Text(
                                                      monthStr,
                                                      style: const TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                        color: AppTheme.textSecondary,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              
                                              // Main transaction info
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      descriptionText,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                        color: AppTheme.textPrimary,
                                                      ),
                                                    ),
                                                    if (paidBadge != null) ...[
                                                      const SizedBox(height: 6),
                                                      Row(
                                                        children: [
                                                          paidBadge,
                                                        ],
                                                      ),
                                                    ],
                                                    if (isInvoice) ...[
                                                      const SizedBox(height: 6),
                                                      const Row(
                                                        children: [
                                                          Icon(
                                                            Icons.picture_as_pdf_rounded,
                                                            color: Colors.redAccent,
                                                            size: 14,
                                                          ),
                                                          SizedBox(width: 4),
                                                          Text(
                                                            "Tap card to Print/Share PDF",
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: AppTheme.primaryPurple,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 14),

                                              // Financial information
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    "${displayAsDebit ? '-' : '+'} ${currencyFormatter.format(entry.amount)}",
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 14,
                                                      color: displayAsDebit ? Colors.redAccent : AppTheme.accentTeal,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    "Bal: ${currencyFormatter.format(entry.runningBalance)}",
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppTheme.textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        
                                        // Actions bar divider & buttons
                                        Container(
                                          decoration: BoxDecoration(
                                            color: AppTheme.cardBg.withOpacity(0.5),
                                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                                            border: const Border(
                                              top: BorderSide(color: AppTheme.accentBorder),
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              if (isInvoice) ...[
                                                TextButton.icon(
                                                  onPressed: () {
                                                    if (inv != null) {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) => PdfViewerScreen(
                                                            title: "Invoice ${inv.invoiceNumber}",
                                                            buildPdf: () => PrintService.instance.generateA4InvoicePdf(inv),
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  icon: const Icon(
                                                    Icons.visibility_outlined,
                                                    size: 14,
                                                    color: AppTheme.accentIndigo,
                                                  ),
                                                  label: const Text(
                                                    "Open in App",
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppTheme.accentIndigo,
                                                    ),
                                                  ),
                                                  style: TextButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                TextButton.icon(
                                                  onPressed: () async {
                                                    await invoiceProv.toggleInvoicePaymentStatus(entry.invoiceId!);
                                                    await transProv.fetchTransactions();
                                                    if (transProv.activeSearchCustomer != null) {
                                                      await transProv.fetchLedger(transProv.activeSearchCustomer!);
                                                    }
                                                  },
                                                  icon: Icon(
                                                    isPaidInvoice ? Icons.cancel_outlined : Icons.check_circle_outline_rounded,
                                                    size: 14,
                                                    color: isPaidInvoice ? Colors.grey : AppTheme.accentTeal,
                                                  ),
                                                  label: Text(
                                                    isPaidInvoice ? "Mark Unpaid" : "Mark Paid",
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: isPaidInvoice ? Colors.grey : AppTheme.accentTeal,
                                                    ),
                                                  ),
                                                  style: TextButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                              ],
                                              TextButton.icon(
                                                onPressed: () => _deleteLedgerEntry(context, transProv, entry),
                                                icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 14,
                                                  color: Colors.redAccent,
                                                ),
                                                label: const Text(
                                                  "Delete",
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.redAccent,
                                                  ),
                                                ),
                                                style: TextButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (isInvoice && inv != null) {
                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () async {
                                          try {
                                            await PrintService.instance.printInvoice(inv);
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text("Error opening PDF: $e")),
                                              );
                                            }
                                          }
                                        },
                                        child: cardContent,
                                      ),
                                    );
                                  }

                                  return cardContent;
                                },
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedExportFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedExportFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentIndigo : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.accentIndigo : AppTheme.accentBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
