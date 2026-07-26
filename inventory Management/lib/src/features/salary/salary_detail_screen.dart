import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/models.dart';
import 'data/salary_provider.dart';
import '../../core/auth/security_helper.dart';

class SalaryDetailScreen extends ConsumerWidget {
  final EmployeeProfile employee;
  const SalaryDetailScreen({super.key, required this.employee});

  static const Color brandGreen = Color(0xFF1B5E20);

  void _showAdvanceDialog(BuildContext context, WidgetRef ref, EmployeeProfile currentEmployee) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.orange.withValues(alpha: 0.12),
                      child: const Icon(Icons.handshake, color: Colors.orange),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TAKE ADVANCE',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.orange,
                            ),
                          ),
                          Text(
                            currentEmployee.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                  decoration: InputDecoration(
                    labelText: 'Advance Amount ₹',
                    prefixIcon: const Icon(Icons.currency_rupee),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (v) {
                    final val = double.tryParse(v ?? '');
                    if (val == null || val <= 0) return 'Enter valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: noteController,
                  decoration: InputDecoration(
                    labelText: 'Note (Optional)',
                    prefixIcon: const Icon(Icons.note_alt_outlined),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          ref.read(paymentProvider.notifier).addPayment(
                            currentEmployee.id,
                            currentEmployee.name,
                            double.parse(amountController.text),
                            noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                            type: 'Advance',
                          );
                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          'CONFIRM',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPaySalaryDialog(BuildContext context, WidgetRef ref, EmployeeProfile currentEmployee) {
    final overtimeController = TextEditingController(text: '0');
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final salary = currentEmployee.salary;
          final advance = currentEmployee.advanceTaken;
          final overtimeBonus = double.tryParse(overtimeController.text) ?? 0.0;
          final finalPayout = (salary - advance) + overtimeBonus;

          return Dialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: brandGreen.withValues(alpha: 0.12),
                            child: const Icon(Icons.payments, color: brandGreen),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PAY MONTHLY SALARY',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: brandGreen,
                                  ),
                                ),
                                Text(
                                  currentEmployee.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _buildBreakdownRow('Monthly Salary', '₹${salary.toStringAsFixed(0)}'),
                            const SizedBox(height: 6),
                            _buildBreakdownRow('Advance Taken', '- ₹${advance.toStringAsFixed(0)}', isNegative: true),
                            const Divider(height: 16),
                            _buildBreakdownRow('Net Base Payable', '₹${(salary - advance).toStringAsFixed(0)}', isBold: true),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: overtimeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                        decoration: InputDecoration(
                          labelText: 'Overtime / Bonuses ₹',
                          prefixIcon: const Icon(Icons.add_circle_outline, color: brandGreen),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (v) {
                          setStateDialog(() {});
                        },
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Enter 0 if none';
                          final val = double.tryParse(v);
                          if (val == null || val < 0) return 'Enter a valid amount';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: noteController,
                        decoration: InputDecoration(
                          labelText: 'Note (Optional)',
                          prefixIcon: const Icon(Icons.note_alt_outlined),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: brandGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: brandGreen.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'FINAL PAYOUT',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: brandGreen),
                            ),
                            Text(
                              '₹${finalPayout.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: brandGreen),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: brandGreen,
                                side: const BorderSide(color: brandGreen),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brandGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () {
                                if (!formKey.currentState!.validate()) return;
                                ref.read(paymentProvider.notifier).addPayment(
                                  currentEmployee.id,
                                  currentEmployee.name,
                                  finalPayout,
                                  noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                                  type: 'Salary',
                                  overtimeBonus: overtimeBonus,
                                );
                                Navigator.pop(ctx);
                              },
                              child: const Text(
                                'PAY NOW',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditEmployeeDialog(BuildContext context, WidgetRef ref, EmployeeProfile currentEmployee) {
    final nameController = TextEditingController(text: currentEmployee.name);
    final customRoleController = TextEditingController(text: ['Helper', 'Manager', 'Driver'].contains(currentEmployee.role) ? '' : (currentEmployee.role ?? ''));
    final salaryController = TextEditingController(text: currentEmployee.salary.toStringAsFixed(0));
    final phoneController = TextEditingController(text: currentEmployee.phoneNumber);
    final formKey = GlobalKey<FormState>();
    String selectedRole = ['Helper', 'Manager', 'Driver'].contains(currentEmployee.role) 
        ? (currentEmployee.role ?? 'Helper') 
        : 'Other';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
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
                              'EDIT EMPLOYEE',
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
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Employee Name',
                          prefixIcon: const Icon(Icons.person, color: brandGreen),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: brandGreen, width: 2),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        decoration: InputDecoration(
                          labelText: 'Role',
                          prefixIcon: const Icon(Icons.work, color: brandGreen),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: brandGreen, width: 2),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Helper', child: Text('Helper')),
                          DropdownMenuItem(value: 'Manager', child: Text('Manager')),
                          DropdownMenuItem(value: 'Driver', child: Text('Driver')),
                          DropdownMenuItem(value: 'Other', child: Text('Other (Type Custom)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              selectedRole = val;
                            });
                          }
                        },
                      ),
                      if (selectedRole == 'Other') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: customRoleController,
                          decoration: InputDecoration(
                            labelText: 'Custom Role Title',
                            prefixIcon: const Icon(Icons.edit_note, color: brandGreen),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: brandGreen, width: 2),
                            ),
                          ),
                          validator: (v) => (selectedRole == 'Other' && (v == null || v.trim().isEmpty)) ? 'Enter role title' : null,
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: salaryController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Salary (Monthly) ₹',
                          prefixIcon: const Icon(Icons.currency_rupee, color: brandGreen),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: brandGreen, width: 2),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Enter salary';
                          final val = double.tryParse(v);
                          if (val == null || val < 0) return 'Enter a valid amount';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: const Icon(Icons.phone, color: brandGreen),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: brandGreen, width: 2),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Enter phone number';
                          if (v.trim().length < 10) return 'Enter a valid phone number (min 10 digits)';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: brandGreen,
                                side: const BorderSide(color: brandGreen, width: 2),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brandGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () {
                                if (!formKey.currentState!.validate()) return;
                                final role = selectedRole == 'Other' 
                                    ? customRoleController.text.trim() 
                                    : selectedRole;
                                final salary = double.tryParse(salaryController.text.trim()) ?? 0.0;
                                final phoneNumber = phoneController.text.trim();
                                
                                ref.read(employeeProvider.notifier).updateEmployee(
                                  currentEmployee.id,
                                  nameController.text.trim(),
                                  role,
                                  salary,
                                  phoneNumber,
                                );
                                Navigator.pop(ctx);
                              },
                              child: const Text(
                                'SAVE',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditPaymentDialog(BuildContext context, WidgetRef ref, EmployeeProfile currentEmployee, SalaryPayment payment) {
    final amountController = TextEditingController(text: payment.amount.toStringAsFixed(0));
    final noteController = TextEditingController(text: payment.note ?? '');
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = payment.paymentDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Edit ${payment.type}',
            style: const TextStyle(fontWeight: FontWeight.w600, color: brandGreen),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Amount ₹',
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) {
                      final val = double.tryParse(v ?? '');
                      if (val == null || val <= 0) return 'Enter valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteController,
                    decoration: InputDecoration(
                      labelText: 'Note (Optional)',
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: brandGreen),
                          const SizedBox(width: 12),
                          Text(
                            'Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: brandGreen),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final verified = await showPasswordVerificationDialog(context);
                if (verified) {
                  ref.read(paymentProvider.notifier).updatePayment(
                        id: payment.id,
                        employeeId: payment.employeeId,
                        employeeName: currentEmployee.name,
                        oldAmount: payment.amount,
                        newAmount: double.parse(amountController.text),
                        type: payment.type,
                        note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                        date: selectedDate,
                      );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, {bool isNegative = false, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isNegative ? Colors.red.shade700 : null,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isNegative ? Colors.red.shade700 : null,
          ),
        ),
      ],
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
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: brandGreen,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (dateRange != null) {
      ref.read(dateRangeProvider.notifier).updateFilter(
        DateFilter.custom,
        start: dateRange.start,
        end: dateRange.end,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeesProvider);
    final currentEmployee = employeesAsync.when(
      data: (list) => list.firstWhere((e) => e.id == employee.id, orElse: () => employee),
      loading: () => employee,
      error: (_, __) => employee,
    );

    final paymentsAsync = ref.watch(employeePaymentsProvider(currentEmployee.id));
    final totalAsync = ref.watch(totalPaidProvider(currentEmployee.id));
    final dateRange = ref.watch(dateRangeProvider);

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
        title: Text(
          currentEmployee.name,
          style: const TextStyle(
            color: brandGreen,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: brandGreen),
            onPressed: () => _showEditEmployeeDialog(context, ref, currentEmployee),
            tooltip: 'Edit Employee',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Card with Total, Balance, and Filter
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [brandGreen, Colors.teal.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 6)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'TOTAL PAID',
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
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
                            ref.read(dateRangeProvider.notifier).updateFilter(filter);
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
                  const SizedBox(height: 4),
                  totalAsync.when(
                    data: (total) => Text(
                      '₹${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    loading: () => const Text(
                      '₹0',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    error: (context, index) => const Text(
                      'Error',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white30, height: 1),
                  const SizedBox(height: 12),
                  // Breakdown row for current month calculations
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildHeaderBreakdownCol('Monthly Salary', '₹${currentEmployee.salary.toStringAsFixed(0)}'),
                      _buildHeaderBreakdownCol('Advance Balance', '₹${currentEmployee.advanceTaken.toStringAsFixed(0)}', isAlert: currentEmployee.advanceTaken > 0),
                      _buildHeaderBreakdownCol('Net Base Payable', '₹${currentEmployee.netPayableSalary.toStringAsFixed(0)}', isHighlight: true),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Payment List
          Expanded(
            child: paymentsAsync.when(
              data: (payments) {
                if (payments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.payment_outlined, 
                          size: 64, 
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No payments found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: payments.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final payment = payments[index];
                    return Dismissible(
                      key: Key('payment_${payment.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white, size: 20),
                      ),
                      confirmDismiss: (direction) async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text('Delete Payment?'),
                            content: const Text('This action cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
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
                        ref.read(paymentProvider.notifier).deletePayment(
                          payment.id,
                          currentEmployee.id,
                          currentEmployee.name,
                          payment.amount,
                          payment.type,
                        );
                      },
                      child: GestureDetector(
                        onTap: () => _showEditPaymentDialog(context, ref, currentEmployee, payment),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        child: Row(
                          children: [
                            Text(
                              '${payment.paymentDate.day}/${payment.paymentDate.month}/${payment.paymentDate.year}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: payment.type == 'Advance' ? Colors.orange.withValues(alpha: 0.15) : brandGreen.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          payment.type.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: payment.type == 'Advance' ? Colors.orange.shade800 : brandGreen,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          payment.note ?? (payment.type == 'Advance' ? 'Mid-month advance' : 'Monthly salary'),
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (payment.overtimeBonus != null && payment.overtimeBonus! > 0) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Includes Overtime/Bonus: ₹${payment.overtimeBonus!.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Text(
                              '₹${payment.amount.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: payment.type == 'Advance' ? Colors.orange.shade800 : brandGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showAdvanceDialog(context, ref, currentEmployee),
                  icon: const Icon(Icons.handshake_outlined),
                  label: const Text('TAKE ADVANCE'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade800,
                    side: BorderSide(color: Colors.orange.shade800, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showPaySalaryDialog(context, ref, currentEmployee),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('PAY SALARY'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandGreen,
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

  Widget _buildHeaderBreakdownCol(String label, String value, {bool isAlert = false, bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isAlert ? Colors.orange.shade300 : (isHighlight ? Colors.lightGreen.shade200 : Colors.white),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _getFilterText(DateFilter filter) {
    switch (filter) {
      case DateFilter.allTime:
        return 'All Time';
      case DateFilter.thisMonth:
        return 'This Month';
      case DateFilter.lastYear:
        return 'Last 1 Year';
      case DateFilter.custom:
        return 'Custom';
    }
  }
}