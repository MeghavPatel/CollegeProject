import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/expense_provider.dart';
import 'data/vendor_ledger_provider.dart';
import '../../core/auth/security_helper.dart';
import '../../core/models/models.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  static const Color brandGreen = Color(0xFF1B5E20);
  bool _isVendorMode = false;

  void _showAddExpenseDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: brandGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.receipt_long, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'ADD EXPENSE',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: brandGreen,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Expense Title',
                        hintText: 'e.g., Lunch, Petrol, Bills',
                        prefixIcon: const Icon(Icons.title, color: brandGreen),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter expense title' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      decoration: InputDecoration(
                        labelText: 'Amount ₹',
                        hintText: 'Enter amount',
                        prefixIcon: const Icon(Icons.currency_rupee, color: brandGreen),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      validator: (v) {
                        final val = double.tryParse(v ?? '');
                        if (val == null || val <= 0) return 'Enter valid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Note (Optional)',
                        hintText: 'Additional details',
                        prefixIcon: const Icon(Icons.note_alt_outlined, color: brandGreen),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: Theme.of(context).colorScheme.copyWith(primary: brandGreen),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (date != null) {
                          setState(() {
                            selectedDate = date;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: brandGreen),
                            const SizedBox(width: 12),
                            Text(
                              'Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          
                          ref.read(expenseControllerProvider.notifier).addExpense(
                                titleController.text.trim(),
                                double.parse(amountController.text),
                                null,
                                noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                                selectedDate,
                              );
                          Navigator.pop(ctx);
                        },
                        child: const Text('ADD EXPENSE', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditExpenseDialog(BuildContext context, WidgetRef ref, ExpenseEntry expense) {
    final titleController = TextEditingController(text: expense.title);
    final amountController = TextEditingController(text: expense.amount.toStringAsFixed(0));
    final noteController = TextEditingController(text: expense.note ?? '');
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = expense.date;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: brandGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.edit, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'EDIT EXPENSE',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: brandGreen,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Expense Title',
                        hintText: 'e.g., Lunch, Petrol, Bills',
                        prefixIcon: const Icon(Icons.title, color: brandGreen),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter expense title' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      decoration: InputDecoration(
                        labelText: 'Amount ₹',
                        hintText: 'Enter amount',
                        prefixIcon: const Icon(Icons.currency_rupee, color: brandGreen),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      validator: (v) {
                        final val = double.tryParse(v ?? '');
                        if (val == null || val <= 0) return 'Enter valid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Note (Optional)',
                        hintText: 'Additional details',
                        prefixIcon: const Icon(Icons.note_alt_outlined, color: brandGreen),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: Theme.of(context).colorScheme.copyWith(primary: brandGreen),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (date != null) {
                          setState(() {
                            selectedDate = date;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: brandGreen),
                            const SizedBox(width: 12),
                            Text(
                              'Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final verified = await showPasswordVerificationDialog(context);
                          if (verified) {
                            ref.read(expenseControllerProvider.notifier).updateExpense(
                                  id: expense.id,
                                  title: titleController.text.trim(),
                                  amount: double.parse(amountController.text),
                                  note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                                  date: selectedDate,
                                );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                          }
                        },
                        child: const Text('SAVE EXPENSE', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditLedgerEntryDialog(BuildContext context, WidgetRef ref, ChaiWalaLedgerEntry entry) {
    final amountController = TextEditingController(text: entry.amount.toStringAsFixed(0));
    final noteController = TextEditingController(text: entry.note ?? '');
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = entry.date;
    String selectedType = entry.type;

    final themeColor = brandGreen;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: themeColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.edit, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'EDIT LEDGER ENTRY',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: brandGreen,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: InputDecoration(
                        labelText: 'Entry Type',
                        prefixIcon: const Icon(Icons.swap_horiz, color: brandGreen),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'DEPOSIT', child: Text('Deposit')),
                        DropdownMenuItem(value: 'EXPENSE', child: Text('Expense')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            selectedType = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      decoration: InputDecoration(
                        labelText: 'Amount ₹',
                        hintText: 'Enter amount',
                        prefixIcon: Icon(Icons.currency_rupee, color: themeColor),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      validator: (v) {
                        final val = double.tryParse(v ?? '');
                        if (val == null || val <= 0) return 'Enter valid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: 'Description / Note',
                        hintText: 'e.g., Supplies purchase',
                        prefixIcon: Icon(Icons.note_alt_outlined, color: themeColor),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: Theme.of(context).colorScheme.copyWith(primary: themeColor),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (date != null) {
                          setState(() {
                            selectedDate = date;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: themeColor),
                            const SizedBox(width: 12),
                            Text(
                              'Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final verified = await showPasswordVerificationDialog(context);
                          if (verified) {
                            ref.read(vendorLedgerControllerProvider.notifier).updateLedgerEntry(
                                  id: entry.id,
                                  type: selectedType,
                                  amount: double.parse(amountController.text),
                                  note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                                  date: selectedDate,
                                );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                          }
                        },
                        child: const Text('SAVE ENTRY', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddVendorLedgerDialog(BuildContext context, String type) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = DateTime.now();

    final isDeposit = type == 'DEPOSIT';
    final title = isDeposit ? 'ADD DEPOSIT' : 'ADD RUNNING EXPENSE';
    final themeColor = isDeposit ? brandGreen : Colors.red.shade700;
    final icon = isDeposit ? Icons.arrow_upward : Icons.arrow_downward;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: themeColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: themeColor,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      decoration: InputDecoration(
                        labelText: 'Amount ₹',
                        hintText: 'Enter amount',
                        prefixIcon: Icon(Icons.currency_rupee, color: themeColor),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      validator: (v) {
                        final val = double.tryParse(v ?? '');
                        if (val == null || val <= 0) return 'Enter valid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: 'Description / Note',
                        hintText: isDeposit ? 'e.g., Cash deposit' : 'e.g., Supplies purchase',
                        prefixIcon: Icon(Icons.note_alt_outlined, color: themeColor),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: Theme.of(context).colorScheme.copyWith(primary: themeColor),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (date != null) {
                          setState(() {
                            selectedDate = date;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: themeColor),
                            const SizedBox(width: 12),
                            Text(
                              'Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          
                          ref.read(vendorLedgerControllerProvider.notifier).addLedgerEntry(
                                type,
                                double.parse(amountController.text),
                                noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                                selectedDate,
                              );
                          Navigator.pop(ctx);
                        },
                        child: Text(isDeposit ? 'RECORD DEPOSIT' : 'RECORD EXPENSE', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDateRangePicker(BuildContext context, WidgetRef ref) async {
    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: brandGreen),
          ),
          child: child!,
        );
      },
    );
    
    if (dateRange != null) {
      ref.read(expenseDateRangeProvider.notifier).updateFilter(
        DateFilter.custom,
        start: dateRange.start,
        end: dateRange.end,
      );
    }
  }

  String _getFilterText(DateFilter filter) {
    switch (filter) {
      case DateFilter.allTime: return 'All Time';
      case DateFilter.thisMonth: return 'This Month';
      case DateFilter.lastYear: return 'Last 1 Year';
      case DateFilter.custom: return 'Custom';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredExpensesAsync = ref.watch(filteredExpensesProvider);
    final totalExpenseAsync = ref.watch(totalExpenseProvider);
    final dateRange = ref.watch(expenseDateRangeProvider);

    final ledgerEntriesAsync = ref.watch(vendorLedgerEntriesProvider);
    final ledgerBalanceAsync = ref.watch(vendorLedgerBalanceProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0.5,
        shadowColor: Colors.black12,
        foregroundColor: brandGreen,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          color: brandGreen,
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Expense Management',
          style: TextStyle(color: brandGreen, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          // 🔹 TAB SELECTOR (Sliding style)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isVendorMode = false),
                      child: Container(
                        decoration: BoxDecoration(
                          color: !_isVendorMode ? brandGreen : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        margin: const EdgeInsets.all(4),
                        child: Center(
                          child: Text(
                            'Personal Expenses',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: !_isVendorMode ? Colors.white : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isVendorMode = true),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isVendorMode ? brandGreen : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        margin: const EdgeInsets.all(4),
                        child: Center(
                          child: Text(
                            'Vendor Ledger',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _isVendorMode ? Colors.white : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🔹 HEADER CARD (Render based on Tab)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: !_isVendorMode
                ? Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [brandGreen, Colors.teal.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 6))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('TOTAL SPENT', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                            const Spacer(),
                            PopupMenuButton<DateFilter>(
                              icon: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _getFilterText(dateRange.filter),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                                  ],
                                ),
                              ),
                              onSelected: (filter) {
                                if (filter == DateFilter.custom) {
                                  _showDateRangePicker(context, ref);
                                } else {
                                  ref.read(expenseDateRangeProvider.notifier).updateFilter(filter);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: DateFilter.allTime, child: Text('All Time')),
                                const PopupMenuItem(value: DateFilter.thisMonth, child: Text('This Month')),
                                const PopupMenuItem(value: DateFilter.lastYear, child: Text('Last 1 Year')),
                                const PopupMenuItem(value: DateFilter.custom, child: Text('Custom Date')),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        totalExpenseAsync.when(
                          data: (total) => Text(
                            '₹${total.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900),
                          ),
                          loading: () => const Text('₹0', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                          error: (context, index) => const Text('Error', style: TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(height: 8),
                        if (dateRange.filter == DateFilter.custom && dateRange.start != null && dateRange.end != null)
                          Text(
                            '${dateRange.start!.day}/${dateRange.start!.month}/${dateRange.start!.year} - ${dateRange.end!.day}/${dateRange.end!.month}/${dateRange.end!.year}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          )
                        else
                          const Text('Tap filter to change date range', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  )
                : ledgerBalanceAsync.when(
                    data: (balance) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color(0xFF0F3A11), brandGreen],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 6))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CURRENT JAMA BALANCE',
                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '₹${balance.currentJamaBalance.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: balance.currentJamaBalance >= 0 ? Colors.green.shade200 : Colors.redAccent.shade100,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Divider(color: Colors.white24, height: 1),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSummaryCol('Deposited (Total)', '₹${balance.totalDeposited.toStringAsFixed(0)}', Colors.white),
                                _buildSummaryCol('Consumed (Total)', '₹${balance.totalConsumed.toStringAsFixed(0)}', Colors.orange.shade200),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                    loading: () => Container(height: 140, decoration: BoxDecoration(color: brandGreen, borderRadius: BorderRadius.circular(22)), child: const Center(child: CircularProgressIndicator(color: Colors.white))),
                    error: (e, _) => Container(height: 140, decoration: BoxDecoration(color: brandGreen, borderRadius: BorderRadius.circular(22)), child: Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white)))),
                  ),
          ),

          // 🔹 LIST VIEW
          Expanded(
            child: !_isVendorMode
                ? filteredExpensesAsync.when(
                    data: (expenses) {
                      if (expenses.isEmpty) {
                        return _buildEmptyState('No personal expenses found');
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: expenses.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final expense = expenses[index];
                          return Dismissible(
                            key: Key('expense_${expense.id}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.delete, color: Colors.white, size: 20),
                            ),
                            confirmDismiss: (direction) async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: Theme.of(context).colorScheme.surface,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: const Text('Delete Expense?'),
                                  content: Text('This will permanently delete "${expense.title}".'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                if (context.mounted) {
                                  return await showPasswordVerificationDialog(context);
                                }
                              }
                              return false;
                            },
                            onDismissed: (direction) {
                              ref.read(expenseControllerProvider.notifier).deleteExpense(expense.id);
                            },
                            child: GestureDetector(
                              onTap: () => _showEditExpenseDialog(context, ref, expense),
                              child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface, 
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade100),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '${expense.date.day}/${expense.date.month}/${expense.date.year}',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          expense.title,
                                          style: TextStyle(
                                            fontSize: 15, 
                                            fontWeight: FontWeight.bold, 
                                            color: Theme.of(context).colorScheme.onSurface
                                          ),
                                        ),
                                        if (expense.note != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            expense.note!,
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), 
                                              fontSize: 12
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '₹${expense.amount.toStringAsFixed(0)}',
                                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ],
                              ),
                            ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: brandGreen)),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  )
                : ledgerEntriesAsync.when(
                    data: (entries) {
                      if (entries.isEmpty) {
                        return _buildEmptyState('Ledger is empty. Record a deposit to start.');
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: entries.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final isDeposit = entry.type == 'DEPOSIT';
                          final color = isDeposit ? brandGreen : Colors.red.shade700;

                          return Dismissible(
                            key: Key('ledger_${entry.id}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.delete, color: Colors.white, size: 20),
                            ),
                            confirmDismiss: (direction) async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: Theme.of(context).colorScheme.surface,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: const Text('Delete Ledger Entry?'),
                                  content: Text('Delete this ${isDeposit ? "deposit" : "running expense"} of ₹${entry.amount.toStringAsFixed(0)}?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                if (context.mounted) {
                                  return await showPasswordVerificationDialog(context);
                                }
                              }
                              return false;
                            },
                            onDismissed: (direction) {
                              ref.read(vendorLedgerControllerProvider.notifier).deleteLedgerEntry(entry.id, entry.amount, entry.type);
                            },
                            child: GestureDetector(
                              onTap: () => _showEditLedgerEntryDialog(context, ref, entry),
                              child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface, 
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade100),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '${entry.date.day}/${entry.date.month}/${entry.date.year}',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  const SizedBox(width: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isDeposit ? 'DEPOSIT' : 'EXPENSE',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      entry.note ?? (isDeposit ? 'Cash Deposit' : 'Supplies consumed'),
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), 
                                        fontSize: 14
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${isDeposit ? '+' : '-'}₹${entry.amount.toStringAsFixed(0)}',
                                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ],
                              ),
                            ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: brandGreen)),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: !_isVendorMode
              ? ElevatedButton.icon(
                  onPressed: () => _showAddExpenseDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('ADD EXPENSE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddVendorLedgerDialog(context, 'DEPOSIT'),
                        icon: const Icon(Icons.arrow_upward),
                        label: const Text('ADD DEPOSIT'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: brandGreen,
                          side: const BorderSide(color: brandGreen, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddVendorLedgerDialog(context, 'EXPENSE'),
                        icon: const Icon(Icons.arrow_downward),
                        label: const Text('ADD EXPENSE'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSummaryCol(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined, 
            size: 64, 
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)
          ),
          const SizedBox(height: 16),
          Text(
            msg, 
            style: TextStyle(
              fontSize: 16, 
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), 
              fontWeight: FontWeight.w600
            )
          ),
        ],
      ),
    );
  }
}