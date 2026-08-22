import 'package:flutter/material.dart';
import 'package:hp_bill/models/invoice.dart';
import 'package:hp_bill/providers/invoice_provider.dart';
import 'package:hp_bill/providers/transaction_provider.dart';
import 'package:hp_bill/screens/sales_invoice_screen.dart';
import 'package:hp_bill/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class SalesInvoicesListScreen extends StatefulWidget {
  const SalesInvoicesListScreen({Key? key}) : super(key: key);

  @override
  State<SalesInvoicesListScreen> createState() => _SalesInvoicesListScreenState();
}

class _SalesInvoicesListScreenState extends State<SalesInvoicesListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'paid', 'unpaid'
  final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ');
  final dateFormatter = DateFormat('dd-MMM-yyyy • hh:mm a');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InvoiceProvider>().fetchInvoices();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmDeleteInvoice(BuildContext context, Invoice invoice) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed),
            SizedBox(width: 8),
            Text("Delete Invoice", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "Are you sure you want to delete invoice ${invoice.invoiceNumber} for ${invoice.customerName}?\n\nThis will remove the corresponding ledger entry as well.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<InvoiceProvider>().deleteInvoice(invoice.id);
              if (mounted) {
                await context.read<TransactionProvider>().fetchTransactions();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Invoice ${invoice.invoiceNumber} deleted."),
                    backgroundColor: AppTheme.errorRed,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoiceProv = context.watch<InvoiceProvider>();

    final filteredInvoices = invoiceProv.invoices.where((inv) {
      final matchesSearch = inv.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          inv.invoiceNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (inv.customerPhone != null && inv.customerPhone!.contains(_searchQuery));

      if (_statusFilter == 'paid') {
        return matchesSearch && inv.isPaid;
      } else if (_statusFilter == 'unpaid') {
        return matchesSearch && !inv.isPaid;
      }
      return matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text("Sales Invoices"),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded, color: AppTheme.secondarySlate),
            onSelected: (val) {
              setState(() => _statusFilter = val);
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    if (_statusFilter == 'all') const Icon(Icons.check, size: 18, color: AppTheme.primaryEmerald),
                    const SizedBox(width: 8),
                    const Text("All Invoices"),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'unpaid',
                child: Row(
                  children: [
                    if (_statusFilter == 'unpaid') const Icon(Icons.check, size: 18, color: AppTheme.primaryEmerald),
                    const SizedBox(width: 8),
                    const Text("Unpaid Only"),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'paid',
                child: Row(
                  children: [
                    if (_statusFilter == 'paid') const Icon(Icons.check, size: 18, color: AppTheme.primaryEmerald),
                    const SizedBox(width: 8),
                    const Text("Paid Only"),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: "Search invoice number, customer name...",
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryEmerald),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Active filter pill if not all
          if (_statusFilter != 'all')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusFilter == 'unpaid' ? AppTheme.errorContainer : AppTheme.successContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Filter: ${_statusFilter.toUpperCase()}",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _statusFilter == 'unpaid' ? AppTheme.onErrorContainer : AppTheme.primaryEmerald,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => setState(() => _statusFilter = 'all'),
                          child: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: _statusFilter == 'unpaid' ? AppTheme.onErrorContainer : AppTheme.primaryEmerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Invoices List
          Expanded(
            child: filteredInvoices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 64,
                          color: AppTheme.outlineVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? "No invoices matching '$_searchQuery'"
                              : "No invoices created yet",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredInvoices.length,
                    itemBuilder: (ctx, index) {
                      final invoice = filteredInvoices[index];
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
                            // Top Row: Reference + Status
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  invoice.invoiceNumber,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryEmerald,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: invoice.isPaid ? AppTheme.successContainer : AppTheme.errorContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    invoice.isPaid ? "PAID" : "UNPAID",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: invoice.isPaid ? AppTheme.primaryEmerald : AppTheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Customer Name
                            Text(
                              invoice.customerName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Details (Phone & Date)
                            if (invoice.customerPhone != null && invoice.customerPhone!.isNotEmpty)
                              Text(
                                "Mob: ${invoice.customerPhone}",
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            Text(
                              dateFormatter.format(invoice.date),
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),

                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(height: 1, color: AppTheme.accentBorder),
                            ),

                            // Bottom Row: Grand Total + Actions
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Grand Total",
                                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                    ),
                                    Text(
                                      currencyFormatter.format(invoice.grandTotal),
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.errorRed, size: 20),
                                      tooltip: "Download PDF",
                                      onPressed: () {
                                        invoiceProv.shareInvoice(invoice);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primaryEmerald, size: 20),
                                      tooltip: "WhatsApp",
                                      onPressed: () {
                                        invoiceProv.shareWhatsAppDirect(invoice);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed, size: 20),
                                      tooltip: "Delete",
                                      onPressed: () => _confirmDeleteInvoice(context, invoice),
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryEmerald,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.post_add_rounded),
        label: const Text("Create Invoice", style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () async {
          await invoiceProv.initializeNewInvoice();
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SalesInvoiceScreen()),
          );
        },
      ),
    );
  }
}
