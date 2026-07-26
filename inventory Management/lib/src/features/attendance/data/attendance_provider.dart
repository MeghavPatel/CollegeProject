import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/models.dart';

class AttendanceRecord {
  final String status;
  final String? checkIn;
  final String? checkOut;

  AttendanceRecord({required this.status, this.checkIn, this.checkOut});

  factory AttendanceRecord.fromFirestore(EmployeeAttendanceData data) {
    return AttendanceRecord(
      status: data.status,
      checkIn: data.checkIn,
      checkOut: data.checkOut,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'checkIn': checkIn,
      'checkOut': checkOut,
    };
  }
}

// Provider to get the list of employees
final employeeListProvider = StreamProvider<List<EmployeeProfile>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'dummy_uid';
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('employees')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => EmployeeProfile.fromFirestore(doc)).toList());
});

// Notifier for attendance state
class AttendanceNotifier extends Notifier<AsyncValue<Map<String, AttendanceRecord>>> {
  @override
  AsyncValue<Map<String, AttendanceRecord>> build() {
    return const AsyncLoading();
  }

  Future<void> loadAttendance(DateTime date) async {
    state = const AsyncLoading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
      
      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('attendance')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();
          
      final attendanceMap = <String, AttendanceRecord>{};
      for (var doc in attendanceSnapshot.docs) {
        final data = EmployeeAttendanceData.fromFirestore(doc);
        attendanceMap[data.employeeId] = AttendanceRecord.fromFirestore(data);
      }
      
      final employeesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('employees')
          .get();

      // Ensure all employees have an entry, default to 'Weekly Off' on Sundays, else 'Absent'
      final defaultStatus = (date.weekday == DateTime.sunday) ? 'Weekly Off' : 'Absent';
      for (var doc in employeesSnapshot.docs) {
        final employeeId = doc.id;
        if (!attendanceMap.containsKey(employeeId)) {
          attendanceMap[employeeId] = AttendanceRecord(
            status: defaultStatus,
            checkIn: defaultStatus == 'Absent' || defaultStatus == 'Weekly Off' ? null : '09:00',
            checkOut: defaultStatus == 'Absent' || defaultStatus == 'Weekly Off' ? null : '18:00',
          );
        }
      }
      state = AsyncData(attendanceMap);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  Future<void> saveAttendance(DateTime date, Map<String, AttendanceRecord> attendanceStatus) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
      
      final batch = FirebaseFirestore.instance.batch();
      
      // Delete old attendance for this day
      final oldAttendance = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('attendance')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();
          
      for (var doc in oldAttendance.docs) {
        batch.delete(doc.reference);
      }
      
      // Insert new attendance
      for (var entry in attendanceStatus.entries) {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('attendance')
            .doc();
        batch.set(docRef, {
          'employeeId': entry.key,
          'date': Timestamp.fromDate(startOfDay),
          'status': entry.value.status,
          'checkIn': entry.value.checkIn,
          'checkOut': entry.value.checkOut,
        });
      }
      
      await batch.commit();
      
      state = AsyncData(attendanceStatus);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }
}

// Provider for the attendance notifier
final attendanceProvider = NotifierProvider<AttendanceNotifier, AsyncValue<Map<String, AttendanceRecord>>>(AttendanceNotifier.new);