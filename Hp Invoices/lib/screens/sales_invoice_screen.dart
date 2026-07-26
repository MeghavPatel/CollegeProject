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
          backgroundColor: AppTheme.accentTeal,
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
      appBar: AppBar(
        title: const Text("Create Bill"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / 3,
            backgroundColor: AppTheme.accentBorder,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
          ),
        ),
      ),
      body: Column(
        children: [
          // Header: Store Profile branding
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: AppTheme.primaryPurple.withOpacity(0.06),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  invoiceProv.storeName.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryPurple),
                ),
                Text(
                  "Bill Reference: ${invoiceProv.activeInvoiceNumber}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),

          // Forms
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

  // --- STEP 1: CUSTOMER DETAILS ---
  Widget _buildStep1Customer(InvoiceProvider prov) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        const Text(
          "Customer Information",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 20),
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
                    elevation: 4.0,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      width: constraints.biggest.width,
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.accentBorder),
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final String option = options.elementAt(index);
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.person_outline_rounded, color: AppTheme.primaryPurple, size: 20),
                            title: Text(
                              option,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
              fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: textController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: "Customer Name",
                    hintText: "Enter customer full name",
                    prefixIcon: Icon(Icons.person_outline_rounded, color: AppTheme.primaryPurple),
                  ),
                  textCapitalization: TextCapitalization.words,
                  onTap: () {
                    textController.text = textController.text;
                  },
                );
              },
            );
          },
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: "Mobile Number",
            hintText: "Enter 10-digit phone number",
            prefixIcon: Icon(Icons.phone_android_rounded, color: AppTheme.primaryPurple),
          ),
        ),
        const SizedBox(height: 24),
        
        // Opening Account settings Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.accentBorder),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.account_balance_rounded, size: 20, color: AppTheme.primaryPurple),
                  SizedBox(width: 8),
                  Text(
                    "Start Opening Account (Optional)",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                "Directly start this customer's account in ledger with an opening balance.",
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              const Divider(height: 24),
              TextField(
                controller: _openingAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: "Opening Outstanding (₹)",
                  hintText: "Enter opening outstanding balance",
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primaryPurple),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _openingAccountType = LedgerEntryType.debit;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _openingAccountType == LedgerEntryType.debit
                              ? AppTheme.primaryPurple.withOpacity(0.1)
                              : AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _openingAccountType == LedgerEntryType.debit
                                ? AppTheme.primaryPurple
                                : AppTheme.accentBorder,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.arrow_downward_rounded,
                              size: 16,
                              color: _openingAccountType == LedgerEntryType.debit
                                  ? AppTheme.primaryPurple
                                  : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Missed Payment",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _openingAccountType == LedgerEntryType.debit
                                    ? AppTheme.primaryPurple
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _openingAccountType = LedgerEntryType.credit;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _openingAccountType == LedgerEntryType.credit
                              ? AppTheme.primaryPurple.withOpacity(0.1)
                              : AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _openingAccountType == LedgerEntryType.credit
                                ? AppTheme.primaryPurple
                                : AppTheme.accentBorder,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.arrow_upward_rounded,
                              size: 16,
                              color: _openingAccountType == LedgerEntryType.credit
                                  ? AppTheme.primaryPurple
                                  : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Received",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _openingAccountType == LedgerEntryType.credit
                                    ? AppTheme.primaryPurple
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isStartingAccount ? null : () => _startOpeningAccount(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentTeal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isStartingAccount
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text(
                    "Start Account & Save",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- STEP 2: QUICK-TAP BILLING (NO TAX) ---
  Widget _buildStep2Items(InvoiceProvider prov) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Tap Inventory Item to Add",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 6),
        const Text(
          "Tap any product below to set quantity and rate. Item locks into the bill instantly.",
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),

        // Quick-Tap Suggestion Chips
        if (prov.inventory.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                "No products saved in Inventory.\nPlease configure inventory in Admin panel first.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: prov.inventory.map((item) {
              return ActionChip(
                elevation: 1,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                label: Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                ),
                backgroundColor: AppTheme.cardBg,
                side: const BorderSide(color: AppTheme.primaryPurple, width: 1.2),
                onPressed: () => _promptItemParameters(prov, item),
              );
            }).toList(),
          ),

        const SizedBox(height: 28),

        // Live Bill Feed
        const Text(
          "Live Bill Feed",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 10),

        if (prov.activeItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined, size: 40, color: AppTheme.textSecondary.withOpacity(0.3)),
                const SizedBox(height: 8),
                const Text(
                  "No items added to this bill yet.",
                  style: TextStyle(color: AppTheme.textSecondary),
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
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text("${item.quantity.toStringAsFixed(0)} Qty  ×  ${currencyFormatter.format(item.rate)}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(currencyFormatter.format(item.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 20),
                        onPressed: () => prov.removeInvoiceItem(item.id),
                      ),
                    ],
                  ),
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
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.accentBorder),
            ),
            child: Column(
              children: [
                _buildTotalRow("Subtotal", currencyFormatter.format(prov.activeSubtotal), false),
                const Divider(height: 20),
                _buildTotalRow("Grand Total", currencyFormatter.format(prov.activeGrandTotal), true),
              ],
            ),
          ),
      ],
    );
  }

  // --- STEP 3: SETTLEMENT & WHATSAPP (NO TAX) ---
  Widget _buildStep3Summary(InvoiceProvider prov) {
    final tempInvoice = Invoice(
      id: 'temp',
      invoiceNumber: prov.activeInvoiceNumber,
      customerName: _nameController.text,
      customerPhone: _phoneController.text,
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 16),

            // Text copy and WhatsApp routing panel
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.accentBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "BILL TEXT SUMMARY",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          ShareService.instance.copyToClipboard(summaryText);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Bill summary copied to clipboard!")),
                          );
                        },
                        icon: const Icon(Icons.copy_all_rounded, size: 14),
                        label: const Text("One-Click Copy", style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.lightPurpleBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      summaryText,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppTheme.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // WhatsApp Direct
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ShareService.instance.launchWhatsAppDirect(tempInvoice);
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: const Text("Send via WhatsApp Direct"),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentTeal),
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

  // --- PARAMETER INPUT DIALOG (ONLY QTY + RATE, NO TAX) ---
  void _promptItemParameters(InvoiceProvider prov, InventoryItem item) {
    _qtyController.text = "1";
    _rateController.text = item.defaultRate != null ? item.defaultRate!.toStringAsFixed(0) : "";

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Add ${item.name}", style: const TextStyle(fontWeight: FontWeight.bold)),
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
              child: const Text("Add to Bill"),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentTeal),
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
        color: AppTheme.cardBg,
        border: Border(top: BorderSide(color: AppTheme.accentBorder)),
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
              child: const Text("Back"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )
          else
            const SizedBox.shrink(),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: isFirstStep ? 0 : 16.0),
              child: ElevatedButton(
                onPressed: () {
                  if (isFirstStep) {
                    if (_nameController.text.isEmpty) {
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
                        const SnackBar(content: Text("Please add at least one item.")),
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
            color: isBold ? AppTheme.primaryPurple : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  // Success sheet
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Color(0xFFD1FAE5),
                child: Icon(Icons.check_circle_rounded, color: AppTheme.accentTeal, size: 38),
              ),
              const SizedBox(height: 16),
              const Text(
                "Invoice Generated Successfully!",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              Text(
                "Bill reference ${invoice.invoiceNumber} has been locked and saved.",
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionCircle(
                    icon: Icons.print_rounded,
                    label: "Print A4",
                    color: AppTheme.primaryPurple,
                    onTap: () {
                      context.read<InvoiceProvider>().printInvoice(invoice);
                    },
                  ),
                  _buildActionCircle(
                    icon: Icons.share_rounded,
                    label: "Share PDF",
                    color: AppTheme.accentBlue,
                    onTap: () {
                      context.read<InvoiceProvider>().shareInvoice(invoice);
                    },
                  ),
                  _buildActionCircle(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: "WhatsApp",
                    color: AppTheme.accentTeal,
                    onTap: () {
                      context.read<InvoiceProvider>().shareWhatsAppDirect(invoice);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  child: const Text("Done & Back to Dashboard"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}
