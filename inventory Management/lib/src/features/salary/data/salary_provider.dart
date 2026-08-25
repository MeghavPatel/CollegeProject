import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/activity_provider.dart';
import '../../../core/services/encryption_service.dart';

enum DateFilter { allTime, thisMonth, lastYear, custom }

class DateRange {
  final DateTime? start;
  final DateTime? end;
  final DateFilter filter;

  DateRange({this.start, this.end, required this.filter});
}

// Employee CRUD Provider
class EmployeeNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> addEmployee(String name, String? role, double salary, String phoneNumber) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");

      final encryptedData = EncryptionService.instance.encryptMap({
        'name': name,
        'role': role,
        'salary': salary,
        'phoneNumber': phoneNumber,
        'joinedDate': FieldValue.serverTimestamp(),
        'advanceTaken': 0.0,
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('employees')
          .add(encryptedData);

      ref.read(activityProvider.notifier).logActivity(
        'Salary', 'Added employee: $name',
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteEmployee(String id, String name) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('employees')
          .doc(id)
          .delete();
      ref.read(activityProvider.notifier).logActivity(
        'Salary', 'Deleted employee: $name',
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateEmployee(String id, String name, String? role, double salary, String phoneNumber) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('employees')
          .doc(id);

      final snap = await docRef.get();
      final currentData = EncryptionService.instance.decryptDoc(snap.data());
      currentData['name'] = name;
      currentData['role'] = role;
      currentData['salary'] = salary;
      currentData['phoneNumber'] = phoneNumber;

      final encryptedData = EncryptionService.instance.encryptMap(currentData);
      await docRef.set(encryptedData, SetOptions(merge: true));

      ref.read(activityProvider.notifier).logActivity(
        'Salary', 'Updated employee details: $name ($role, ₹${salary.toStringAsFixed(0)})',
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

// Payment CRUD Provider
class PaymentNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> addPayment(String employeeId, String employeeName, double amount, String? note, {String type = 'Salary', double? overtimeBonus}) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final empRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('employees')
            .doc(employeeId);
            
        final paymentRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('salary_payments')
            .doc();
            
        final empSnapshot = await transaction.get(empRef);
        final empData = EncryptionService.instance.decryptDoc(empSnapshot.data());

        if (type == 'Advance') {
          final currentAdvance = (empData['advanceTaken'] ?? 0.0).toDouble();
          empData['advanceTaken'] = currentAdvance + amount;
          transaction.set(empRef, EncryptionService.instance.encryptMap(empData), SetOptions(merge: true));
        } else if (type == 'Salary') {
          empData['advanceTaken'] = 0.0;
          transaction.set(empRef, EncryptionService.instance.encryptMap(empData), SetOptions(merge: true));
        }
        
        final paymentData = EncryptionService.instance.encryptMap({
          'employeeId': employeeId,
          'amount': amount,
          'note': note,
          'paymentDate': FieldValue.serverTimestamp(),
          'type': type,
          'overtimeBonus': overtimeBonus ?? 0.0,
        });

        transaction.set(paymentRef, paymentData);
      });

      final actionStr = type == 'Advance' ? 'Advance early payment' : 'Monthly Salary payout';
      ref.read(activityProvider.notifier).logActivity(
        'Salary', '$actionStr of ₹${amount.toStringAsFixed(0)} to $employeeName',
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deletePayment(String id, String employeeId, String employeeName, double amount, String type) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final empRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('employees')
            .doc(employeeId);
            
        final paymentRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('salary_payments')
            .doc(id);
            
        if (type == 'Advance') {
          final empSnapshot = await transaction.get(empRef);
          if (empSnapshot.exists) {
            final empData = EncryptionService.instance.decryptDoc(empSnapshot.data());
            final currentAdvance = (empData['advanceTaken'] ?? 0.0).toDouble();
            empData['advanceTaken'] = (currentAdvance - amount).clamp(0.0, double.infinity);
            transaction.set(empRef, EncryptionService.instance.encryptMap(empData), SetOptions(merge: true));
          }
        }
        
        transaction.delete(paymentRef);
      });

      ref.read(activityProvider.notifier).logActivity(
        'Salary', 'Deleted payment/advance ₹${amount.toStringAsFixed(0)} for $employeeName',
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updatePayment({
    required String id,
    required String employeeId,
    required String employeeName,
    required double oldAmount,
    required double newAmount,
    required String type,
    required String? note,
    required DateTime date,
  }) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final empRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('employees')
            .doc(employeeId);
            
        final paymentRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('salary_payments')
            .doc(id);
            
        if (type == 'Advance') {
          final empSnapshot = await transaction.get(empRef);
          if (empSnapshot.exists) {
            final empData = EncryptionService.instance.decryptDoc(empSnapshot.data());
            final currentAdvance = (empData['advanceTaken'] ?? 0.0).toDouble();
            // Revert old advance and apply new advance
            empData['advanceTaken'] = (currentAdvance - oldAmount + newAmount).clamp(0.0, double.infinity);
            transaction.set(empRef, EncryptionService.instance.encryptMap(empData), SetOptions(merge: true));
          }
        }
        
        final paymentData = EncryptionService.instance.encryptMap({
          'employeeId': employeeId,
          'amount': newAmount,
          'note': note,
          'paymentDate': Timestamp.fromDate(date),
          'type': type,
        });

        transaction.set(paymentRef, paymentData, SetOptions(merge: true));
      });

      ref.read(activityProvider.notifier).logActivity(
        'Salary', 'Updated payment/advance for $employeeName (₹$oldAmount -> ₹$newAmount)',
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

// Date Range State Provider
class DateRangeNotifier extends Notifier<DateRange> {
  @override
  DateRange build() => DateRange(filter: DateFilter.allTime);
  
  void updateFilter(DateFilter filter, {DateTime? start, DateTime? end}) {
    state = DateRange(filter: filter, start: start, end: end);
  }
}

final dateRangeProvider = NotifierProvider<DateRangeNotifier, DateRange>(DateRangeNotifier.new);

// Employees List Provider
final employeesProvider = StreamProvider<List<EmployeeProfile>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'dummy_uid';
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('employees')
      .snapshots()
      .map((snapshot) {
        final list = snapshot.docs.map((doc) => EmployeeProfile.fromFirestore(doc)).toList();
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      });
});

// Employee Payments Provider (with date filtering)
final employeePaymentsProvider = StreamProvider.family<List<SalaryPayment>, String>((ref, employeeId) {
  final dateRange = ref.watch(dateRangeProvider);
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'dummy_uid';
  
  final query = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('salary_payments')
      .where('employeeId', isEqualTo: employeeId);

  return query.snapshots().map((snapshot) {
    var payments = snapshot.docs.map((doc) => SalaryPayment.fromFirestore(doc)).toList();

    // Apply date filter in memory
    if (dateRange.filter != DateFilter.allTime) {
      DateTime? start, end;
      final now = DateTime.now();
      
      switch (dateRange.filter) {
        case DateFilter.thisMonth:
          start = DateTime(now.year, now.month, 1);
          end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          break;
        case DateFilter.lastYear:
          start = DateTime(now.year - 1, now.month, now.day);
          end = now;
          break;
        case DateFilter.custom:
          start = dateRange.start;
          end = dateRange.end;
          break;
        case DateFilter.allTime:
          break;
      }
      
      if (start != null && end != null) {
        payments = payments.where((p) {
          return p.paymentDate.isAfter(start!) && p.paymentDate.isBefore(end!);
        }).toList();
      }
    }

    // Sort in memory (descending by paymentDate)
    payments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    return payments;
  });
});

// Total Paid Amount Provider (with date filtering)
final totalPaidProvider = StreamProvider.family<double, String>((ref, employeeId) {
  final paymentsAsync = ref.watch(employeePaymentsProvider(employeeId));
  return paymentsAsync.when(
    data: (payments) => Stream.value(
      payments.fold(0.0, (acc, payment) => acc + payment.amount)
    ),
    loading: () => Stream.value(0.0),
    error: (e, stack) => Stream.value(0.0),
  );
});

// Providers
final employeeProvider = NotifierProvider<EmployeeNotifier, AsyncValue<void>>(EmployeeNotifier.new);
final paymentProvider = NotifierProvider<PaymentNotifier, AsyncValue<void>>(PaymentNotifier.new);