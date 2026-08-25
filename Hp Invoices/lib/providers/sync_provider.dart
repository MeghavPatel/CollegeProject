import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hp_bill/models/invoice.dart';
import 'package:hp_bill/services/database_helper.dart';
import 'package:hp_bill/services/firestore_invoice_service.dart';

/// Manages online/offline state and background sync of unsynced local invoices.
class SyncProvider extends ChangeNotifier {
  bool _isOnline = true;
  bool _isSyncing = false;
  int _pendingSyncCount = 0;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get pendingSyncCount => _pendingSyncCount;

  Timer? _syncTimer;

  SyncProvider() {
    // Background sync every 30 seconds for any locally-saved items that
    // haven't been pushed to Firestore yet (e.g. saved while offline)
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isOnline) {
        syncPendingQueue();
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  void toggleConnection() {
    _isOnline = !_isOnline;
    notifyListeners();

    if (_isOnline) {
      syncPendingQueue();
    }
  }

  void incrementPendingQueue() {
    _pendingSyncCount++;
    notifyListeners();
  }

  Future<void> syncPendingQueue() async {
    if (!_isOnline || _isSyncing) return;

    final cloud = FirestoreInvoiceService.instance;
    if (!cloud.isAvailable) return;

    _isSyncing = true;
    notifyListeners();

    try {
      final db = DatabaseHelper.instance;
      final localInvoices = await db.getInvoices();
      final unsynced = localInvoices.where((inv) => !inv.isSynced).toList();

      _pendingSyncCount = unsynced.length;
      notifyListeners();

      for (var invoice in unsynced) {
        try {
          await cloud.createInvoice(invoice);
          // Save with isSynced=true so it won't be re-synced
          final syncedInvoice = Invoice(
            id: invoice.id,
            invoiceNumber: invoice.invoiceNumber,
            customerName: invoice.customerName,
            customerPhone: invoice.customerPhone,
            customerEmail: invoice.customerEmail,
            date: invoice.date,
            items: invoice.items,
            isPaid: invoice.isPaid,
            isSynced: true,
            customerAddress: invoice.customerAddress,
            transport: invoice.transport,
            lrNo: invoice.lrNo,
            siteName: invoice.siteName,
            notes: invoice.notes,
            tax: invoice.tax,
            discount: invoice.discount,
          );
          await db.saveInvoice(syncedInvoice, fromSync: true);
        } catch (e) {
          debugPrint("Failed to sync invoice ${invoice.invoiceNumber}: $e");
        }
      }

      _pendingSyncCount = 0;
    } catch (e) {
      debugPrint("Error syncing queue to Firestore: $e");
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
