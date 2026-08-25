import 'package:flutter/material.dart';
import 'package:hp_bill/models/invoice.dart';
import 'package:hp_bill/providers/invoice_provider.dart';
import 'package:hp_bill/providers/transaction_provider.dart';
import 'package:hp_bill/screens/pdf_viewer_screen.dart';
import 'package:hp_bill/screens/sales_invoice_screen.dart';
import 'package:hp_bill/services/master_password_service.dart';
import 'package:hp_bill/services/print_service.dart';
import 'package:hp_bill/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class SalesInvoiceListScreen extends StatefulWidget {
  const SalesInvoiceListScreen({super.key});

  @override
  State<SalesInvoiceListScreen> createState() => _SalesInvoiceListScreenState();
}

class _SalesInvoiceListScreenState extends State<SalesInvoiceListScreen> {
  final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ');
  final dateFormatter = DateFormat('dd-MMM-yyyy • hh:mm a');
  final _searchController = TextEditingController();
  String _searchQuery = '';

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

  void _confirmDeleteInvoice(BuildContext context, InvoiceProvider prov, Invoice invoice) async {
    final allowed = await MasterPasswordService.confirmMasterPassword(
      context,
      title: "Master Password Required",
      message: "Enter master password to delete invoice ${invoice.invoiceNumber}.",
    );
    if (!allowed) return;

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 8),
              Text("Delete Invoice"),
            ],
          ),
          content: Text(
            "Are you sure you want to permanently delete invoice ${invoice.invoiceNumber} for ${invoice.customerName}?\n\nThis will also update the customer's ledger.",
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await prov.deleteInvoice(invoice.id);
                  if (context.mounted) {
                    await context.read<TransactionProvider>().fetchTransactions();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Invoice ${invoice.invoiceNumber} deleted successfully.")),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Failed to delete invoice: $e")),
                    );
                  }
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

  void _editInvoice(BuildContext context, InvoiceProvider prov, Invoice invoice) async {
    final allowed = await MasterPasswordService.confirmMasterPassword(
      context,
      title: "Master Password Required",
      message: "Enter master password to edit invoice ${invoice.invoiceNumber}.",
    );
    if (!allowed) return;

    if (!context.mounted) return;
    prov.loadInvoiceForEditing(invoice);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SalesInvoiceScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoiceProv = context.watch<InvoiceProvider>();
    final invoices = invoiceProv.invoices;

    final filteredInvoices = invoices.where((inv) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return inv.invoiceNumber.toLowerCase().contains(q) ||
          inv.customerName.toLowerCase().contains(q) ||
          inv.customerPhone.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sales Invoices"),
      ),
      body: Column(
        children: [
          // Search Panel
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.accentTeal.withValues(alpha: 0.04),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: "Search invoice number, customer name, phone...",
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.accentTeal),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Invoice List
          Expanded(
            child: invoiceProv.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredInvoices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isEmpty ? "No sales invoices found." : "No matching invoices found.",
                              style: const TextStyle(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredInvoices.length,
                        itemBuilder: (ctx, index) {
                          final inv = filteredInvoices[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top row: Invoice # & Paid status
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        inv.invoiceNumber,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppTheme.primaryPurple,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: inv.isPaid
                                              ? AppTheme.accentTeal.withValues(alpha: 0.08)
                                              : Colors.orangeAccent.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          inv.isPaid ? "PAID" : "UNPAID",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: inv.isPaid ? AppTheme.accentTeal : Colors.orange.shade800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Customer Info
                                  Text(
                                    inv.customerName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  if (inv.customerPhone.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      "Mob: ${inv.customerPhone}",
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    dateFormatter.format(inv.date),
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  ),

                                  if (inv.notes != null && inv.notes!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      "Notes: ${inv.notes!.trim()}",
                                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
                                    ),
                                  ],

                                  const Divider(height: 20),

                                  // Bottom row: Grand Total & Action Buttons
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Grand Total",
                                            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                          ),
                                          Text(
                                            currencyFormatter.format(inv.grandTotal),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          // PDF View Button
                                          IconButton(
                                            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 20),
                                            tooltip: "PDF View",
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => PdfViewerScreen(
                                                    title: "Invoice ${inv.invoiceNumber}",
                                                    buildPdf: () => PrintService.instance.generateA4InvoicePdf(inv),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          // Edit Button
                                          IconButton(
                                            icon: const Icon(Icons.edit_rounded, color: AppTheme.accentIndigo, size: 20),
                                            tooltip: "Edit Invoice",
                                            onPressed: () => _editInvoice(context, invoiceProv, inv),
                                          ),
                                          // Delete Button
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                            tooltip: "Delete Invoice",
                                            onPressed: () => _confirmDeleteInvoice(context, invoiceProv, inv),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
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
