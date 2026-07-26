import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/activity_provider.dart';

class VendorLedgerNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> addLedgerEntry(String type, double amount, String? note, DateTime date) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chai_wala_ledger')
          .add({
        'type': type,
        'amount': amount,
        'note': note,
        'date': Timestamp.fromDate(date),
      });

      final typeStr = type == 'DEPOSIT' ? 'Deposit' : 'Running Expense';
      ref.read(activityProvider.notifier).logActivity(
        'Expense', 'Vendor Ledger $typeStr: ₹${amount.toStringAsFixed(0)} - ${note ?? "General"}',
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteLedgerEntry(String id, double amount, String type) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chai_wala_ledger')
          .doc(id)
          .delete();

      final typeStr = type == 'DEPOSIT' ? 'Deposit' : 'Running Expense';
      ref.read(activityProvider.notifier).logActivity(
        'Expense', 'Deleted Vendor Ledger $typeStr: ₹${amount.toStringAsFixed(0)}',
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateLedgerEntry({
    required String id,
    required String type,
    required double amount,
    required String? note,
    required DateTime date,
  }) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chai_wala_ledger')
          .doc(id)
          .update({
        'type': type,
        'amount': amount,
        'note': note,
        'date': Timestamp.fromDate(date),
      });

      final typeStr = type == 'DEPOSIT' ? 'Deposit' : 'Running Expense';
      ref.read(activityProvider.notifier).logActivity(
        'Expense', 'Updated Vendor Ledger $typeStr: ₹${amount.toStringAsFixed(0)} - ${note ?? "General"}',
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final vendorLedgerControllerProvider = NotifierProvider<VendorLedgerNotifier, AsyncValue<void>>(VendorLedgerNotifier.new);

// Stream of Chai Wala Ledger Entries
final vendorLedgerEntriesProvider = StreamProvider<List<ChaiWalaLedgerEntry>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'dummy_uid';
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('chai_wala_ledger')
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => ChaiWalaLedgerEntry.fromFirestore(doc)).toList());
});

// Aggregated Balance Class
class VendorLedgerBalance {
  final double totalDeposited;
  final double totalConsumed;
  final double currentJamaBalance;

  VendorLedgerBalance({
    required this.totalDeposited,
    required this.totalConsumed,
    required this.currentJamaBalance,
  });
}

// Calculated balance provider
final vendorLedgerBalanceProvider = Provider<AsyncValue<VendorLedgerBalance>>((ref) {
  final entriesAsync = ref.watch(vendorLedgerEntriesProvider);
  return entriesAsync.whenData((entries) {
    double deposited = 0.0;
    double consumed = 0.0;

    for (var entry in entries) {
      if (entry.type == 'DEPOSIT') {
        deposited += entry.amount;
      } else {
        consumed += entry.amount;
      }
    }

    return VendorLedgerBalance(
      totalDeposited: deposited,
      totalConsumed: consumed,
      currentJamaBalance: deposited - consumed,
    );
  });
});
