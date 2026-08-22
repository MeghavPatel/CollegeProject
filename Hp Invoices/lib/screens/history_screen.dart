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
  String _statusFilter = 'all'; // 'all', 'paid', 'unpaid'
  final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ');
  final dateFormatter = DateFormat('dd-MMM-yyyy');

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
          return matchesSearch && (item.type == QuickEntryType.receipt || item.type == QuickEntryType.contra);
        } else if (_statusFilter == 'unpaid') {
          return matchesSearch && (item.type == QuickEntryType.payment);
        }
        return matchesSearch;
      }
      return false;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle & Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(bottom: BorderSide(color: AppTheme.outlineVariant)),
            ),
            child: Column(
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.outlineVariant,
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
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainer,
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

          // Search & Filter Panel
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surfaceContainerLowest,
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
                    prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primaryEmerald),
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

          const Divider(height: 1, color: AppTheme.outlineVariant),

          // Transaction List
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off_rounded, size: 48, color: AppTheme.outlineVariant),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty ? "No matching records found." : "No transactions recorded yet.",
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
                        return _buildInvoiceTile(context, invoiceProv, item);
                      } else if (item is QuickEntry) {
                        return _buildQuickEntryTile(item);
                      }
                      return const SizedBox.shrink();
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _statusFilter == filterKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _statusFilter = filterKey;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryEmerald : AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryEmerald : AppTheme.outlineVariant,
          ),
          boxShadow: isSelected ? AppTheme.softShadow : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceTile(BuildContext context, InvoiceProvider prov, Invoice invoice) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          // Status Icon Container
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: invoice.isPaid
                  ? AppTheme.primaryLight.withValues(alpha: 0.35)
                  : AppTheme.errorContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              invoice.isPaid ? Icons.check_circle_rounded : Icons.schedule_rounded,
              color: invoice.isPaid ? AppTheme.primaryEmerald : AppTheme.errorRed,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.invoiceNumber,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryEmerald,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  invoice.customerName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Amount & Date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                invoice.isPaid
                    ? "+ ${currencyFormatter.format(invoice.grandTotal)}"
                    : "- ${currencyFormatter.format(invoice.grandTotal)}",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: invoice.isPaid ? AppTheme.primaryEmerald : AppTheme.errorRed,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateFormatter.format(invoice.date),
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickEntryTile(QuickEntry entry) {
    final isReceipt = entry.type == QuickEntryType.receipt;
    final isPayment = entry.type == QuickEntryType.payment;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isReceipt
                  ? AppTheme.primaryLight.withValues(alpha: 0.35)
                  : isPayment
                      ? AppTheme.errorContainer
                      : AppTheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isReceipt
                  ? Icons.arrow_downward_rounded
                  : isPayment
                      ? Icons.arrow_upward_rounded
                      : Icons.swap_horiz_rounded,
              color: isReceipt
                  ? AppTheme.primaryEmerald
                  : isPayment
                      ? AppTheme.errorRed
                      : AppTheme.secondarySlate,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "LOG: ${entry.type.name.toUpperCase()} (${entry.mode.name.toUpperCase()})",
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondarySlate,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.partyName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (entry.remarks.isNotEmpty)
                  Text(
                    entry.remarks,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isReceipt
                    ? "+ ${currencyFormatter.format(entry.amount)}"
                    : "- ${currencyFormatter.format(entry.amount)}",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isReceipt ? AppTheme.primaryEmerald : AppTheme.errorRed,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateFormatter.format(entry.date),
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
