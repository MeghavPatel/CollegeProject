import 'package:flutter/material.dart';
import 'package:hp_bill/models/quick_entry.dart';
import 'package:hp_bill/providers/transaction_provider.dart';
import 'package:hp_bill/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class CashBankEntryScreen extends StatefulWidget {
  const CashBankEntryScreen({Key? key}) : super(key: key);

  @override
  State<CashBankEntryScreen> createState() => _CashBankEntryScreenState();
}

class _CashBankEntryScreenState extends State<CashBankEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form states
  AccountMode _selectedMode = AccountMode.cash;
  final _partyController = TextEditingController();
  final _amountController = TextEditingController();
  final _remarksController = TextEditingController();

  final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().fetchTransactions();
    });
  }

  @override
  void dispose() {
    _partyController.dispose();
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _submitEntry() async {
    if (!_formKey.currentState!.validate()) return;

    final transProv = context.read<TransactionProvider>();
    final amount = double.tryParse(_amountController.text) ?? 0.0;

    await transProv.addQuickEntry(
      type: QuickEntryType.receipt,
      mode: _selectedMode,
      partyName: _partyController.text.trim(),
      amount: amount,
      remarks: _remarksController.text.trim(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Quick receipt entry saved!"),
        backgroundColor: AppTheme.accentBlue,
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cash / Bank Quick Entry"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [


            Form(
              key: _formKey,
              child: Column(
                children: [


                  // Account mode selector
                  DropdownButtonFormField<AccountMode>(
                    value: _selectedMode,
                    decoration: const InputDecoration(
                      labelText: "Account Mode",
                      prefixIcon: Icon(Icons.account_balance_wallet_rounded, color: AppTheme.accentBlue),
                    ),
                    items: const [
                      DropdownMenuItem(value: AccountMode.cash, child: Text("Cash Account")),
                      DropdownMenuItem(value: AccountMode.bank, child: Text("Bank / UPI")),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedMode = val;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 18),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Autocomplete<String>(
                        textEditingController: _partyController,
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          final customers = context.read<TransactionProvider>().customers;
                          if (textEditingValue.text.isEmpty) {
                            return customers;
                          }
                          return customers.where((String option) {
                            return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        onSelected: (String selection) {
                          _partyController.text = selection;
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
                                      leading: const Icon(Icons.person_outline_rounded, color: AppTheme.accentBlue, size: 20),
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
                          return TextFormField(
                            controller: textController,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: "Party / Account Name",
                              hintText: "Enter client or ledger account name",
                              prefixIcon: Icon(Icons.business_rounded, color: AppTheme.accentBlue),
                            ),
                            textCapitalization: TextCapitalization.words,
                            validator: (val) => val == null || val.isEmpty ? "Required field" : null,
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 18),

                  // Amount
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Amount (₹)",
                      hintText: "0.00",
                      prefixIcon: Icon(Icons.currency_rupee_rounded, color: AppTheme.accentBlue),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return "Required field";
                      if (double.tryParse(val) == null) return "Invalid amount";
                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  // Remarks
                  TextFormField(
                    controller: _remarksController,
                    decoration: const InputDecoration(
                      labelText: "Remarks / Ref. No",
                      hintText: "Chq details, narration, invoice ref etc.",
                      prefixIcon: Icon(Icons.edit_note_rounded, color: AppTheme.accentBlue),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitEntry,
                      child: const Text("Save Transaction"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
