import 'package:flutter/material.dart';
import 'package:hp_bill/models/inventory_item.dart';
import 'package:hp_bill/models/invoice.dart';
import 'package:hp_bill/models/ledger_entry.dart';
import 'package:hp_bill/providers/invoice_provider.dart';
import 'package:hp_bill/providers/transaction_provider.dart';
import 'package:hp_bill/providers/sync_provider.dart';
import 'package:hp_bill/screens/ledger_lookup_screen.dart';
import 'package:hp_bill/services/share_service.dart';
import 'package:hp_bill/services/database_helper.dart';
import 'package:hp_bill/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class SalesInvoiceScreen extends StatefulWidget {
  const SalesInvoiceScreen({Key? key}) : super(key: key);

  @override
  State<SalesInvoiceScreen> createState() => _SalesInvoiceScreenState();
}

class _SalesInvoiceScreenState extends State<SalesInvoiceScreen> {
  int _currentStep = 0;
  
  // Customer details controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  final _openingAmountController = TextEditingController();
  bool _isStartingAccount = false;
  LedgerEntryType _openingAccountType = LedgerEntryType.debit;

  // Custom Item dialog controllers
  final _customItemNameController = TextEditingController();
  final _customItemQtyController = TextEditingController();
  final _customItemRateController = TextEditingController();

  // Temporary dialog input controllers
  final _qtyController = TextEditingController();
  final _rateController = TextEditingController();

  final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ');

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final provider = context.read<TransactionProvider>();
    final matchedCustomer = provider.customers.firstWhere(
      (c) => c.toLowerCase().trim() == name.toLowerCase(),
      orElse: () => '',
    );

    if (matchedCustomer.isNotEmpty) {
      final phone = await DatabaseHelper.instance.getCustomerPhone(matchedCustomer);
      if (!mounted) return;
      if (phone != null && phone.isNotEmpty) {
        if (_phoneController.text != phone) {
          _phoneController.text = phone;
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _openingAmountController.dispose();
    _customItemNameController.dispose();
    _customItemQtyController.dispose();
    _customItemRateController.dispose();
    _qtyController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  void _startOpeningAccount(BuildContext context) async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final openingAmtText = _openingAmountController.text.trim();

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (name.isEmpty) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text("Please enter a customer name.")),
      );
      return;
    }

    final transProv = context.read<TransactionProvider>();
    final exists = transProv.customers.any(
      (c) => c.toLowerCase().trim() == name.toLowerCase().trim(),
    );
    if (exists) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("An account for '$name' already exists.")),
      );
      return;
    }

    final openingAmount = double.tryParse(openingAmtText) ?? 0.0;

    setState(() => _isStartingAccount = true);
    try {
      await transProv.startOpeningAccount(
        name: name,
        phone: phone,
        openingAmount: openingAmount,
        type: _openingAccountType,
      );

      if (!mounted) return;

      context.read<InvoiceProvider>().setCustomerInfo(name, phone);

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text("Account started for '$name' with ₹${openingAmount.toStringAsFixed(2)}!"),
          backgroundColor: AppTheme.primaryEmerald,
          action: SnackBarAction(
            label: "View Ledger",
            textColor: Colors.white,
            onPressed: () {
              navigator.push(
                MaterialPageRoute(
                  builder: (_) => LedgerLookupScreen(initialCustomerName: name),
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("Failed to start account: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _isStartingAccount = false);
      }
    }
  }

  void _finalizeInvoice(BuildContext context) async {
    final invoiceProv = context.read<InvoiceProvider>();
    invoiceProv.setCustomerDetails(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: null,
      transport: null,
      lrNo: null,
      siteName: null,
    );

    try {
      final savedInvoice = await invoiceProv.saveActiveInvoice();

      if (!mounted) return;

      // Refresh the ledger/transaction lists
      await context.read<TransactionProvider>().fetchTransactions();

      if (context.read<SyncProvider>().isOnline == false) {
        context.read<SyncProvider>().incrementPendingQueue();
      }

      _showSuccessDialog(context, savedInvoice);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving invoice: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoiceProv = context.watch<InvoiceProvider>();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text("Create Invoice"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / 3,
            backgroundColor: AppTheme.surfaceContainerHighest,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryEmerald),
          ),
        ),
      ),
      body: Column(
        children: [
          // Sub-bar with Invoice Reference & Mode
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: AppTheme.surfaceContainerLow,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryEmerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "STANDARD",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: AppTheme.primaryEmerald,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      invoiceProv.storeName.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                Text(
                  invoiceProv.activeInvoiceNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppTheme.primaryEmerald,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),

          // Steps view
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildCurrentStepView(invoiceProv),
            ),
          ),

          // Bottom navigation bar
          _buildBottomNavigationBar(invoiceProv),
        ],
      ),
    );
  }

  Widget _buildCurrentStepView(InvoiceProvider prov) {
    switch (_currentStep) {
      case 0:
        return _buildStep1Customer(prov);
      case 1:
        return _buildStep2Items(prov);
      case 2:
        return _buildStep3Summary(prov);
      default:
        return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  STEP 1: CUSTOMER INFORMATION
  // ═══════════════════════════════════════════════════════════════
  Widget _buildStep1Customer(InvoiceProvider prov) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Customer Information",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "Enter customer details to begin billing.",
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 20),

        // Customer Name Autocomplete
        LayoutBuilder(
          builder: (context, constraints) {
            return Autocomplete<String>(
              textEditingController: _nameController,
              optionsBuilder: (TextEditingValue textEditingValue) {
                final customers = context.read<TransactionProvider>().customers;
                if (textEditingValue.text.isEmpty) {
                  return customers;
                }
                return customers.where((String option) {
                  return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (String selection) async {
                final phone = await DatabaseHelper.instance.getCustomerPhone(selection);
                if (phone != null && phone.isNotEmpty) {
                  _phoneController.text = phone;
                }
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 6.0,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      width: constraints.biggest.width,
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.outlineVariant),
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final String option = options.elementAt(index);
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.person_rounded, color: AppTheme.primaryEmerald, size: 20),
                            title: Text(
                              option,
                              style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                            ),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: "Customer Name",
                    hintText: "Enter or select customer",
                    prefixIcon: Icon(Icons.person_rounded, color: AppTheme.secondarySlate),
                  ),
                );
              },
            );
          },
        ),

        const SizedBox(height: 14),

        // Phone input
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: "Mobile Number",
            hintText: "Enter 10-digit mobile number",
            prefixIcon: Icon(Icons.smartphone_rounded, color: AppTheme.secondarySlate),
          ),
        ),

        const SizedBox(height: 28),

        // Optional Opening Account Card (Glassmorphic / Clean Stitch UI Style)
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.outlineVariant),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subtle emerald top bar
              Container(
                height: 4,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryEmerald,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.account_balance_rounded,
                            color: AppTheme.primaryEmerald,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Start Opening Account",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                "Optional initial balance for this customer",
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _openingAmountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Opening Balance (₹)",
                        hintText: "0.00",
                        prefixIcon: Icon(Icons.account_balance_wallet_rounded, color: AppTheme.secondarySlate),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text("Debit (Receivable)")),
                            selected: _openingAccountType == LedgerEntryType.debit,
                            selectedColor: AppTheme.primaryEmerald.withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: _openingAccountType == LedgerEntryType.debit
                                  ? AppTheme.primaryEmerald
                                  : AppTheme.textSecondary,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _openingAccountType = LedgerEntryType.debit);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text("Credit (Payable)")),
                            selected: _openingAccountType == LedgerEntryType.credit,
                            selectedColor: AppTheme.errorContainer,
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: _openingAccountType == LedgerEntryType.credit
                                  ? AppTheme.onErrorContainer
                                  : AppTheme.textSecondary,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _openingAccountType = LedgerEntryType.credit);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isStartingAccount ? null : () => _startOpeningAccount(context),
                        icon: _isStartingAccount
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.person_add_alt_1_rounded, size: 18),
                        label: const Text(
                          "Start Account & Save",
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  STEP 2: QUICK-TAP INVENTORY & LIVE BILL FEED
  // ═══════════════════════════════════════════════════════════════
  Widget _buildStep2Items(InvoiceProvider prov) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Tap Inventory Item to Add",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          "Tap any product below to set quantity and rate. Item locks into the bill instantly.",
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),

        // Quick-Tap Suggestion Chips + Custom Item Button
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...prov.inventory.map((item) {
              return ActionChip(
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                label: Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryEmerald,
                  ),
                ),
                backgroundColor: AppTheme.surfaceContainerLowest,
                side: const BorderSide(color: AppTheme.primaryEmerald, width: 1.2),
                onPressed: () => _promptItemParameters(prov, item),
              );
            }).toList(),

            // Custom Item Chip (Dashed style)
            ActionChip(
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              avatar: const Icon(Icons.add_rounded, size: 18, color: AppTheme.secondarySlate),
              label: const Text(
                "Custom Item",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.secondarySlate,
                ),
              ),
              backgroundColor: AppTheme.surfaceContainerLow,
              side: const BorderSide(color: AppTheme.outlineVariant, width: 1.2),
              onPressed: () => _promptCustomItem(prov),
            ),
          ],
        ),

        const SizedBox(height: 28),

        // Live Bill Feed
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Live Bill Feed",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            if (prov.activeItems.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryEmerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${prov.activeItems.length} items",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryEmerald,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (prov.activeItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: 48,
                  color: AppTheme.outlineVariant,
                ),
                const SizedBox(height: 10),
                const Text(
                  "No items added to this bill yet.",
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Tap an item from the list above to begin.",
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: prov.activeItems.length,
            itemBuilder: (ctx, index) {
              final item = prov.activeItems[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${item.quantity.toStringAsFixed(0)} Qty  ×  ${currencyFormatter.format(item.rate)}",
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      currencyFormatter.format(item.total),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded, color: AppTheme.errorRed, size: 20),
                      onPressed: () => prov.removeInvoiceItem(item.id),
                    ),
                  ],
                ),
              );
            },
          ),

        const SizedBox(height: 16),
        
        // Live Calculation block (NO TAX)
        if (prov.activeItems.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.outlineVariant),
              boxShadow: AppTheme.softShadow,
            ),
            child: Column(
              children: [
                _buildTotalRow("Subtotal", currencyFormatter.format(prov.activeSubtotal), false),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: AppTheme.accentBorder),
                ),
                _buildTotalRow("Grand Total", currencyFormatter.format(prov.activeGrandTotal), true),
              ],
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  STEP 3: SETTLEMENT & SHARING
  // ═══════════════════════════════════════════════════════════════
  Widget _buildStep3Summary(InvoiceProvider prov) {
    final tempInvoice = Invoice(
      id: 'temp',
      invoiceNumber: prov.activeInvoiceNumber,
      customerName: _nameController.text.trim(),
      customerPhone: _phoneController.text.trim(),
      date: DateTime.now(),
      items: prov.activeItems,
      isPaid: prov.isPaid,
      customerAddress: null,
      transport: null,
      lrNo: null,
      siteName: null,
    );

    return FutureBuilder<String>(
      future: ShareService.instance.compileBillSummaryText(tempInvoice),
      builder: (context, snapshot) {
        final summaryText = snapshot.data ?? 'Compiling bill...';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Settlement & Sharing",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 16),

            // Text copy and WhatsApp routing panel
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.outlineVariant),
                boxShadow: AppTheme.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top bar in card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      border: Border(bottom: BorderSide(color: AppTheme.outlineVariant)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "BILL TEXT SUMMARY",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.5),
                        ),
                        GestureDetector(
                          onTap: () {
                            ShareService.instance.copyToClipboard(summaryText);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Bill summary copied to clipboard!")),
                            );
                          },
                          child: Row(
                            children: const [
                              Icon(Icons.content_copy_rounded, size: 14, color: AppTheme.primaryEmerald),
                              SizedBox(width: 4),
                              Text(
                                "One-Click Copy",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryEmerald,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.outlineVariant),
                          ),
                          child: Text(
                            summaryText,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: AppTheme.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // WhatsApp Direct Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ShareService.instance.launchWhatsAppDirect(tempInvoice);
                            },
                            icon: const Icon(Icons.chat_bubble_outline_rounded),
                            label: const Text("Send via WhatsApp Direct"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryEmerald,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  DIALOGS & ACTIONS
  // ═══════════════════════════════════════════════════════════════

  void _promptItemParameters(InvoiceProvider prov, InventoryItem item) {
    _qtyController.text = "1";
    _rateController.text = item.defaultRate != null ? item.defaultRate!.toStringAsFixed(0) : "";

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text("Add ${item.name}", style: const TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: "Quantity"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _rateController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Rate (₹)"),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final qty = double.tryParse(_qtyController.text) ?? 1.0;
                final rate = double.tryParse(_rateController.text) ?? item.defaultRate ?? 0.0;
                prov.addInvoiceItem(item.name, qty, rate);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryEmerald),
              child: const Text("Add to Bill"),
            ),
          ],
        );
      },
    );
  }

  void _promptCustomItem(InvoiceProvider prov) {
    _customItemNameController.clear();
    _customItemQtyController.text = "1";
    _customItemRateController.clear();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text("Add Custom Product", style: TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _customItemNameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: "Product Name"),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customItemQtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Quantity"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _customItemRateController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Rate (₹)"),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final name = _customItemNameController.text.trim();
                if (name.isEmpty) return;
                final qty = double.tryParse(_customItemQtyController.text) ?? 1.0;
                final rate = double.tryParse(_customItemRateController.text) ?? 0.0;
                prov.addInvoiceItem(name, qty, rate);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryEmerald),
              child: const Text("Add to Bill"),
            ),
          ],
        );
      },
    );
  }

  // Navigation bar
  Widget _buildBottomNavigationBar(InvoiceProvider prov) {
    final isFirstStep = _currentStep == 0;
    final isLastStep = _currentStep == 2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppTheme.outlineVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!isFirstStep)
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _currentStep--;
                });
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Back"),
            )
          else
            const SizedBox.shrink(),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: isFirstStep ? 0 : 14.0),
              child: ElevatedButton(
                onPressed: () {
                  if (isFirstStep) {
                    if (_nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please enter a customer name.")),
                      );
                      return;
                    }
                    prov.setCustomerDetails(
                      name: _nameController.text.trim(),
                      phone: _phoneController.text.trim(),
                      address: null,
                      transport: null,
                      lrNo: null,
                      siteName: null,
                    );
                    setState(() {
                      _currentStep++;
                    });
                  } else if (_currentStep == 1) {
                    if (prov.activeItems.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please add at least one item to continue.")),
                      );
                      return;
                    }
                    setState(() {
                      _currentStep++;
                    });
                  } else {
                    _finalizeInvoice(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryEmerald,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(isLastStep ? "Generate Invoice" : "Continue"),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, bool isBold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            fontSize: isBold ? 16 : 14,
            color: isBold ? AppTheme.primaryEmerald : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  // Success modal matching invoice_success_modal/code.html
  void _showSuccessDialog(BuildContext context, Invoice invoice) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
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
              const SizedBox(height: 20),

              // Success Icon
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primaryEmerald.withValues(alpha: 0.2)),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.primaryEmerald,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                "Invoice Saved Successfully!",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Bill reference ${invoice.invoiceNumber} is saved.",
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // 3 Action Buttons Grid matching Stitch UI
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionCircle(
                    icon: Icons.print_rounded,
                    label: "Print A4",
                    onTap: () {
                      context.read<InvoiceProvider>().printInvoice(invoice);
                    },
                  ),
                  _buildActionCircle(
                    icon: Icons.picture_as_pdf_rounded,
                    label: "Share PDF Direct",
                    onTap: () {
                      context.read<InvoiceProvider>().shareInvoice(invoice);
                    },
                  ),
                  _buildActionCircle(
                    icon: Icons.chat_rounded,
                    label: "WhatsApp Text",
                    onTap: () {
                      context.read<InvoiceProvider>().shareWhatsAppDirect(invoice);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Primary Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.dashboard_rounded, size: 18),
                  label: const Text("Done & Back to Dashboard"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryEmerald,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionCircle({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppTheme.secondaryContainer,
              shape: BoxShape.circle,
              boxShadow: AppTheme.softShadow,
            ),
            child: Icon(icon, color: AppTheme.onSecondaryContainer, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
