import 'dart:async';
import 'dart:convert';
import 'package:hp_bill/models/inventory_item.dart';
import 'package:hp_bill/models/invoice.dart';
import 'package:hp_bill/models/ledger_entry.dart';
import 'package:hp_bill/models/quick_entry.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  DatabaseHelper._init();

  SharedPreferences? _prefs;

  // Cache tables
  final List<Invoice> _invoices = [];
  final List<LedgerEntry> _ledgerEntries = [];
  final List<QuickEntry> _quickEntries = [];
  final List<InventoryItem> _inventory = [];
  
  // Store Profile Configuration
  String _storeName = 'HP Bill';
  String _storeAddress = '12, Lavender Arcade, Industrial Area, Mumbai';

  // --- Initialization ---

  Future<void> init() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();

    // Load store profile
    _storeName = _prefs!.getString('storeName') ?? 'HP Bill';
    _storeAddress = _prefs!.getString('storeAddress') ?? '12, Lavender Arcade, Industrial Area, Mumbai';

    // Load lists
    _loadFromPrefs();

    // Seed if never initialized
    if (!(_prefs!.getBool('db_initialized') ?? false)) {
      seedInitialData();
      await _prefs!.setBool('db_initialized', true);
      await _saveAllToPrefs();
    }
  }

  void _loadFromPrefs() {
    if (_prefs == null) return;

    // Clear existing cache
    _inventory.clear();
    _invoices.clear();
    _ledgerEntries.clear();
    _quickEntries.clear();

    // Load inventory
    final inventoryStr = _prefs!.getString('inventory_list');
    if (inventoryStr != null) {
      final List decoded = jsonDecode(inventoryStr);
      _inventory.addAll(decoded.map((item) => InventoryItem.fromMap(item)).toList());
    }

    // Load invoices
    final invoicesStr = _prefs!.getString('invoices_list');
    if (invoicesStr != null) {
      final List decoded = jsonDecode(invoicesStr);
      _invoices.addAll(decoded.map((item) => Invoice.fromMap(item)).toList());
    }

    // Load ledger entries
    final ledgerStr = _prefs!.getString('ledger_entries_list');
    if (ledgerStr != null) {
      final List decoded = jsonDecode(ledgerStr);
      _ledgerEntries.addAll(decoded.map((item) => LedgerEntry.fromMap(item)).toList());
    }

    // Load quick entries
    final quickStr = _prefs!.getString('quick_entries_list');
    if (quickStr != null) {
      final List decoded = jsonDecode(quickStr);
      _quickEntries.addAll(decoded.map((item) => QuickEntry.fromMap(item)).toList());
    }
  }

  Future<void> _saveAllToPrefs() async {
    if (_prefs == null) return;
    await _prefs!.setString('inventory_list', jsonEncode(_inventory.map((i) => i.toMap()).toList()));
    await _prefs!.setString('invoices_list', jsonEncode(_invoices.map((i) => i.toMap()).toList()));
    await _prefs!.setString('ledger_entries_list', jsonEncode(_ledgerEntries.map((l) => l.toMap()).toList()));
    await _prefs!.setString('quick_entries_list', jsonEncode(_quickEntries.map((q) => q.toMap()).toList()));
  }

  // Seed initial mock data for dashboard visuals, ledger lookups, and inventory
  void seedInitialData() {
    // Seed Global Inventory Items (NO TAX RATES)
    _inventory.addAll([
      InventoryItem(id: 'inv1', name: '18mm Premium Ply', defaultRate: 1450.0),
      InventoryItem(id: 'inv2', name: '12mm MDF Board', defaultRate: 980.0),
      InventoryItem(id: 'inv3', name: 'Teak Wood Plank', defaultRate: 2500.0),
      InventoryItem(id: 'inv4', name: 'Lavender Soap Bar', defaultRate: 120.0),
      InventoryItem(id: 'inv5', name: 'Essential Diffuser', defaultRate: 850.0),
    ]);

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Seed Invoices (NO TAX, NO DISCOUNT)
    final invoice1 = Invoice(
      id: '1',
      invoiceNumber: 'INV-$todayStr--0001',
      customerName: 'Aman Sharma',
      customerPhone: '9876543210',
      date: DateTime.now().subtract(const Duration(hours: 3)),
      items: [
        InvoiceItem(id: 'i1', name: 'Lavender Soap Bar', quantity: 10, rate: 120.0),
        InvoiceItem(id: 'i2', name: 'Essential Diffuser', quantity: 2, rate: 850.0),
      ],
      isPaid: true,
      isSynced: true,
    );

    final invoice2 = Invoice(
      id: '2',
      invoiceNumber: 'INV-$todayStr--0002',
      customerName: 'Riya Patel',
      customerPhone: '9812345678',
      date: DateTime.now().subtract(const Duration(hours: 1)),
      items: [
        InvoiceItem(id: 'i3', name: '18mm Premium Ply', quantity: 5, rate: 1450.0),
      ],
      isPaid: false,
      isSynced: false,
    );

    _invoices.addAll([invoice1, invoice2]);

    // Seed Ledger Entries
    _ledgerEntries.addAll([
      LedgerEntry(
        id: 'l1',
        customerName: 'Aman Sharma',
        date: DateTime.now().subtract(const Duration(days: 3)),
        description: 'Sales Bill INV-$todayStr--0001',
        type: LedgerEntryType.debit,
        amount: 2900.0,
        runningBalance: 2900.0,
        invoiceId: '1',
      ),
      LedgerEntry(
        id: 'l2',
        customerName: 'Aman Sharma',
        date: DateTime.now().subtract(const Duration(days: 2)),
        description: 'Cash Receipt',
        type: LedgerEntryType.credit,
        amount: 2000.0,
        runningBalance: 900.0,
      ),
      LedgerEntry(
        id: 'l3',
        customerName: 'Riya Patel',
        date: DateTime.now().subtract(const Duration(days: 1)),
        description: 'Sales Bill INV-$todayStr--0002',
        type: LedgerEntryType.debit,
        amount: 7250.0,
        runningBalance: 7250.0,
        invoiceId: '2',
      ),
    ]);

    // Seed Quick Entries
    _quickEntries.addAll([
      QuickEntry(
        id: 'q1',
        date: DateTime.now().subtract(const Duration(days: 2)),
        type: QuickEntryType.receipt,
        mode: AccountMode.cash,
        partyName: 'Aman Sharma',
        amount: 2000.0,
        remarks: 'Part payment received',
        isSynced: true,
      ),
    ]);
  }

  // --- Store Profile Methods ---

  Future<Map<String, String>> getStoreProfile() async {
    return {
      'storeName': _storeName,
      'storeAddress': _storeAddress,
    };
  }

  Future<void> saveStoreProfile(String name, String address) async {
    _storeName = name;
    _storeAddress = address;
    if (_prefs != null) {
      await _prefs!.setString('storeName', name);
      await _prefs!.setString('storeAddress', address);
    }
  }

  // --- Inventory Methods ---

  Future<List<InventoryItem>> getInventory() async {
    return List.from(_inventory);
  }

  Future<void> saveInventoryItem(InventoryItem item) async {
    final index = _inventory.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      _inventory[index] = item;
    } else {
      _inventory.add(item);
    }
    await _saveAllToPrefs();
  }

  Future<void> deleteInventoryItem(String id) async {
    _inventory.removeWhere((item) => item.id == id);
    await _saveAllToPrefs();
  }

  // --- Invoice Methods ---

  Future<List<Invoice>> getInvoices() async {
    return List.from(_invoices);
  }

  /// Generates invoice number sequentially based on current date, resetting daily
  Future<String> generateNextInvoiceNumber() async {
    final todayPrefix = DateFormat('yyyy-MM-dd').format(DateTime.now()); // e.g. 2026-07-01
    final searchPrefix = 'INV-$todayPrefix--';

    int maxDailySeq = 0;
    for (var inv in _invoices) {
      if (inv.invoiceNumber.startsWith(searchPrefix)) {
        final seqStr = inv.invoiceNumber.replaceFirst(searchPrefix, '');
        final seqVal = int.tryParse(seqStr);
        if (seqVal != null && seqVal > maxDailySeq) {
          maxDailySeq = seqVal;
        }
      }
    }

    final nextSeq = maxDailySeq + 1;
    final paddedSeq = nextSeq.toString().padLeft(4, '0');
    return 'INV-$todayPrefix--$paddedSeq';
  }

  Future<void> saveInvoice(Invoice invoice) async {
    _invoices.add(invoice);

    final cleanName = invoice.customerName.trim();

    // Automatically add to Client Ledger as a Debit entry
    final ledgerItem = LedgerEntry(
      id: 'L-${invoice.id}',
      customerName: cleanName,
      date: invoice.date,
      description: 'Sales Bill ${invoice.invoiceNumber}',
      type: LedgerEntryType.debit,
      amount: invoice.grandTotal,
      runningBalance: 0.0, // Will be recalculated
      invoiceId: invoice.id,
      customerPhone: invoice.customerPhone.trim().isEmpty ? null : invoice.customerPhone.trim(),
    );
    _ledgerEntries.add(ledgerItem);

    _recalculateCustomerLedger(cleanName);
    await _saveAllToPrefs();
  }

  Future<void> deleteInvoice(String id) async {
    final invoiceIndex = _invoices.indexWhere((inv) => inv.id == id);
    if (invoiceIndex != -1) {
      final customerName = _invoices[invoiceIndex].customerName;
      _invoices.removeAt(invoiceIndex);
      _ledgerEntries.removeWhere((entry) => entry.invoiceId == id);
      _recalculateCustomerLedger(customerName);
      await _saveAllToPrefs();
    }
  }

  Future<void> toggleInvoicePaymentStatus(String id) async {
    final index = _invoices.indexWhere((inv) => inv.id == id);
    if (index != -1) {
      final old = _invoices[index];
      final newPaid = !old.isPaid;
      _invoices[index] = Invoice(
        id: old.id,
        invoiceNumber: old.invoiceNumber,
        customerName: old.customerName,
        customerPhone: old.customerPhone,
        date: old.date,
        items: old.items,
        isPaid: newPaid,
        isSynced: old.isSynced,
        customerAddress: old.customerAddress,
        transport: old.transport,
        lrNo: old.lrNo,
        siteName: old.siteName,
      );

      _recalculateCustomerLedger(old.customerName);
      await _saveAllToPrefs();
    }
  }

  // --- Quick Entry Methods ---

  Future<List<QuickEntry>> getQuickEntries() async {
    return List.from(_quickEntries);
  }

  Future<void> saveQuickEntry(QuickEntry entry) async {
    _quickEntries.add(entry);

    if (entry.type != QuickEntryType.contra) {
      final cleanName = entry.partyName.trim();
      final isReceipt = entry.type == QuickEntryType.receipt;

      final ledgerItem = LedgerEntry(
        id: 'L-QE-${entry.id}',
        customerName: cleanName,
        date: entry.date,
        description: '${entry.type.name.toUpperCase()} (${entry.mode.name.toUpperCase()}) - ${entry.remarks}',
        type: isReceipt ? LedgerEntryType.credit : LedgerEntryType.debit,
        amount: entry.amount,
        runningBalance: 0.0, // Will be recalculated
      );
      _ledgerEntries.add(ledgerItem);
      _recalculateCustomerLedger(cleanName);
    }
    await _saveAllToPrefs();
  }

  Future<void> deleteQuickEntry(String id) async {
    final entryIndex = _quickEntries.indexWhere((e) => e.id == id);
    if (entryIndex != -1) {
      final entry = _quickEntries[entryIndex];
      _quickEntries.removeAt(entryIndex);
      _ledgerEntries.removeWhere((e) => e.id == 'L-QE-$id');
      if (entry.type != QuickEntryType.contra) {
        _recalculateCustomerLedger(entry.partyName);
      }
      await _saveAllToPrefs();
    }
  }

  // --- Ledger Methods ---

  void _recalculateCustomerLedger(String customerName) {
    final cleanName = customerName.toLowerCase().trim();

    // 1. Get all entries for this customer
    final customerEntries = _ledgerEntries
        .where((e) => e.customerName.toLowerCase().trim() == cleanName)
        .toList();

    // 2. Sort them by date chronologically
    customerEntries.sort((a, b) => a.date.compareTo(b.date));

    // 3. Recalculate running balance
    double balance = 0.0;
    final updatedEntries = customerEntries.map((e) {
      final invoice = e.invoiceId != null
          ? _invoices.where((inv) => inv.id == e.invoiceId).firstOrNull
          : null;
      final isPaidInvoice = invoice != null && invoice.isPaid;

      if (e.type == LedgerEntryType.debit) {
        if (!isPaidInvoice) {
          balance += e.amount;
        }
      } else {
        balance -= e.amount;
      }
      return LedgerEntry(
        id: e.id,
        customerName: e.customerName,
        date: e.date,
        description: e.description,
        type: e.type,
        amount: e.amount,
        runningBalance: balance,
        invoiceId: e.invoiceId,
      );
    }).toList();

    // 4. Update in-place in _ledgerEntries list
    for (var updated in updatedEntries) {
      final idx = _ledgerEntries.indexWhere((e) => e.id == updated.id);
      if (idx != -1) {
        _ledgerEntries[idx] = updated;
      }
    }
  }

  Future<List<LedgerEntry>> getLedger(String customerName) async {
    return _ledgerEntries
        .where((e) => e.customerName.toLowerCase().trim() == customerName.toLowerCase().trim())
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<List<LedgerEntry>> getAllLedgerEntries() async {
    return List.from(_ledgerEntries);
  }

  Future<void> addLedgerEntry(LedgerEntry entry) async {
    _ledgerEntries.add(entry);
    _recalculateCustomerLedger(entry.customerName.trim());
    await _saveAllToPrefs();
  }

  Future<String?> getCustomerPhone(String customerName) async {
    final cleanName = customerName.toLowerCase().trim();
    for (var inv in _invoices) {
      if (inv.customerName.toLowerCase().trim() == cleanName && inv.customerPhone.isNotEmpty) {
        return inv.customerPhone;
      }
    }
    for (var entry in _ledgerEntries) {
      if (entry.customerName.toLowerCase().trim() == cleanName && entry.customerPhone != null && entry.customerPhone!.isNotEmpty) {
        return entry.customerPhone;
      }
    }
    return null;
  }

  Future<List<String>> getUniqueCustomers() async {
    final customers = <String>{};
    for (var entry in _ledgerEntries) {
      customers.add(entry.customerName.trim());
    }
    for (var inv in _invoices) {
      customers.add(inv.customerName.trim());
    }
    return customers.toList();
  }

  /// Deletes all ledger statements and invoices for a specific customer
  Future<void> deleteLedgerForCustomer(String customerName) async {
    final cleanName = customerName.toLowerCase().trim();
    _ledgerEntries.removeWhere((e) => e.customerName.toLowerCase().trim() == cleanName);
    _invoices.removeWhere((inv) => inv.customerName.toLowerCase().trim() == cleanName);
    _quickEntries.removeWhere((qe) => qe.partyName.toLowerCase().trim() == cleanName);
    await _saveAllToPrefs();
  }

  // --- BACKUP / RESTORE / WIPE Methods ---

  Map<String, dynamic> exportAllData() {
    return {
      'version': 1,
      'exportDate': DateTime.now().toIso8601String(),
      'storeName': _storeName,
      'storeAddress': _storeAddress,
      'inventory': _inventory.map((i) => i.toMap()).toList(),
      'invoices': _invoices.map((i) => i.toMap()).toList(),
      'quickEntries': _quickEntries.map((e) => e.toMap()).toList(),
      'ledgerEntries': _ledgerEntries.map((e) => e.toMap()).toList(),
    };
  }

  String exportAllDataAsJson() {
    return const JsonEncoder.withIndent('  ').convert(exportAllData());
  }

  Future<void> importAllData(Map<String, dynamic> data) async {
    _invoices.clear();
    _ledgerEntries.clear();
    _quickEntries.clear();
    _inventory.clear();

    _storeName = data['storeName'] ?? 'HP Bill';
    _storeAddress = data['storeAddress'] ?? '';

    if (data['inventory'] != null) {
      for (var item in data['inventory']) {
        _inventory.add(InventoryItem.fromMap(item));
      }
    }

    if (data['invoices'] != null) {
      for (var item in data['invoices']) {
        _invoices.add(Invoice.fromMap(item));
      }
    }

    if (data['quickEntries'] != null) {
      for (var item in data['quickEntries']) {
        _quickEntries.add(QuickEntry.fromMap(item));
      }
    }

    if (data['ledgerEntries'] != null) {
      for (var item in data['ledgerEntries']) {
        _ledgerEntries.add(LedgerEntry.fromMap(item));
      }
    }

    if (_prefs != null) {
      await _prefs!.setString('storeName', _storeName);
      await _prefs!.setString('storeAddress', _storeAddress);
    }
    await _saveAllToPrefs();
  }

  Future<void> wipeAllData() async {
    _invoices.clear();
    _ledgerEntries.clear();
    _quickEntries.clear();
    _inventory.clear();
    _storeName = 'HP Bill';
    _storeAddress = '';
    
    if (_prefs != null) {
      await _prefs!.setString('storeName', _storeName);
      await _prefs!.setString('storeAddress', _storeAddress);
      await _prefs!.setBool('db_initialized', false);
    }
    await _saveAllToPrefs();
  }
}
