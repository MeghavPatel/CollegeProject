import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/activity_provider.dart';

// Transport CRUD Provider
class TransportNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> addTransporter(String name, {double? initialPayment}) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");
      
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('transporters')
          .add({
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (initialPayment != null && initialPayment > 0) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('transport_payments')
            .add({
          'transporterId': docRef.id,
          'amount': initialPayment,
          'note': 'Initial payment',
          'date': FieldValue.serverTimestamp(),
        });
      }

      final logMsg = initialPayment != null && initialPayment > 0 
          ? 'Added new transporter: $name (Initial payment: ₹${initialPayment.toStringAsFixed(0)})'
          : 'Added new transporter: $name';

      ref.read(activityProvider.notifier).logActivity('Transport', logMsg);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addTransportPayment(String transporterId, String transporterName, double amount, String? note) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('transport_payments')
          .add({
        'transporterId': transporterId,
        'amount': amount,
        'note': note,
        'date': FieldValue.serverTimestamp(),
      });
      ref.read(activityProvider.notifier).logActivity(
        'Transport', 'Paid ₹${amount.toStringAsFixed(0)} to $transporterName',
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteTransporter(String transporterId, String transporterName) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");
      final batch = FirebaseFirestore.instance.batch();
      
      // Delete all payments for this transporter
      final paymentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('transport_payments')
          .where('transporterId', isEqualTo: transporterId)
          .get();
          
      for (var doc in paymentsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete transporter
      batch.delete(FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('transporters')
          .doc(transporterId));
      
      await batch.commit();
      
      ref.read(activityProvider.notifier).logActivity(
        'Transport', 'Deleted transporter: $transporterName',
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteTransportPayment(String paymentId, double amount, String transporterName) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('transport_payments')
          .doc(paymentId)
          .delete();
      ref.read(activityProvider.notifier).logActivity(
        'Transport', 'Deleted payment of ₹${amount.toStringAsFixed(0)} for $transporterName',
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateTransporter(String id, String name) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('transporters')
          .doc(id)
          .update({
        'name': name,
      });
      ref.read(activityProvider.notifier).logActivity(
        'Transport', 'Updated transporter name to: $name',
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateTransportPayment({
    required String paymentId,
    required String transporterName,
    required double oldAmount,
    required double newAmount,
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
          .collection('transport_payments')
          .doc(paymentId)
          .update({
        'amount': newAmount,
        'note': note,
        'date': Timestamp.fromDate(date),
      });
      ref.read(activityProvider.notifier).logActivity(
        'Transport', 'Updated transport payment for $transporterName (₹$oldAmount -> ₹$newAmount)',
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

// Internal Streams
final _transportersStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'dummy_uid';
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('transporters')
      .snapshots();
});

final _allTransportPaymentsStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'dummy_uid';
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('transport_payments')
      .snapshots();
});

// Providers
final transportProvider = Provider<AsyncValue<List<TransporterWithBalance>>>((ref) {
  final transportersAsync = ref.watch(_transportersStreamProvider);
  final paymentsAsync = ref.watch(_allTransportPaymentsStreamProvider);
  
  if (transportersAsync.isLoading || paymentsAsync.isLoading) {
    return const AsyncValue.loading();
  }
  
  if (transportersAsync.hasError) return AsyncValue.error(transportersAsync.error!, transportersAsync.stackTrace!);
  if (paymentsAsync.hasError) return AsyncValue.error(paymentsAsync.error!, paymentsAsync.stackTrace!);
  
  final transporters = transportersAsync.value!.docs.map((doc) => Transporter.fromFirestore(doc)).toList();
  final payments = paymentsAsync.value!.docs.map((doc) => TransportPayment.fromFirestore(doc)).toList();
  
  final map = <String, TransporterWithBalance>{};
  for (var t in transporters) {
    map[t.id] = TransporterWithBalance(transporter: t, totalAmount: 0);
  }
  
  for (var p in payments) {
    if (map.containsKey(p.transporterId)) {
      final current = map[p.transporterId]!;
      map[p.transporterId] = TransporterWithBalance(
        transporter: current.transporter,
        totalAmount: current.totalAmount + p.amount,
      );
    }
  }
  
  return AsyncValue.data(map.values.toList());
});

final transportLogsProvider = StreamProvider.family<List<TransportPayment>, String>((ref, transporterId) {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'dummy_uid';
  final query = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('transport_payments')
      .where('transporterId', isEqualTo: transporterId);
      
  return query.snapshots().map((snapshot) {
    final logs = snapshot.docs.map((doc) => TransportPayment.fromFirestore(doc)).toList();
    // Sort in memory (descending by date)
    logs.sort((a, b) => b.date.compareTo(a.date));
    return logs;
  });
});

final transportControllerProvider = NotifierProvider<TransportNotifier, AsyncValue<void>>(TransportNotifier.new);