import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/activity_provider.dart';
import '../../../core/services/encryption_service.dart';

// Scope Stock operations under user UID
class StockNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> addStockItem(String name) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");

      final encryptedData = EncryptionService.instance.encryptMap({
        'itemName': name,
        'currentQuantity': 0.0,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('stock_items')
          .add(encryptedData);

      ref.read(activityProvider.notifier).logActivity(
        'Stock', 'Created parent item: $name',
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateStockItem(String id, String newName) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('stock_items')
          .doc(id);

      final snap = await docRef.get();
      final currentData = EncryptionService.instance.decryptDoc(snap.data());
      currentData['itemName'] = newName;
      currentData['lastUpdated'] = FieldValue.serverTimestamp();

      final encryptedData = EncryptionService.instance.encryptMap(currentData);
      await docRef.set(encryptedData, SetOptions(merge: true));

      ref.read(activityProvider.notifier).logActivity(
        'Stock', 'Updated parent stock item name to: $newName',
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addStockVariant(
    String itemId, 
    String itemName, {
    double? thickness,
    double? length,
    double? width,
    double initialStock = 0.0,
  }) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");
      
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('stock_items')
          .doc(itemId);

      final variantRef = docRef.collection('variants').doc();
      final logRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('stock_logs')
          .doc();

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final parentSnapshot = await transaction.get(docRef);
        final parentData = EncryptionService.instance.decryptDoc(parentSnapshot.data());
        final currentParentQty = (parentData['currentQuantity'] ?? 0.0).toDouble();

        final variantData = EncryptionService.instance.encryptMap({
          'thickness': thickness,
          'length': length,
          'width': width,
          'currentStock': initialStock,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        parentData['currentQuantity'] = currentParentQty + initialStock;
        parentData['lastUpdated'] = FieldValue.serverTimestamp();
        final updatedParent = EncryptionService.instance.encryptMap(parentData);

        transaction.set(variantRef, variantData);
        transaction.set(docRef, updatedParent, SetOptions(merge: true));

        if (initialStock > 0) {
          final logData = EncryptionService.instance.encryptMap({
            'itemId': itemId,
            'variantId': variantRef.id,
            'type': 'ADD',
            'quantityChange': initialStock,
            'date': FieldValue.serverTimestamp(),
          });
          transaction.set(logRef, logData);
        }
      });

      final varStr = thickness != null ? '${thickness.toString().replaceAll(RegExp(r'\.0$'), '')} mm' : (length != null && width != null ? '${length.toString().replaceAll(RegExp(r'\.0$'), '')} x ${width.toString().replaceAll(RegExp(r'\.0$'), '')}' : 'Variant');
      ref.read(activityProvider.notifier).logActivity(
        'Stock', 'Added variant ($varStr) to $itemName with Qty: $initialStock',
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateVariantStock(
    String itemId, 
    String variantId, 
    String itemName, 
    String variantName, 
    String type, 
    double quantityChange,
    String? note,
  ) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");

      final parentRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('stock_items')
          .doc(itemId);

      final variantRef = parentRef.collection('variants').doc(variantId);
      final logRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('stock_logs')
          .doc();

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final parentSnapshot = await transaction.get(parentRef);
        final variantSnapshot = await transaction.get(variantRef);

        if (!parentSnapshot.exists || !variantSnapshot.exists) {
          throw Exception("Stock item or variant does not exist!");
        }

        final parentData = EncryptionService.instance.decryptDoc(parentSnapshot.data());
        final variantData = EncryptionService.instance.decryptDoc(variantSnapshot.data());

        final currentParentQty = (parentData['currentQuantity'] ?? 0.0).toDouble();
        final currentVarStock = (variantData['currentStock'] ?? 0.0).toDouble();

        double newVarStock = currentVarStock;
        double newParentQty = currentParentQty;

        if (type == 'ADD') {
          newVarStock += quantityChange;
          newParentQty += quantityChange;
        } else if (type == 'SELL') {
          newVarStock -= quantityChange;
          newParentQty -= quantityChange;
        }

        variantData['currentStock'] = newVarStock;
        variantData['lastUpdated'] = FieldValue.serverTimestamp();

        parentData['currentQuantity'] = newParentQty;
        parentData['lastUpdated'] = FieldValue.serverTimestamp();

        transaction.set(variantRef, EncryptionService.instance.encryptMap(variantData), SetOptions(merge: true));
        transaction.set(parentRef, EncryptionService.instance.encryptMap(parentData), SetOptions(merge: true));

        final logData = EncryptionService.instance.encryptMap({
          'itemId': itemId,
          'variantId': variantId,
          'type': type,
          'quantityChange': quantityChange,
          'date': FieldValue.serverTimestamp(),
          'note': note,
        });

        transaction.set(logRef, logData);
      });

      final action = type == 'ADD' ? 'Added' : 'Sold';
      final noteStr = note != null && note.isNotEmpty ? ' (Note: $note)' : '';
      ref.read(activityProvider.notifier).logActivity(
        'Stock', '$action ${quantityChange.toStringAsFixed(0)} units for $itemName ($variantName)$noteStr',
      );

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteStockVariant(
    String itemId, 
    String variantId, 
    String itemName, 
    String variantName, 
    double currentStock,
  ) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");

      final parentRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('stock_items')
          .doc(itemId);

      final variantRef = parentRef.collection('variants').doc(variantId);
      
      // Get all logs for this variant
      final logsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('stock_logs')
          .where('itemId', isEqualTo: itemId)
          .where('variantId', isEqualTo: variantId)
          .get();

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final parentSnapshot = await transaction.get(parentRef);
        final parentData = EncryptionService.instance.decryptDoc(parentSnapshot.data());
        final currentParentQty = (parentData['currentQuantity'] ?? 0.0).toDouble();

        transaction.delete(variantRef);

        parentData['currentQuantity'] = (currentParentQty - currentStock).clamp(0.0, double.infinity);
        parentData['lastUpdated'] = FieldValue.serverTimestamp();

        transaction.set(parentRef, EncryptionService.instance.encryptMap(parentData), SetOptions(merge: true));

        for (var doc in logsSnapshot.docs) {
          transaction.delete(doc.reference);
        }
      });

      ref.read(activityProvider.notifier).logActivity(
        'Stock', 'Deleted variant $variantName of $itemName',
      );

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteStockItem(String itemId, String itemName) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");
      
      // Delete all logs for this item
      final logsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('stock_logs')
          .where('itemId', isEqualTo: itemId)
          .get();
          
      // Delete all variants for this item
      final variantsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('stock_items')
          .doc(itemId)
          .collection('variants')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in logsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      for (var doc in variantsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('stock_items')
          .doc(itemId));
      
      await batch.commit();
      
      ref.read(activityProvider.notifier).logActivity(
        'Stock', 'Deleted item: $itemName',
      );
      
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteStockLog(String itemId, String variantId, String logId, String itemName, String variantName, double quantityChange, String type) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");

      final parentRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('stock_items')
          .doc(itemId);

      final variantRef = parentRef.collection('variants').doc(variantId);
      final logRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('stock_logs')
          .doc(logId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final parentSnapshot = await transaction.get(parentRef);
        final variantSnapshot = await transaction.get(variantRef);

        if (!parentSnapshot.exists || !variantSnapshot.exists) {
          throw Exception("Stock item or variant does not exist!");
        }

        final parentData = EncryptionService.instance.decryptDoc(parentSnapshot.data());
        final variantData = EncryptionService.instance.decryptDoc(variantSnapshot.data());

        final currentParentQty = (parentData['currentQuantity'] ?? 0.0).toDouble();
        final currentVarStock = (variantData['currentStock'] ?? 0.0).toDouble();

        double newVarStock = currentVarStock;
        double newParentQty = currentParentQty;

        // Revert the action
        if (type == 'ADD') {
          newVarStock -= quantityChange;
          newParentQty -= quantityChange;
        } else if (type == 'SELL') {
          newVarStock += quantityChange;
          newParentQty += quantityChange;
        }

        variantData['currentStock'] = newVarStock.clamp(0.0, double.infinity);
        variantData['lastUpdated'] = FieldValue.serverTimestamp();

        parentData['currentQuantity'] = newParentQty.clamp(0.0, double.infinity);
        parentData['lastUpdated'] = FieldValue.serverTimestamp();

        transaction.set(variantRef, EncryptionService.instance.encryptMap(variantData), SetOptions(merge: true));
        transaction.set(parentRef, EncryptionService.instance.encryptMap(parentData), SetOptions(merge: true));

        transaction.delete(logRef);
      });

      ref.read(activityProvider.notifier).logActivity(
        'Stock', 'Deleted transaction log for $itemName ($variantName)',
      );

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateStockLog({
    required String itemId,
    required String variantId,
    required String logId,
    required String itemName,
    required String variantName,
    required double oldQuantity,
    required double newQuantity,
    required String oldType,
    required String newType,
    required String? note,
    required DateTime date,
  }) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");

      final parentRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('stock_items')
          .doc(itemId);

      final variantRef = parentRef.collection('variants').doc(variantId);
      final logRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('stock_logs')
          .doc(logId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final parentSnapshot = await transaction.get(parentRef);
        final variantSnapshot = await transaction.get(variantRef);

        if (!parentSnapshot.exists || !variantSnapshot.exists) {
          throw Exception("Stock item or variant does not exist!");
        }

        final parentData = EncryptionService.instance.decryptDoc(parentSnapshot.data());
        final variantData = EncryptionService.instance.decryptDoc(variantSnapshot.data());

        final currentParentQty = (parentData['currentQuantity'] ?? 0.0).toDouble();
        final currentVarStock = (variantData['currentStock'] ?? 0.0).toDouble();

        double newVarStock = currentVarStock;
        double newParentQty = currentParentQty;

        // 1. Revert old change
        if (oldType == 'ADD') {
          newVarStock -= oldQuantity;
          newParentQty -= oldQuantity;
        } else if (oldType == 'SELL') {
          newVarStock += oldQuantity;
          newParentQty += oldQuantity;
        }

        // 2. Apply new change
        if (newType == 'ADD') {
          newVarStock += newQuantity;
          newParentQty += newQuantity;
        } else if (newType == 'SELL') {
          newVarStock -= newQuantity;
          newParentQty -= newQuantity;
        }

        variantData['currentStock'] = newVarStock.clamp(0.0, double.infinity);
        variantData['lastUpdated'] = FieldValue.serverTimestamp();

        parentData['currentQuantity'] = newParentQty.clamp(0.0, double.infinity);
        parentData['lastUpdated'] = FieldValue.serverTimestamp();

        transaction.set(variantRef, EncryptionService.instance.encryptMap(variantData), SetOptions(merge: true));
        transaction.set(parentRef, EncryptionService.instance.encryptMap(parentData), SetOptions(merge: true));

        final logData = EncryptionService.instance.encryptMap({
          'itemId': itemId,
          'variantId': variantId,
          'type': newType,
          'quantityChange': newQuantity,
          'note': note,
          'date': Timestamp.fromDate(date),
        });

        transaction.set(logRef, logData, SetOptions(merge: true));
      });

      ref.read(activityProvider.notifier).logActivity(
        'Stock', 'Updated transaction log for $itemName ($variantName): $oldType $oldQuantity -> $newType $newQuantity',
      );

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateStockVariant(
    String itemId,
    String variantId,
    String itemName,
    String oldVariantName, {
    double? thickness,
    double? length,
    double? width,
  }) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");
      
      final variantRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('stock_items')
          .doc(itemId)
          .collection('variants')
          .doc(variantId);

      final snap = await variantRef.get();
      final varData = EncryptionService.instance.decryptDoc(snap.data());
      varData['thickness'] = thickness;
      varData['length'] = length;
      varData['width'] = width;
      varData['lastUpdated'] = FieldValue.serverTimestamp();

      await variantRef.set(EncryptionService.instance.encryptMap(varData), SetOptions(merge: true));
      
      final parts = <String>[];
      if (length != null && width != null) {
        parts.add('${length.toString().replaceAll(RegExp(r'\.0$'), '')} x ${width.toString().replaceAll(RegExp(r'\.0$'), '')}');
      }
      if (thickness != null) {
        parts.add('${thickness.toString().replaceAll(RegExp(r'\.0$'), '')} mm');
      }
      final newVarName = parts.isNotEmpty ? parts.join(' - ') : 'Default Size';

      ref.read(activityProvider.notifier).logActivity(
        'Stock', 'Updated variant details of $itemName ($oldVariantName -> $newVarName)',
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> clearVariantHistory(
    String itemId,
    String variantId,
    String itemName,
    String variantName,
  ) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");

      final logsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('stock_logs')
          .where('itemId', isEqualTo: itemId)
          .where('variantId', isEqualTo: variantId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in logsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      ref.read(activityProvider.notifier).logActivity(
        'Stock', 'Cleared all transaction history for $itemName ($variantName)',
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

// Stock Items Provider
final stockItemsProvider = StreamProvider<List<StockItem>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'dummy_uid';
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('stock_items')
      .snapshots()
      .map((snapshot) {
        final list = snapshot.docs.map((doc) => StockItem.fromFirestore(doc)).toList();
        list.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
        return list;
      });
});

// Stock Variants Provider
final stockVariantsProvider = StreamProvider.family<List<StockVariant>, String>((ref, itemId) {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'dummy_uid';
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('stock_items')
      .doc(itemId)
      .collection('variants')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => StockVariant.fromFirestore(doc)).toList());
});

// Stock Logs Provider for specific item and variant
final stockLogsProvider = StreamProvider.family<List<StockLog>, String>((ref, ids) {
  // ids will be in the format: "itemId_variantId"
  final parts = ids.split('_');
  final itemId = parts[0];
  final variantId = parts.length > 1 ? parts[1] : '';
  
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'dummy_uid';
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('stock_logs')
      .where('itemId', isEqualTo: itemId)
      .snapshots()
      .map((snapshot) {
        final list = snapshot.docs.map((doc) => StockLog.fromFirestore(doc)).toList();
        final filtered = list.where((log) => log.variantId == variantId).toList();
        filtered.sort((a, b) => b.date.compareTo(a.date));
        return filtered;
      });
});

// Main Provider
final stockProvider = NotifierProvider<StockNotifier, AsyncValue<void>>(StockNotifier.new);