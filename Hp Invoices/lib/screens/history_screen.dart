import 'package:flutter/material.dart';
import 'package:hp_bill/models/invoice.dart';
import 'package:hp_bill/models/quick_entry.dart';
import 'package:hp_bill/providers/invoice_provider.dart';
import 'package:hp_bill/providers/transaction_provider.dart';
import 'package:hp_bill/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// A pop-up modal overlay for viewing transaction history.
/// Opened via showModalBottomSheet from the Dashboard.
class HistoryOverlay extends StatefulWidget {
  const HistoryOverlay({Key? key}) : super(key: key);

  @override
  State<HistoryOverlay> createState() => _HistoryOverlayState();
}

class _HistoryOverlayState extends State<HistoryOverlay> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ');

  @override
  Widget build(BuildContext context) {
    final invoiceProv = context.watch<InvoiceProvider>();
    final transProv = context.watch<TransactionProvider>();

    // Combine invoices and quick entries
    final List<dynamic> allItems = [
      ...invoiceProv.invoices,
      ...transProv.quickEntries
    ];

    // Sort by date descending
    allItems.sort((a, b) {
      final dateA = a is Invoice ? a.date : (a as QuickEntry).date;
      final dateB = b is Invoice ? b.date : (b as QuickEntry).date;
      return dateB.compareTo(dateA);
    });

    // Filter items based on search and status
    final filteredItems = allItems.where((item) {
      if (item is Invoice) {
        final matchesSearch = item.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            item.invoiceNumber.toLowerCase().contains(_searchQuery.toLowerCase());
        
        if (_statusFilter == 'paid') {
          return matchesSearch && item.isPaid;
        } else if (_statusFilter == 'unpaid') {
          return matchesSearch && !item.isPaid;
        }
        return matchesSearch;
      } else if (item is QuickEntry) {
        final matchesSearch = item.partyName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (item.remarks).toLowerCase().contains(_searchQuery.toLowerCase()) ||
            item.type.name.toLowerCase().contains(_searchQuery.toLowerCase());

        if (_statusFilter == 'paid') {
          // Receipts and contras represent money in/transfer, count as paid/settled
          return matchesSearch && (item.type == QuickEntryType.receipt || item.type == QuickEntryType.contra);
        } else if (_statusFilter == 'unpaid') {
          // Payments are money out, can count as unpaid or not shown under paid filter
          return matchesSearch && (item.type == QuickEntryType.payment);
        }
        return matchesSearch;
      }
      return false;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppTheme.lightPurpleBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle & Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(bottom: BorderSide(color: AppTheme.accentBorder)),
            ),
            child: Column(
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.accentBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Transaction History",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentBorder.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Filter panel
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.primaryPurple.withValues(alpha: 0.03),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: "Search customer, bill number, or quick entry...",
                    prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primaryPurple),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildFilterChip('all', 'All Entries'),
                    const SizedBox(width: 8),
                    _buildFilterChip('paid', 'In / Paid'),
                    const SizedBox(width: 8),
                    _buildFilterChip('unpaid', 'Out / Unpaid'),
                  ],
                ),
              ],
            ),
          ),

          // Unified Transaction List
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        const Text(
                          "No transactions recorded.",
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredItems.length,
                    itemBuilder: (ctx, index) {
                      final item = filteredItems[index];

                      if (item is Invoice) {
                        return _buildInvoiceCard(ctx, item, invoiceProv);
                      } else if (item is QuickEntry) {
                        return _buildQuickEntryCard(ctx, item, transProv);
                      }
                      return const SizedBox.shrink();
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(BuildContext context, Invoice inv, InvoiceProvider prov) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showInvoiceDetail(context, inv, prov),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (inv.isPaid ? AppTheme.accentTeal : AppTheme.accentDeepPurple).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      inv.isPaid ? Icons.check_circle_rounded : Icons.schedule_rounded,
                      color: inv.isPaid ? AppTheme.accentTeal : AppTheme.accentDeepPurple,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv.invoiceNumber,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryPurple),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        inv.customerName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${inv.isPaid ? '+' : '-'} ${currencyFormatter.format(inv.grandTotal)}",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: inv.isPaid ? AppTheme.accentTeal : Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd-MMM-yyyy').format(inv.date),
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickEntryCard(BuildContext context, QuickEntry entry, TransactionProvider prov) {
    final isReceipt = entry.type == QuickEntryType.receipt;
    final isContra = entry.type == QuickEntryType.contra;

    Color badgeColor = AppTheme.accentBlue;
    if (isReceipt) badgeColor = AppTheme.accentTeal;
    if (entry.type == QuickEntryType.payment) badgeColor = Colors.redAccent;

    IconData leadIcon = Icons.account_balance_wallet_rounded;
    if (isContra) leadIcon = Icons.swap_horiz_rounded;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showQuickEntryDetail(context, entry, prov),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      leadIcon,
                      color: badgeColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Quick ${entry.type.name.toUpperCase()}",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: badgeColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.partyName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${isReceipt ? '+' : (isContra ? '' : '-')} ${currencyFormatter.format(entry.amount)}",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: isReceipt ? AppTheme.accentTeal : (isContra ? AppTheme.accentBlue : Colors.redAccent),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd-MMM-yyyy').format(entry.date),
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String status, String label) {
    final isSelected = _statusFilter == status;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _statusFilter = status;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryPurple : AppTheme.cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppTheme.primaryPurple : AppTheme.accentBorder),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  void _showInvoiceDetail(BuildContext context, Invoice invoice, InvoiceProvider prov) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(invoice.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryPurple)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (invoice.isPaid ? AppTheme.accentTeal : AppTheme.accentDeepPurple).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  invoice.isPaid ? "PAID" : "UNPAID",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: invoice.isPaid ? AppTheme.accentTeal : AppTheme.accentDeepPurple,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Customer: ${invoice.customerName}", style: const TextStyle(fontWeight: FontWeight.w600)),
                Text("Phone: +91 ${invoice.customerPhone}", style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                Text("Date: ${DateFormat('dd-MMM-yyyy • hh:mm a').format(invoice.date)}", style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const Divider(height: 20),
                const Text("ITEMS:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                ...invoice.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text("${item.name} × ${item.quantity.toStringAsFixed(0)}", style: const TextStyle(fontSize: 13))),
                      Text(currencyFormatter.format(item.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                )),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Grand Total", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(currencyFormatter.format(invoice.grandTotal), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.primaryPurple)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            // Toggle payment status
            IconButton(
              onPressed: () async {
                await prov.toggleInvoicePaymentStatus(invoice.id);
                if (context.mounted) {
                  await context.read<TransactionProvider>().fetchTransactions();
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Payment status updated!"), duration: Duration(seconds: 1)),
                );
              },
              icon: Icon(
                invoice.isPaid ? Icons.money_off_rounded : Icons.attach_money_rounded,
                color: AppTheme.accentTeal,
              ),
              tooltip: invoice.isPaid ? "Mark as Unpaid" : "Mark as Paid",
            ),
            // Print
            IconButton(
              onPressed: () => prov.printInvoice(invoice),
              icon: const Icon(Icons.print_rounded, color: AppTheme.primaryPurple),
              tooltip: "Print A4",
            ),
            // Share
            IconButton(
              onPressed: () => prov.shareInvoice(invoice),
              icon: const Icon(Icons.share_rounded, color: AppTheme.accentBlue),
              tooltip: "Share PDF",
            ),
            // Delete
            IconButton(
              onPressed: () {
                Navigator.pop(ctx);
                _confirmDeleteInvoice(context, prov, invoice);
              },
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              tooltip: "Delete",
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteInvoice(BuildContext context, InvoiceProvider prov, Invoice invoice) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Delete Record"),
          content: Text("Are you sure you want to permanently delete invoice ${invoice.invoiceNumber}? This action is irreversible."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                await prov.deleteInvoice(invoice.id);
                if (context.mounted) {
                  await context.read<TransactionProvider>().fetchTransactions();
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Invoice record deleted.")),
                );
              },
              child: const Text("Delete"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            ),
          ],
        );
      },
    );
  }

  void _showQuickEntryDetail(BuildContext context, QuickEntry entry, TransactionProvider prov) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isReceipt = entry.type == QuickEntryType.receipt;

        Color badgeColor = AppTheme.accentBlue;
        if (isReceipt) badgeColor = AppTheme.accentTeal;
        if (entry.type == QuickEntryType.payment) badgeColor = Colors.redAccent;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Quick ${entry.type.name.toUpperCase()}",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: badgeColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  entry.mode.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Party / Account: ${entry.partyName}", style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text("Date: ${DateFormat('dd-MMM-yyyy • hh:mm a').format(entry.date)}", style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                if (entry.remarks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text("REMARKS / REFERENCE:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Text(entry.remarks, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                ],
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Amount", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(
                      currencyFormatter.format(entry.amount),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Close"),
            ),
            IconButton(
              onPressed: () {
                Navigator.pop(ctx);
                _confirmDeleteQuickEntry(context, prov, entry);
              },
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              tooltip: "Delete Entry",
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteQuickEntry(BuildContext context, TransactionProvider prov, QuickEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Delete Quick Entry"),
          content: Text("Are you sure you want to permanently delete this quick ${entry.type.name.toUpperCase()} entry of ${currencyFormatter.format(entry.amount)}? This action is irreversible."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                prov.deleteQuickEntry(entry.id);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Quick entry deleted.")),
                );
              },
              child: const Text("Delete"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            ),
          ],
        );
      },
    );
  }
}
