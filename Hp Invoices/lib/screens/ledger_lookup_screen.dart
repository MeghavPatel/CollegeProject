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
    // Always clear active ledger search when entering the screen
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
          backgroundColor: AppTheme.primaryEmerald,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed),
              SizedBox(width: 8),
              Text("Delete Ledger Log", style: TextStyle(fontWeight: FontWeight.w700)),
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
                  SnackBar(
                    content: Text("Ledger for $customerName has been deleted."),
                    backgroundColor: AppTheme.errorRed,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text("Delete Entry", style: TextStyle(fontWeight: FontWeight.w700)),
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
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
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
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text("A/c. Ledger Statements"),
      ),
      body: Column(
        children: [
          // Search Card
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surfaceContainerLowest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "STATEMENT LEDGER LOOKUP",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
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
                        prefixIcon: const Icon(Icons.person_search_rounded, color: AppTheme.primaryEmerald),
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
          const Divider(height: 1, color: AppTheme.outlineVariant),

          // Ledger statements list OR Recently Accessed Ledgers
          Expanded(
            child: activeClient == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 10),
                        child: Text(
                          "Recently Accessed Ledgers",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: recentCustomers.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.find_in_page_outlined, size: 54, color: AppTheme.outlineVariant),
                                    const SizedBox(height: 12),
                                    const Text(
                                      "No ledger records found.\nCreate an invoice or quick entry to begin.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: recentCustomers.length,
                                itemBuilder: (ctx, index) {
                                  final name = recentCustomers[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceContainerLowest,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: AppTheme.outlineVariant),
                                      boxShadow: AppTheme.softShadow,
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        _searchController.text = name;
                                        transProv.fetchLedger(name);
                                      },
                                      onLongPress: () => _confirmDeleteLedger(context, transProv, name),
                                      borderRadius: BorderRadius.circular(14),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14.0),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 42,
                                              height: 42,
                                              decoration: BoxDecoration(
                                                color: AppTheme.secondaryContainer,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.person_rounded, color: AppTheme.primaryEmerald, size: 22),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  const Text(
                                                    "Tap to view statement • Long-press to delete",
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
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        color: AppTheme.surfaceContainerLowest,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activeClient,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: AppTheme.textPrimary),
                                ),
                                const Text("Account Statement", style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text("Net Balance Due", style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                                Text(
                                  ledger.isNotEmpty ? currencyFormatter.format(ledger.last.runningBalance) : "₹ 0.00",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    color: ledger.isNotEmpty && ledger.last.runningBalance > 0
                                        ? AppTheme.errorRed
                                        : AppTheme.primaryEmerald,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // --- PDF EXPORT FILTER BAR ---
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: const BoxDecoration(
                          color: AppTheme.surfaceContainerLow,
                          border: Border(
                            top: BorderSide(color: AppTheme.outlineVariant),
                            bottom: BorderSide(color: AppTheme.outlineVariant),
                          ),
                        ),
                        child: Row(
                          children: [
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
                            const SizedBox(width: 10),
                            // Export button
                            GestureDetector(
                              onTap: _isExporting
                                  ? null
                                  : () => _exportLedgerPdf(activeClient, _getFilteredEntries(ledger)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryEmerald,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: AppTheme.softShadow,
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
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
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
                                padding: const EdgeInsets.all(16),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isPaidInvoice
                                            ? AppTheme.successContainer
                                            : AppTheme.errorContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isPaidInvoice ? "PAID" : "UNPAID",
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isPaidInvoice ? AppTheme.primaryEmerald : AppTheme.onErrorContainer,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    );
                                  }

                                  final cardContent = Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceContainerLowest,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: AppTheme.outlineVariant),
                                      boxShadow: AppTheme.softShadow,
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
                                                width: 46,
                                                height: 48,
                                                decoration: BoxDecoration(
                                                  color: AppTheme.secondaryContainer,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      dayStr,
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w900,
                                                        color: AppTheme.textPrimary,
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
                                              const SizedBox(width: 12),
                                              
                                              // Main transaction info
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      descriptionText,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 13,
                                                        color: AppTheme.textPrimary,
                                                      ),
                                                    ),
                                                    if (paidBadge != null) ...[
                                                      const SizedBox(height: 4),
                                                      paidBadge,
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12),

                                              // Financial information
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    "${displayAsDebit ? '-' : '+'} ${currencyFormatter.format(entry.amount)}",
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 14,
                                                      color: displayAsDebit ? AppTheme.errorRed : AppTheme.primaryEmerald,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    "Bal: ${currencyFormatter.format(entry.runningBalance)}",
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppTheme.textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        
                                        // Actions bar
                                        Container(
                                          decoration: const BoxDecoration(
                                            color: AppTheme.surfaceContainerLow,
                                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
                                            border: Border(
                                              top: BorderSide(color: AppTheme.accentBorder),
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                                                    color: AppTheme.primaryEmerald,
                                                  ),
                                                  label: const Text(
                                                    "Open PDF",
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppTheme.primaryEmerald,
                                                    ),
                                                  ),
                                                  style: TextButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
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
                                                    color: isPaidInvoice ? AppTheme.textSecondary : AppTheme.primaryEmerald,
                                                  ),
                                                  label: Text(
                                                    isPaidInvoice ? "Mark Unpaid" : "Mark Paid",
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: isPaidInvoice ? AppTheme.textSecondary : AppTheme.primaryEmerald,
                                                    ),
                                                  ),
                                                  style: TextButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              TextButton.icon(
                                                onPressed: () => _deleteLedgerEntry(context, transProv, entry),
                                                icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 14,
                                                  color: AppTheme.errorRed,
                                                ),
                                                label: const Text(
                                                  "Delete",
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.errorRed,
                                                  ),
                                                ),
                                                style: TextButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                                        borderRadius: BorderRadius.circular(14),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryEmerald : AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryEmerald : AppTheme.outlineVariant,
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
