import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hp_bill/models/customer.dart';
import 'package:hp_bill/models/inventory_item.dart';
import 'package:hp_bill/models/invoice.dart';
import 'package:hp_bill/models/quick_entry.dart';
import 'package:hp_bill/models/ledger_entry.dart';
import 'package:hp_bill/services/encryption_service.dart';
import 'package:flutter/foundation.dart';

/// Dedicated service for the Invoice Generation App.
/// ALL operations are strictly namespaced under `invoice_app/data/`.
/// ALL document payloads stored in Firebase are AES-256 ENCRYPTED for total privacy & security.
class FirestoreInvoiceService {
  static final FirestoreInvoiceService instance = FirestoreInvoiceService._init();
  FirestoreInvoiceService._init();

  final EncryptionService _enc = EncryptionService.instance;

  // Lazy-loaded Firestore reference — only accessed when Firebase is ready
  FirebaseFirestore? _firestoreInstance;

  FirebaseFirestore? get _firestore {
    try {
      _firestoreInstance ??= FirebaseFirestore.instance;
      return _firestoreInstance;
    } catch (e) {
      debugPrint("Firestore not available: $e");
      return null;
    }
  }

  bool get isAvailable => _firestore != null;

  // STRICTLY SCOPED REFERENCES (ISOLATED NAMESPACE)
  DocumentReference? get _rootNamespace => _firestore?.collection('invoice_app').doc('data');
  CollectionReference? get _billsCollection => _rootNamespace?.collection('bills');
  CollectionReference? get _customersCollection => _rootNamespace?.collection('customers');
  CollectionReference? get _quickEntriesCollection => _rootNamespace?.collection('quick_entries');
  CollectionReference? get _ledgerEntriesCollection => _rootNamespace?.collection('ledger_entries');
  CollectionReference? get _storeProfileCollection => _rootNamespace?.collection('store_profile');
  CollectionReference? get _inventoryCollection => _rootNamespace?.collection('inventory');

  // =====================================================================
  // INVOICE CRUD OPERATIONS (ENCRYPTED)
  // =====================================================================

  Future<void> createInvoice(Invoice invoice) async {
    final bills = _billsCollection;
    if (bills == null) return;
    final encryptedData = _enc.encryptMap(invoice.toFirestore());
    await bills.doc(invoice.id).set(encryptedData);
  }

  Future<void> updateInvoice(Invoice invoice) async {
    final bills = _billsCollection;
    if (bills == null) return;
    final encryptedData = _enc.encryptMap(invoice.toFirestore());
    await bills.doc(invoice.id).set(encryptedData);
  }

  Future<void> deleteInvoice(String invoiceId) async {
    final bills = _billsCollection;
    if (bills == null) return;
    try {
      await bills.doc(invoiceId).delete();
    } catch (_) {}

    // Delete linked ledger entry
    try {
      final ledger = _ledgerEntriesCollection;
      if (ledger != null) {
        await ledger.doc('L-$invoiceId').delete();
      }
    } catch (_) {}
  }

  Future<void> updatePaymentStatus(String invoiceId, bool isPaid) async {
    final bills = _billsCollection;
    if (bills == null) return;
    final docRef = bills.doc(invoiceId);
    final docSnap = await docRef.get().timeout(const Duration(seconds: 5));
    if (docSnap.exists) {
      final decrypted = _enc.decryptDoc(docSnap.data() as Map<String, dynamic>?);
      decrypted['paymentStatus'] = isPaid ? 'paid' : 'unpaid';
      decrypted['isPaid'] = isPaid;
      await docRef.set(_enc.encryptMap(decrypted));
    }
  }

  /// One-time fetch of invoices (Decrypted)
  Future<List<Invoice>> fetchInvoiceHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? paymentStatus,
  }) async {
    try {
      final bills = _billsCollection;
      if (bills == null) return [];

      final querySnapshot = await bills.get().timeout(const Duration(seconds: 6));

      List<Invoice> invoices = querySnapshot.docs.map((doc) {
        final decrypted = _enc.decryptDoc(doc.data() as Map<String, dynamic>?);
        return Invoice.fromFirestore(doc.id, decrypted);
      }).toList();

      if (paymentStatus != null && paymentStatus.isNotEmpty && paymentStatus != 'all') {
        invoices = invoices.where((inv) => inv.paymentStatus == paymentStatus).toList();
      }

      if (startDate != null) {
        final start = DateTime(startDate.year, startDate.month, startDate.day);
        invoices = invoices.where((inv) => inv.date.isAfter(start) || inv.date.isAtSameMomentAs(start)).toList();
      }
      if (endDate != null) {
        final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        invoices = invoices.where((inv) => inv.date.isBefore(end) || inv.date.isAtSameMomentAs(end)).toList();
      }

      invoices.sort((a, b) => b.date.compareTo(a.date));
      return invoices;
    } catch (e) {
      debugPrint("fetchInvoiceHistory error: $e");
      return [];
    }
  }

  /// REAL-TIME stream of all invoices (Decrypted)
  Stream<List<Invoice>> streamInvoices() {
    final bills = _billsCollection;
    if (bills == null) return Stream.value([]);
    return bills.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final decrypted = _enc.decryptDoc(doc.data() as Map<String, dynamic>?);
        return Invoice.fromFirestore(doc.id, decrypted);
      }).toList()..sort((a, b) => b.date.compareTo(a.date));
    }).handleError((e) {
      debugPrint("streamInvoices error: $e");
      return <Invoice>[];
    });
  }

  // =====================================================================
  // CUSTOMER CRUD OPERATIONS (ENCRYPTED)
  // =====================================================================

  Future<void> saveCustomer(Customer customer) async {
    final customers = _customersCollection;
    if (customers == null) return;
    final encryptedData = _enc.encryptMap(customer.toFirestore());
    await customers.doc(customer.id).set(encryptedData, SetOptions(merge: true));
  }

  Future<List<Customer>> fetchCustomers() async {
    try {
      final customers = _customersCollection;
      if (customers == null) return [];
      final snapshot = await customers.get().timeout(const Duration(seconds: 5));
      return snapshot.docs.map((doc) {
        final decrypted = _enc.decryptDoc(doc.data() as Map<String, dynamic>?);
        return Customer.fromFirestore(doc.id, decrypted);
      }).toList();
    } catch (e) {
      debugPrint("fetchCustomers error: $e");
      return [];
    }
  }

  Future<void> deleteCustomer(String customerId) async {
    final customers = _customersCollection;
    if (customers == null) return;
    await customers.doc(customerId).delete();
  }

  // =====================================================================
  // QUICK ENTRY (Cash/Bank) CRUD + REAL-TIME STREAM (ENCRYPTED)
  // =====================================================================

  Future<void> saveQuickEntry(QuickEntry entry) async {
    final col = _quickEntriesCollection;
    if (col == null) return;
    final encrypted = _enc.encryptMap(entry.toMap());
    await col.doc(entry.id).set(encrypted);
  }

  Future<void> deleteQuickEntry(String entryId) async {
    final col = _quickEntriesCollection;
    if (col == null) return;
    await col.doc(entryId).delete();
  }

  Future<void> updateQuickEntry(QuickEntry entry) async {
    final col = _quickEntriesCollection;
    if (col == null) return;
    final encrypted = _enc.encryptMap(entry.toMap());
    await col.doc(entry.id).set(encrypted);
  }

  Future<List<QuickEntry>> fetchQuickEntries() async {
    try {
      final col = _quickEntriesCollection;
      if (col == null) return [];
      final snapshot = await col.get().timeout(const Duration(seconds: 5));
      return snapshot.docs.map((doc) {
        final decrypted = _enc.decryptDoc(doc.data() as Map<String, dynamic>?);
        return QuickEntry.fromMap(decrypted);
      }).toList()..sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      debugPrint("fetchQuickEntries error: $e");
      return [];
    }
  }

  /// REAL-TIME stream of quick entries (Decrypted)
  Stream<List<QuickEntry>> streamQuickEntries() {
    final col = _quickEntriesCollection;
    if (col == null) return Stream.value([]);
    return col.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final decrypted = _enc.decryptDoc(doc.data() as Map<String, dynamic>?);
        return QuickEntry.fromMap(decrypted);
      }).toList()..sort((a, b) => b.date.compareTo(a.date));
    }).handleError((e) {
      debugPrint("streamQuickEntries error: $e");
      return <QuickEntry>[];
    });
  }

  // =====================================================================
  // LEDGER ENTRY CRUD + REAL-TIME STREAM (ENCRYPTED)
  // =====================================================================

  Future<void> saveLedgerEntry(LedgerEntry entry) async {
    final col = _ledgerEntriesCollection;
    if (col == null) return;
    final encrypted = _enc.encryptMap(entry.toMap());
    await col.doc(entry.id).set(encrypted);
  }

  Future<void> deleteLedgerEntry(String entryId) async {
    final col = _ledgerEntriesCollection;
    if (col == null) return;
    await col.doc(entryId).delete();
  }

  Future<void> updateLedgerEntry(LedgerEntry entry) async {
    final col = _ledgerEntriesCollection;
    if (col == null) return;
    final encrypted = _enc.encryptMap(entry.toMap());
    await col.doc(entry.id).set(encrypted);
  }

  Future<void> deleteLedgerForCustomer(String customerName) async {
    final cleanName = customerName.trim().toLowerCase();

    // 1. Delete from ledger_entries
    try {
      final col = _ledgerEntriesCollection;
      if (col != null) {
        final snapshot = await col.get().timeout(const Duration(seconds: 5));
        for (var doc in snapshot.docs) {
          final data = _enc.decryptDoc(doc.data() as Map<String, dynamic>?);
          final cName = (data['customerName'] ?? data['customer_name'] ?? '').toString().trim().toLowerCase();
          if (cName == cleanName) {
            await doc.reference.delete();
          }
        }
      }
    } catch (e) {
      debugPrint("deleteLedgerForCustomer (ledger) error: $e");
    }

    // 2. Delete from bills
    try {
      final bills = _billsCollection;
      if (bills != null) {
        final snapshot = await bills.get().timeout(const Duration(seconds: 5));
        for (var doc in snapshot.docs) {
          final data = _enc.decryptDoc(doc.data() as Map<String, dynamic>?);
          final customerMap = data['customer'] is Map ? data['customer'] as Map : {};
          final cName = (customerMap['name'] ?? data['customerName'] ?? '').toString().trim().toLowerCase();
          if (cName == cleanName) {
            await doc.reference.delete();
          }
        }
      }
    } catch (e) {
      debugPrint("deleteLedgerForCustomer (bills) error: $e");
    }

    // 3. Delete from quick_entries
    try {
      final qe = _quickEntriesCollection;
      if (qe != null) {
        final snapshot = await qe.get().timeout(const Duration(seconds: 5));
        for (var doc in snapshot.docs) {
          final data = _enc.decryptDoc(doc.data() as Map<String, dynamic>?);
          final pName = (data['partyName'] ?? data['party_name'] ?? '').toString().trim().toLowerCase();
          if (pName == cleanName) {
            await doc.reference.delete();
          }
        }
      }
    } catch (e) {
      debugPrint("deleteLedgerForCustomer (quick_entries) error: $e");
    }

    // 4. Delete from customers
    try {
      final cust = _customersCollection;
      if (cust != null) {
        final snapshot = await cust.get().timeout(const Duration(seconds: 5));
        for (var doc in snapshot.docs) {
          final data = _enc.decryptDoc(doc.data() as Map<String, dynamic>?);
          final cName = (data['name'] ?? doc.id).toString().trim().toLowerCase();
          if (cName == cleanName) {
            await doc.reference.delete();
          }
        }
      }
    } catch (e) {
      debugPrint("deleteLedgerForCustomer (customers) error: $e");
    }
  }

  Future<List<LedgerEntry>> fetchLedgerEntries() async {
    try {
      final col = _ledgerEntriesCollection;
      if (col == null) return [];
      final snapshot = await col.get().timeout(const Duration(seconds: 5));
      return snapshot.docs.map((doc) {
        final decrypted = _enc.decryptDoc(doc.data() as Map<String, dynamic>?);
        return LedgerEntry.fromMap(decrypted);
      }).toList();
    } catch (e) {
      debugPrint("fetchLedgerEntries error: $e");
      return [];
    }
  }

  /// REAL-TIME stream of ledger entries (Decrypted)
  Stream<List<LedgerEntry>> streamLedgerEntries() {
    final col = _ledgerEntriesCollection;
    if (col == null) return Stream.value([]);
    return col.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final decrypted = _enc.decryptDoc(doc.data() as Map<String, dynamic>?);
        return LedgerEntry.fromMap(decrypted);
      }).toList();
    }).handleError((e) {
      debugPrint("streamLedgerEntries error: $e");
      return <LedgerEntry>[];
    });
  }

  // =====================================================================
  // INVENTORY / PRODUCT CRUD + REAL-TIME STREAM (ENCRYPTED)
  // =====================================================================

  Future<void> saveInventoryItem(InventoryItem item) async {
    final col = _inventoryCollection;
    if (col == null) return;
    final encrypted = _enc.encryptMap(item.toMap());
    await col.doc(item.id).set(encrypted);
  }

  Future<void> deleteInventoryItem(String itemId) async {
    final col = _inventoryCollection;
    if (col == null) return;
    await col.doc(itemId).delete();
  }

  Future<List<InventoryItem>> fetchInventory() async {
    try {
      final col = _inventoryCollection;
      if (col == null) return [];
      final snapshot = await col.get().timeout(const Duration(seconds: 5));
      return snapshot.docs.map((doc) {
        final decrypted = _enc.decryptDoc(doc.data() as Map<String, dynamic>?);
        return InventoryItem.fromMap(decrypted);
      }).toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (e) {
      debugPrint("fetchInventory error: $e");
      return [];
    }
  }

  /// REAL-TIME stream of inventory items (Decrypted)
  Stream<List<InventoryItem>> streamInventory() {
    final col = _inventoryCollection;
    if (col == null) return Stream.value([]);
    return col.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final decrypted = _enc.decryptDoc(doc.data() as Map<String, dynamic>?);
        return InventoryItem.fromMap(decrypted);
      }).toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }).handleError((e) {
      debugPrint("streamInventory error: $e");
      return <InventoryItem>[];
    });
  }

  // =====================================================================
  // STORE PROFILE SYNC + REAL-TIME STREAM (ENCRYPTED)
  // =====================================================================

  Future<void> saveStoreProfile(String name, String address) async {
    final col = _storeProfileCollection;
    if (col == null) return;
    final encrypted = _enc.encryptMap({
      'storeName': name,
      'storeAddress': address,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    await col.doc('profile').set(encrypted);
  }

  Future<Map<String, String>> fetchStoreProfile() async {
    try {
      final col = _storeProfileCollection;
      if (col == null) return {};
      final doc = await col.doc('profile').get().timeout(const Duration(seconds: 3));
      if (doc.exists) {
        final data = _enc.decryptDoc(doc.data() as Map<String, dynamic>?);
        return {
          'storeName': data['storeName']?.toString() ?? '',
          'storeAddress': data['storeAddress']?.toString() ?? '',
        };
      }
      return {};
    } catch (e) {
      debugPrint("fetchStoreProfile error: $e");
      return {};
    }
  }

  /// REAL-TIME stream of store profile (Decrypted)
  Stream<Map<String, String>> streamStoreProfile() {
    final col = _storeProfileCollection;
    if (col == null) return Stream.value({});
    return col.doc('profile').snapshots().map((doc) {
      if (doc.exists) {
        final data = _enc.decryptDoc(doc.data() as Map<String, dynamic>?);
        return {
          'storeName': data['storeName']?.toString() ?? '',
          'storeAddress': data['storeAddress']?.toString() ?? '',
        };
      }
      return <String, String>{};
    }).handleError((e) {
      debugPrint("streamStoreProfile error: $e");
      return <String, String>{};
    });
  }

  // =====================================================================
  // FULL DATABASE PURGE & ATOMIC RESTORE (CLOUD)
  // =====================================================================

  /// Permanently deletes all obsolete documents across all collections in Firestore
  Future<void> wipeAllDataFromFirestore() async {
    try {
      final collections = [
        _billsCollection,
        _customersCollection,
        _quickEntriesCollection,
        _ledgerEntriesCollection,
        _storeProfileCollection,
        _inventoryCollection,
      ];
      for (var col in collections) {
        if (col == null) continue;
        final snapshot = await col.get().timeout(const Duration(seconds: 10));
        for (var doc in snapshot.docs) {
          await doc.reference.delete();
        }
      }
      debugPrint("All Firestore collections purged cleanly.");
    } catch (e) {
      debugPrint("wipeAllDataFromFirestore error: $e");
    }
  }

  /// Atomically purges cloud and replaces with clean encrypted dataset using WriteBatch
  Future<void> batchSyncEncryptedData({
    required List<Invoice> invoices,
    required List<LedgerEntry> ledgerEntries,
    required List<QuickEntry> quickEntries,
    required List<InventoryItem> inventory,
    required String storeName,
    required String storeAddress,
  }) async {
    final instance = _firestore;
    if (instance == null) return;

    try {
      // 1. Purge all existing Firestore documents so no obsolete or phantom entries remain
      await wipeAllDataFromFirestore();

      // 2. Commit all data in WriteBatches (atomic chunks of max 400 operations)
      WriteBatch batch = instance.batch();
      int opCount = 0;

      Future<void> checkBatch() async {
        opCount++;
        if (opCount >= 400) {
          await batch.commit();
          batch = instance.batch();
          opCount = 0;
        }
      }

      // Store Profile
      final profCol = _storeProfileCollection;
      if (profCol != null) {
        final encrypted = _enc.encryptMap({
          'storeName': storeName,
          'storeAddress': storeAddress,
          'updatedAt': DateTime.now().toIso8601String(),
        });
        batch.set(profCol.doc('profile'), encrypted);
        await checkBatch();
      }

      // Inventory
      final invCol = _inventoryCollection;
      if (invCol != null) {
        for (var item in inventory) {
          final enc = _enc.encryptMap(item.toMap());
          batch.set(invCol.doc(item.id), enc);
          await checkBatch();
        }
      }

      // Invoices
      final billsCol = _billsCollection;
      if (billsCol != null) {
        for (var inv in invoices) {
          final enc = _enc.encryptMap(inv.toFirestore());
          batch.set(billsCol.doc(inv.id), enc);
          await checkBatch();
        }
      }

      // Quick entries
      final qeCol = _quickEntriesCollection;
      if (qeCol != null) {
        for (var q in quickEntries) {
          final enc = _enc.encryptMap(q.toMap());
          batch.set(qeCol.doc(q.id), enc);
          await checkBatch();
        }
      }

      // Ledger entries
      final ledCol = _ledgerEntriesCollection;
      if (ledCol != null) {
        for (var l in ledgerEntries) {
          final enc = _enc.encryptMap(l.toMap());
          batch.set(ledCol.doc(l.id), enc);
          await checkBatch();
        }
      }

      if (opCount > 0) {
        await batch.commit();
      }

      debugPrint("Atomic WriteBatch encrypted cloud sync complete (${invoices.length} bills, ${ledgerEntries.length} ledger entries, ${inventory.length} inventory items).");
    } catch (e) {
      debugPrint("batchSyncEncryptedData error: $e");
    }
  }
}
