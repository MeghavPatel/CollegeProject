import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/activity_provider.dart';

// -----------------------------------------------------------------------------
// 1. DATE FILTER STATE
// -----------------------------------------------------------------------------
enum DateFilter { allTime, thisMonth, lastYear, custom }

class DateRangeState {
  final DateFilter filter;
  final DateTime? start;
  final DateTime? end;

  DateRangeState({required this.filter, this.start, this.end});
}

class ExpenseDateRangeNotifier extends Notifier<DateRangeState> {
  @override
  DateRangeState build() {
    return DateRangeState(filter: DateFilter.thisMonth);
  }

  void updateFilter(DateFilter filter, {DateTime? start, DateTime? end}) {
    state = DateRangeState(filter: filter, start: start, end: end);
  }
}

final expenseDateRangeProvider = 
    NotifierProvider<ExpenseDateRangeNotifier, DateRangeState>(ExpenseDateRangeNotifier.new);

// -----------------------------------------------------------------------------
// 2. STREAM PROVIDER (The Real-Time Listener)
// -----------------------------------------------------------------------------
final allExpensesProvider = StreamProvider<List<ExpenseEntry>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'dummy_uid';
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('expenses')
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => ExpenseEntry.fromFirestore(doc)).toList());
});

// -----------------------------------------------------------------------------
// 3. FILTER LOGIC
// -----------------------------------------------------------------------------
final filteredExpensesProvider = Provider<AsyncValue<List<ExpenseEntry>>>((ref) {
  final expensesAsync = ref.watch(allExpensesProvider);
  final dateRange = ref.watch(expenseDateRangeProvider);
  
  return expensesAsync.whenData((expenses) {
    final now = DateTime.now();
    List<ExpenseEntry> filtered;
    
    switch (dateRange.filter) {
      case DateFilter.thisMonth:
        filtered = expenses.where((e) => e.date.month == now.month && e.date.year == now.year).toList();
        break;
      case DateFilter.lastYear:
        final oneYearAgo = DateTime(now.year - 1, now.month, now.day);
        filtered = expenses.where((e) => e.date.isAfter(oneYearAgo)).toList();
        break;
      case DateFilter.custom:
        if (dateRange.start != null && dateRange.end != null) {
          final endDay = dateRange.end!.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
          filtered = expenses.where((e) => 
            e.date.isAfter(dateRange.start!) && e.date.isBefore(endDay)
          ).toList();
        } else {
          filtered = expenses;
        }
        break;
      case DateFilter.allTime:
        filtered = expenses;
    }
    
    return filtered;
  });
});

// -----------------------------------------------------------------------------
// 4. TOTAL CALCULATION
// -----------------------------------------------------------------------------
final totalExpenseProvider = Provider<AsyncValue<double>>((ref) {
  final filteredExpensesAsync = ref.watch(filteredExpensesProvider);
  
  return filteredExpensesAsync.whenData((expenses) {
    return expenses.fold(0.0, (acc, expense) => acc + expense.amount);
  });
});

// -----------------------------------------------------------------------------
// 5. CONTROLLER (Add/Delete Logic Only)
// -----------------------------------------------------------------------------
class ExpenseController extends Notifier<void> {
  @override
  void build() {}

  Future<void> addExpense(String title, double amount, String? account, String? note, DateTime date) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .add({
        'title': title,
        'amount': amount,
        'category': 'General',
        'account': account,
        'note': note,
        'date': Timestamp.fromDate(date),
      });
      
      // Log Activity
      ref.read(activityProvider.notifier).logActivity('Expense', 'Added: $title - ₹$amount');
      
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .doc(id)
          .delete();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateExpense({
    required String id,
    required String title,
    required double amount,
    required String? note,
    required DateTime date,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .doc(id)
          .update({
        'title': title,
        'amount': amount,
        'note': note,
        'date': Timestamp.fromDate(date),
      });
      ref.read(activityProvider.notifier).logActivity('Expense', 'Updated: $title - ₹$amount');
    } catch (e) {
      rethrow;
    }
  }
}

final expenseControllerProvider = NotifierProvider<ExpenseController, void>(ExpenseController.new);