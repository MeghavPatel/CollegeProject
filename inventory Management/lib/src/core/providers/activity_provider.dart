import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';

class LastSeenActivityNotifier extends Notifier<DateTime?> {
  static const _key = 'last_seen_activity_time';

  @override
  DateTime? build() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _loadLastSeen(uid);
    }
    return null;
  }

  Future<void> _loadLastSeen(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt('${_key}_$uid');
      if (ms != null) {
        state = DateTime.fromMillisecondsSinceEpoch(ms);
      }
    } catch (_) {}
  }

  Future<void> markAsSeen() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final now = DateTime.now();
    state = now;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('${_key}_$uid', now.millisecondsSinceEpoch);
    } catch (_) {}
  }
}

final lastSeenActivityProvider = NotifierProvider<LastSeenActivityNotifier, DateTime?>(LastSeenActivityNotifier.new);


// 1. Icon ke liye Latest Activity (Red Dot Logic)
final latestActivityProvider = StreamProvider<ActivityLog?>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'dummy_uid';
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('activity_logs')
      .orderBy('timestamp', descending: true)
      .limit(1)
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) return null;
    return ActivityLog.fromFirestore(snapshot.docs.first);
  });
});

// 2. List ke liye History (Max 100 Items display karega)
final activityLogsProvider = StreamProvider<List<ActivityLog>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'dummy_uid';
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('activity_logs')
      .orderBy('timestamp', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => ActivityLog.fromFirestore(doc)).toList();
  });
});

// 3. Logic Class (Insert & Delete)
class ActivityNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  // Activity Save karna + Purana data clean karna
  Future<void> logActivity(String module, String description) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return; // Silent discard if not logged in
      
      final collection = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('activity_logs');
      
      // Step 1: Insert New Log
      await collection.add({
        'moduleName': module,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Step 2: Check total count (Auto-clean logic)
      final allLogsSnapshot = await collection
          .orderBy('timestamp', descending: true)
          .get();
      
      // Step 3: Agar 100 se zyada hain, toh purane delete kar do
      if (allLogsSnapshot.docs.length > 100) {
        final logsToDelete = allLogsSnapshot.docs.skip(100).toList();
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in logsToDelete) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
      
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e.toString(), stack);
    }
  }

  // Delete Single Activity (Trash Icon ke liye)
  Future<void> deleteActivity(String id) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('activity_logs')
          .doc(id)
          .delete();
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e.toString(), stack);
    }
  }

  // Delete All Activities (Clear All History)
  Future<void> deleteAllActivities() async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");
      
      final collection = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('activity_logs');
          
      final snapshot = await collection.get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e.toString(), stack);
    }
  }
}

// 4. Main Provider Connect
final activityProvider = NotifierProvider<ActivityNotifier, AsyncValue<void>>(ActivityNotifier.new);