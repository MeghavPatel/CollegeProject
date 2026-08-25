import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hp_bill/models/customer.dart';
import 'package:hp_bill/models/inventory_item.dart';
import 'package:hp_bill/models/invoice.dart';
import 'package:hp_bill/models/ledger_entry.dart';
import 'package:hp_bill/services/database_helper.dart';
import 'package:hp_bill/services/firestore_invoice_service.dart';
import 'package:hp_bill/services/print_service.dart';
import 'package:hp_bill/services/share_service.dart';
import 'package:uuid/uuid.dart';

class InvoiceProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final FirestoreInvoiceService _firestoreService = FirestoreInvoiceService.instance;

  List<Invoice> _invoices = [];
  List<Customer> _customers = [];
  bool _isLoading = false;

  // Store & Profile Configuration
  String _storeName = 'HP Bill';
  String _storeAddress = '';

  // Global Item Inventory
  List<InventoryItem> _inventory = [];

  // Active Invoice form states
  String? _editingInvoiceId;
  String _activeInvoiceNumber = '';
  String _customerName = '';
  String _customerPhone = '';
  String? _customerEmail;
  String? _customerAddress;
  String? _transport;
  String? _lrNo;
  String? _siteName;
  String? _notes;
  double _tax = 0.0;
  double _discount = 0.0;
  List<InvoiceItem> _activeItems = [];
  bool _isPaid = false;

  // Real-time stream subscriptions
  StreamSubscription? _invoiceStreamSub;
  StreamSubscription? _inventoryStreamSub;
  StreamSubscription? _storeProfileStreamSub;

  // Getters
  List<Invoice> get invoices => _invoices;
  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;
  
  String get storeName => _storeName;
  String get storeAddress => _storeAddress;
  List<InventoryItem> get inventory => _inventory;
  
  String? get editingInvoiceId => _editingInvoiceId;
  String get activeInvoiceNumber => _activeInvoiceNumber;
  String get customerName => _customerName;
  String get customerPhone => _customerPhone;
  String? get customerEmail => _customerEmail;
  String? get customerAddress => _customerAddress;
  String? get transport => _transport;
  String? get lrNo => _lrNo;
  String? get siteName => _siteName;
  String? get notes => _notes;
  double get tax => _tax;
  double get discount => _discount;
  List<InvoiceItem> get activeItems => _activeItems;
  bool get isPaid => _isPaid;

  double get activeSubtotal => _activeItems.fold(0.0, (sum, item) => sum + item.subtotal);
  double get activeGrandTotal {
    final total = activeSubtotal + _tax - _discount;
    return total < 0 ? 0.0 : total;
  }

  // =====================================================================
  // REAL-TIME SYNC — Listen to Firestore for live updates across phones
  // =====================================================================

  /// Start listening to Firestore invoice, inventory, and profile streams for real-time sync.
  /// Call this once from Dashboard initState.
  void startRealtimeSync() {
    _invoiceStreamSub?.cancel();
    _inventoryStreamSub?.cancel();
    _storeProfileStreamSub?.cancel();

    if (!_firestoreService.isAvailable) {
      debugPrint("Firestore not available — skipping real-time sync.");
      return;
    }

    // 1. Invoices stream
    _invoiceStreamSub = _firestoreService.streamInvoices().listen(
      (cloudInvoices) async {
        // Full reconciliation: adds new, updates modified, removes deleted
        await _db.syncInvoicesFromCloud(cloudInvoices);

        // Reload from local DB
        _invoices = await _db.getInvoices();
        _invoices.sort((a, b) => b.date.compareTo(a.date));
        notifyListeners();
      },
      onError: (e) {
        debugPrint("Invoice stream error: $e");
      },
    );

    // 2. Inventory stream (Syncs product additions, edits, and deletions across all phones in real-time)
    _inventoryStreamSub = _firestoreService.streamInventory().listen(
      (cloudInventory) async {
        await _db.syncInventoryFromCloud(cloudInventory);
        _inventory = await _db.getInventory();
        notifyListeners();
      },
      onError: (e) {
        debugPrint("Inventory stream error: $e");
      },
    );

    // 3. Store Profile stream (Syncs business name & address changes in real-time)
    _storeProfileStreamSub = _firestoreService.streamStoreProfile().listen(
      (cloudProfile) async {
        if (cloudProfile.isNotEmpty) {
          final cloudName = cloudProfile['storeName'] ?? '';
          final cloudAddr = cloudProfile['storeAddress'] ?? '';
          if (cloudName.isNotEmpty) {
            await _db.syncStoreProfileFromCloud(cloudName, cloudAddr);
            _storeName = cloudName;
            _storeAddress = cloudAddr;
            notifyListeners();
          }
        }
      },
      onError: (e) {
        debugPrint("Store profile stream error: $e");
      },
    );

    debugPrint("Real-time invoice, inventory, and profile sync started.");
  }

  void pauseRealtimeSync() {
    _invoiceStreamSub?.cancel();
    _inventoryStreamSub?.cancel();
    _storeProfileStreamSub?.cancel();
  }

  @override
  void dispose() {
    _invoiceStreamSub?.cancel();
    _inventoryStreamSub?.cancel();
    _storeProfileStreamSub?.cancel();
    super.dispose();
  }

  // Load store details and inventory
  Future<void> fetchStoreDetails() async {
    final profile = await _db.getStoreProfile();
    _storeName = profile['storeName'] ?? 'HP Bill';
    _storeAddress = profile['storeAddress'] ?? '';
    _inventory = await _db.getInventory();

    // Try to get store profile and inventory from cloud
    try {
      final cloudProfile = await _firestoreService.fetchStoreProfile();
      if (cloudProfile.isNotEmpty) {
        final cloudName = cloudProfile['storeName'] ?? '';
        final cloudAddr = cloudProfile['storeAddress'] ?? '';
        if (cloudName.isNotEmpty) {
          _storeName = cloudName;
          _storeAddress = cloudAddr;
          await _db.syncStoreProfileFromCloud(cloudName, cloudAddr);
        }
      }

      final cloudInventory = await _firestoreService.fetchInventory();
      if (cloudInventory.isNotEmpty) {
        await _db.syncInventoryFromCloud(cloudInventory);
        _inventory = await _db.getInventory();
      } else if (_inventory.isNotEmpty) {
        // First-time seed local inventory to cloud if cloud is empty
        for (var item in _inventory) {
          await _firestoreService.saveInventoryItem(item);
        }
      }
    } catch (e) {
      debugPrint("Cloud store details / inventory notice: $e");
    }

    notifyListeners();
  }

  // Update and save Store profile details
  Future<void> saveStoreProfile(String name, String address) async {
    _isLoading = true;
    notifyListeners();

    await _db.saveStoreProfile(name, address);
    
    // Sync to cloud
    try {
      await _firestoreService.saveStoreProfile(name, address);
    } catch (e) {
      debugPrint("Cloud store profile save notice: $e");
    }

    await fetchStoreDetails();

    _isLoading = false;
    notifyListeners();
  }

  // Inventory Management methods (Local + Cloud Encrypted)
  Future<void> addInventoryItem(String name, double? rate) async {
    _isLoading = true;
    notifyListeners();

    final newItem = InventoryItem(
      id: const Uuid().v4(),
      name: name,
      defaultRate: rate,
    );

    // Save locally
    await _db.saveInventoryItem(newItem);

    // Push to Firestore (All other devices receive this immediately via stream)
    try {
      await _firestoreService.saveInventoryItem(newItem);
    } catch (e) {
      debugPrint("Cloud inventory add notice: $e");
    }

    await fetchStoreDetails();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateInventoryItem(InventoryItem item) async {
    _isLoading = true;
    notifyListeners();

    // Save locally
    await _db.saveInventoryItem(item);

    // Push update to Firestore
    try {
      await _firestoreService.saveInventoryItem(item);
    } catch (e) {
      debugPrint("Cloud inventory update notice: $e");
    }

    await fetchStoreDetails();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteInventoryItem(String id) async {
    _isLoading = true;
    notifyListeners();

    // Delete locally
    await _db.deleteInventoryItem(id);

    // Delete from Firestore
    try {
      await _firestoreService.deleteInventoryItem(id);
    } catch (e) {
      debugPrint("Cloud inventory delete notice: $e");
    }

    await fetchStoreDetails();

    _isLoading = false;
    notifyListeners();
  }

  // =====================================================================
  // FETCH INVOICES (Local-first + Cloud merge)
  // =====================================================================

  Future<void> fetchInvoices({
    DateTime? startDate,
    DateTime? endDate,
    String? paymentStatus,
  }) async {
    _isLoading = true;
    notifyListeners();

    // 1. Fetch from local cache first (instant)
    _invoices = await _db.getInvoices();

    // In-memory local filtering
    if (paymentStatus != null && paymentStatus.isNotEmpty && paymentStatus != 'all') {
      _invoices = _invoices.where((inv) => inv.paymentStatus == paymentStatus).toList();
    }
    if (startDate != null) {
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      _invoices = _invoices.where((inv) => inv.date.isAfter(start) || inv.date.isAtSameMomentAs(start)).toList();
    }
    if (endDate != null) {
      final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      _invoices = _invoices.where((inv) => inv.date.isBefore(end) || inv.date.isAtSameMomentAs(end)).toList();
    }

    _invoices.sort((a, b) => b.date.compareTo(a.date));

    _isLoading = false;
    notifyListeners();

    // 2. Background cloud merge (non-blocking) — cloud is source of truth
    // IMPORTANT: Always fetch ALL invoices (no filter) for sync to avoid
    // deleting local invoices that simply don't match the active filter.
    try {
      final cloudInvoices = await _firestoreService.fetchInvoiceHistory();

      // Get local invoices to compare
      final localAll = await _db.getInvoices();
      final cloudIds = cloudInvoices.map((inv) => inv.id).toSet();
      final localIds = localAll.map((inv) => inv.id).toSet();

      // Delete local invoices not in cloud (deleted from another phone)
      final deletedIds = localIds.difference(cloudIds);
      for (var id in deletedIds) {
        await _db.deleteInvoice(id);
      }

      // Upsert cloud invoices (fromSync: true to avoid duplicate ledger entries)
      for (var inv in cloudInvoices) {
        await _db.saveInvoice(inv, fromSync: true);
      }

      _invoices = await _db.getInvoices();
      _invoices.sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();
    } catch (e) {
      debugPrint("Firestore fetch notice: $e");
    }
  }

  // =====================================================================
  // CUSTOMER MANAGEMENT
  // =====================================================================

  Future<void> fetchCustomers() async {
    try {
      _customers = await _firestoreService.fetchCustomers();
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching customers: $e");
    }
  }

  Future<void> saveCustomer(Customer customer) async {
    try {
      await _firestoreService.saveCustomer(customer);
      await fetchCustomers();
    } catch (e) {
      debugPrint("Error saving customer: $e");
    }
  }

  Future<void> deleteCustomer(String customerId) async {
    try {
      await _firestoreService.deleteCustomer(customerId);
      await fetchCustomers();
    } catch (e) {
      debugPrint("Error deleting customer: $e");
    }
  }

  // =====================================================================
  // INVOICE FORM STATE
  // =====================================================================

  Future<void> initializeNewInvoice() async {
    _isLoading = true;
    notifyListeners();

    await fetchStoreDetails();
    _activeInvoiceNumber = await _db.generateNextInvoiceNumber();
    
    _editingInvoiceId = null;
    _customerName = '';
    _customerPhone = '';
    _customerEmail = null;
    _customerAddress = null;
    _transport = null;
    _lrNo = null;
    _siteName = null;
    _notes = null;
    _tax = 0.0;
    _discount = 0.0;
    _activeItems = [];
    _isPaid = false;

    _isLoading = false;
    notifyListeners();
  }

  void loadInvoiceForEditing(Invoice invoice) {
    _editingInvoiceId = invoice.id;
    _activeInvoiceNumber = invoice.invoiceNumber;
    _customerName = invoice.customerName;
    _customerPhone = invoice.customerPhone;
    _customerEmail = invoice.customerEmail;
    _customerAddress = invoice.customerAddress;
    _transport = invoice.transport;
    _lrNo = invoice.lrNo;
    _siteName = invoice.siteName;
    _notes = invoice.notes;
    _tax = invoice.tax;
    _discount = invoice.discount;
    _activeItems = List.from(invoice.items);
    _isPaid = invoice.isPaid;
    notifyListeners();
  }

  void setNotes(String? notes) {
    _notes = notes;
    notifyListeners();
  }

  void setTaxAndDiscount(double tax, double discount) {
    _tax = tax;
    _discount = discount;
    notifyListeners();
  }

  void setCustomerInfo(String name, String phone, {String? email, String? address}) {
    _customerName = name;
    _customerPhone = phone;
    _customerEmail = email;
    _customerAddress = address;
    notifyListeners();
  }

  void setCustomerDetails({
    required String name,
    required String phone,
    String? email,
    String? address,
    String? transport,
    String? lrNo,
    String? siteName,
  }) {
    _customerName = name;
    _customerPhone = phone;
    _customerEmail = email;
    _customerAddress = address;
    _transport = transport;
    _lrNo = lrNo;
    _siteName = siteName;
    notifyListeners();
  }

  void setPaymentStatus(bool paid) {
    _isPaid = paid;
    notifyListeners();
  }

  void addInvoiceItem(String name, double qty, double rate) {
    final newItem = InvoiceItem(
      id: const Uuid().v4(),
      name: name,
      quantity: qty,
      rate: rate,
    );
    _activeItems = List.from(_activeItems)..add(newItem);
    notifyListeners();
  }

  void updateActiveInvoiceItem(String id, double qty, double rate) {
    final index = _activeItems.indexWhere((item) => item.id == id);
    if (index != -1) {
      final old = _activeItems[index];
      _activeItems[index] = InvoiceItem(
        id: old.id,
        name: old.name,
        quantity: qty,
        rate: rate,
      );
      notifyListeners();
    }
  }

  void removeInvoiceItem(String id) {
    _activeItems = List.from(_activeItems)..removeWhere((item) => item.id == id);
    notifyListeners();
  }

  // =====================================================================
  // SAVE INVOICE (Local + Cloud)
  // =====================================================================

  Future<Invoice> saveActiveInvoice() async {
    if (_customerName.isEmpty || _activeItems.isEmpty) {
      throw Exception("Customer details or items list cannot be empty.");
    }

    bool syncedToCloud = false;

    final invoiceToSave = Invoice(
      id: _editingInvoiceId ?? const Uuid().v4(),
      invoiceNumber: _activeInvoiceNumber,
      customerName: _customerName,
      customerPhone: _customerPhone,
      customerEmail: _customerEmail,
      date: DateTime.now(),
      items: List.from(_activeItems),
      isPaid: _isPaid,
      isSynced: false,
      customerAddress: _customerAddress,
      transport: _transport,
      lrNo: _lrNo,
      siteName: _siteName,
      notes: _notes,
      tax: _tax,
      discount: _discount,
    );

    // 1. Write to Firestore (real-time sync to other phones)
    try {
      if (_editingInvoiceId != null) {
        await _firestoreService.updateInvoice(invoiceToSave);
      } else {
        await _firestoreService.createInvoice(invoiceToSave);
      }
      syncedToCloud = true;
    } catch (e) {
      debugPrint("Cloud save notice: $e (saved locally for auto-sync)");
    }

    // 2. Save locally
    final finalInvoice = Invoice(
      id: invoiceToSave.id,
      invoiceNumber: invoiceToSave.invoiceNumber,
      customerName: invoiceToSave.customerName,
      customerPhone: invoiceToSave.customerPhone,
      customerEmail: invoiceToSave.customerEmail,
      date: invoiceToSave.date,
      items: invoiceToSave.items,
      isPaid: invoiceToSave.isPaid,
      isSynced: syncedToCloud,
      customerAddress: invoiceToSave.customerAddress,
      transport: invoiceToSave.transport,
      lrNo: invoiceToSave.lrNo,
      siteName: invoiceToSave.siteName,
      notes: invoiceToSave.notes,
      tax: invoiceToSave.tax,
      discount: invoiceToSave.discount,
    );

    await _db.saveInvoice(finalInvoice);

    // 3. Sync the invoice-linked ledger entry to Firestore
    // (saveInvoice creates a ledger entry L-{id} locally — push it to cloud
    // so other phones receive it via the ledger stream)
    try {
      final ledgerEntry = LedgerEntry(
        id: 'L-${finalInvoice.id}',
        customerName: finalInvoice.customerName.trim(),
        date: finalInvoice.date,
        description: 'Sales Bill ${finalInvoice.invoiceNumber}',
        type: LedgerEntryType.debit,
        amount: finalInvoice.grandTotal,
        runningBalance: 0.0,
        invoiceId: finalInvoice.id,
        customerPhone: finalInvoice.customerPhone.trim().isEmpty ? null : finalInvoice.customerPhone.trim(),
      );
      await _firestoreService.saveLedgerEntry(ledgerEntry);
    } catch (e) {
      debugPrint("Cloud ledger sync notice: $e");
    }

    // Auto-save customer to Firestore
    if (_customerName.isNotEmpty && _customerPhone.isNotEmpty) {
      saveCustomer(Customer(
        id: _customerPhone,
        name: _customerName,
        phone: _customerPhone,
        email: _customerEmail ?? '',
        address: _customerAddress ?? '',
      ));
    }

    await fetchInvoices();
    return finalInvoice;
  }

  // =====================================================================
  // DATA CONTROL ACTIONS
  // =====================================================================
  
  Future<void> deleteInvoice(String invoiceId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _firestoreService.deleteInvoice(invoiceId);
    } catch (e) {
      debugPrint("Firestore delete notice: $e");
    }

    // Also delete the invoice-linked ledger entry from Firestore
    try {
      await _firestoreService.deleteLedgerEntry('L-$invoiceId');
    } catch (e) {
      debugPrint("Firestore ledger delete notice: $e");
    }

    await _db.deleteInvoice(invoiceId);
    await fetchInvoices();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> toggleInvoicePaymentStatus(String invoiceId) async {
    _isLoading = true;
    notifyListeners();

    final index = _invoices.indexWhere((inv) => inv.id == invoiceId);
    if (index != -1) {
      final current = _invoices[index];
      final newPaid = !current.isPaid;
      try {
        await _firestoreService.updatePaymentStatus(invoiceId, newPaid);
      } catch (e) {
        debugPrint("Firestore status update notice: $e");
      }
    }

    await _db.toggleInvoicePaymentStatus(invoiceId);
    await fetchInvoices();

    _isLoading = false;
    notifyListeners();
  }

  // =====================================================================
  // BACKUP / RESTORE / WIPE
  // =====================================================================

  String exportBackupJson() {
    return _db.exportAllDataAsJson();
  }

  Future<void> restoreFromJson(String jsonString) async {
    _isLoading = true;
    notifyListeners();

    pauseRealtimeSync();

    try {
      final dynamic decoded = jsonDecode(jsonString);
      Map<String, dynamic> data = {};
      if (decoded is Map<String, dynamic>) {
        data = decoded;
      } else if (decoded is Map) {
        data = Map<String, dynamic>.from(decoded);
      } else if (decoded is List) {
        data = {'invoices': decoded};
      }

      // 1. Import and recalculate locally
      await _db.importAllData(data);
      await fetchStoreDetails();
      await fetchInvoices();

      // 2. Perform atomic purge and encrypted batch sync to Firestore
      try {
        final allInvoices = await _db.getInvoices();
        final allQuickEntries = await _db.getQuickEntries();
        final allLedger = await _db.getAllLedgerEntries();
        final allInventory = await _db.getInventory();

        await _firestoreService.batchSyncEncryptedData(
          invoices: allInvoices,
          ledgerEntries: allLedger,
          quickEntries: allQuickEntries,
          inventory: allInventory,
          storeName: _storeName,
          storeAddress: _storeAddress,
        );

        debugPrint("Restored data cleanly purged & synced to Firestore (${allInvoices.length} invoices, ${allLedger.length} ledger entries, ${allInventory.length} inventory items).");
      } catch (e) {
        debugPrint("Cloud sync after restore notice: $e");
      }
    } catch (e) {
      _isLoading = false;
      startRealtimeSync();
      notifyListeners();
      throw Exception("Invalid backup file format: $e");
    }

    startRealtimeSync();
    _isLoading = false;
    notifyListeners();
  }

  /// Forces a complete local recalculation and pushes a clean encrypted sync to Cloud
  Future<void> recalculateAndResyncAll() async {
    _isLoading = true;
    notifyListeners();

    pauseRealtimeSync();

    _db.recalculateAllCustomerLedgers();
    await fetchStoreDetails();
    await fetchInvoices();

    try {
      final allInvoices = await _db.getInvoices();
      final allQuickEntries = await _db.getQuickEntries();
      final allLedger = await _db.getAllLedgerEntries();
      final allInventory = await _db.getInventory();

      await _firestoreService.batchSyncEncryptedData(
        invoices: allInvoices,
        ledgerEntries: allLedger,
        quickEntries: allQuickEntries,
        inventory: allInventory,
        storeName: _storeName,
        storeAddress: _storeAddress,
      );
    } catch (e) {
      debugPrint("recalculateAndResyncAll notice: $e");
    }

    startRealtimeSync();
    _isLoading = false;
    notifyListeners();
  }

  /// Pulls fresh data from Cloud, reconciles with local storage, and recalculates all ledgers
  Future<void> manualCloudRefresh() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_firestoreService.isAvailable) {
        final cloudInvoices = await _firestoreService.fetchInvoiceHistory();
        if (cloudInvoices.isNotEmpty) {
          await _db.syncInvoicesFromCloud(cloudInvoices);
        }

        final cloudLedger = await _firestoreService.fetchLedgerEntries();
        if (cloudLedger.isNotEmpty) {
          await _db.syncLedgerFromCloud(cloudLedger);
        }

        final cloudQuick = await _firestoreService.fetchQuickEntries();
        if (cloudQuick.isNotEmpty) {
          await _db.syncQuickEntriesFromCloud(cloudQuick);
        }

        final cloudInventory = await _firestoreService.fetchInventory();
        if (cloudInventory.isNotEmpty) {
          await _db.syncInventoryFromCloud(cloudInventory);
        }

        final cloudProfile = await _firestoreService.fetchStoreProfile();
        if (cloudProfile.isNotEmpty) {
          final cloudName = cloudProfile['storeName'] ?? '';
          final cloudAddr = cloudProfile['storeAddress'] ?? '';
          if (cloudName.isNotEmpty) {
            await _db.syncStoreProfileFromCloud(cloudName, cloudAddr);
          }
        }
      }
    } catch (e) {
      debugPrint("manualCloudRefresh notice: $e");
    }

    _db.recalculateAllCustomerLedgers();
    await fetchStoreDetails();
    await fetchInvoices();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> wipeAllData() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _firestoreService.wipeAllDataFromFirestore();
    } catch (e) {
      debugPrint("Firestore wipe notice: $e");
    }

    await _db.wipeAllData();
    _invoices = [];
    _inventory = [];
    _activeItems = [];
    _editingInvoiceId = null;
    _storeName = 'HP Bill';
    _storeAddress = '';

    _isLoading = false;
    notifyListeners();
  }

  // Action Engines
  Future<void> printInvoice(Invoice invoice) async {
    await PrintService.instance.printInvoice(invoice);
  }

  Future<void> shareInvoicePdf(Invoice invoice) async {
    await ShareService.instance.shareInvoicePdf(invoice);
  }

  Future<void> shareWhatsAppDirect(Invoice invoice) async {
    await ShareService.instance.launchWhatsAppDirect(invoice);
  }
}
