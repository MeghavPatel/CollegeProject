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

    // Load store profile & printer config
    _storeName = _prefs!.getString('storeName') ?? 'HP Bill';
    _storeAddress = _prefs!.getString('storeAddress') ?? '12, Lavender Arcade, Industrial Area, Mumbai';
    _printerIp = _prefs!.getString('printerIp') ?? '192.168.1.81';
    _printerName = _prefs!.getString('printerName') ?? 'Canon LBP6030w/6018w';
    _directPrint = _prefs!.getBool('printerDirectPrint') ?? true;

    // Load lists from storage
    _loadFromPrefs();

    // Mark db initialized without injecting mock fake records
    if (!(_prefs!.getBool('db_initialized') ?? false)) {
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

  // --- Wi-Fi Printer Configuration Methods ---

  String _printerIp = '192.168.1.81';
  String _printerName = 'Canon LBP6030w/6018w';
  bool _directPrint = true;

  Future<Map<String, dynamic>> getPrinterConfig() async {
    return {
      'printerIp': _printerIp,
      'printerName': _printerName,
      'directPrint': _directPrint,
    };
  }

  Future<void> savePrinterConfig({
    required String ip,
    required String name,
    required bool directPrint,
  }) async {
    _printerIp = ip;
    _printerName = name;
    _directPrint = directPrint;
    if (_prefs != null) {
      await _prefs!.setString('printerIp', ip);
      await _prefs!.setString('printerName', name);
      await _prefs!.setBool('printerDirectPrint', directPrint);
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
    final todayPrefix = DateFormat('yyyy-MM-dd').format(DateTime.now());
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

  Future<void> saveInvoice(Invoice invoice, {bool fromSync = false}) async {
    final existingIndex = _invoices.indexWhere((inv) => inv.id == invoice.id);
    String? oldCustomerName;
    if (existingIndex != -1) {
      oldCustomerName = _invoices[existingIndex].customerName.trim();
      _invoices[existingIndex] = invoice;
    } else {
      _invoices.add(invoice);
    }

    final cleanName = invoice.customerName.trim();

    if (!fromSync) {
      // Upsert into Client Ledger as a Debit entry
      final ledgerId = 'L-${invoice.id}';
      final existingLedgerIdx = _ledgerEntries.indexWhere((e) => e.id == ledgerId || e.invoiceId == invoice.id);

      final ledgerItem = LedgerEntry(
        id: ledgerId,
        customerName: cleanName,
        date: invoice.date,
        description: 'Sales Bill ${invoice.invoiceNumber}',
        type: LedgerEntryType.debit,
        amount: invoice.grandTotal,
        runningBalance: 0.0,
        invoiceId: invoice.id,
        customerPhone: invoice.customerPhone.trim().isEmpty ? null : invoice.customerPhone.trim(),
      );

      if (existingLedgerIdx != -1) {
        _ledgerEntries[existingLedgerIdx] = ledgerItem;
      } else {
        _ledgerEntries.add(ledgerItem);
      }

      if (oldCustomerName != null && oldCustomerName.isNotEmpty && oldCustomerName != cleanName) {
        _recalculateCustomerLedger(oldCustomerName);
      }
      _recalculateCustomerLedger(cleanName);
    }
    await _saveAllToPrefs();
  }

  Future<void> deleteInvoice(String id) async {
    final invoiceIndex = _invoices.indexWhere((inv) => inv.id == id || inv.invoiceNumber == id);
    if (invoiceIndex != -1) {
      final inv = _invoices[invoiceIndex];
      final customerName = inv.customerName;
      _invoices.removeAt(invoiceIndex);
      _ledgerEntries.removeWhere((entry) =>
          entry.invoiceId == id ||
          entry.invoiceId == inv.id ||
          entry.invoiceId == inv.invoiceNumber ||
          entry.id == 'L-$id' ||
          entry.id == 'L-${inv.id}' ||
          (entry.description.isNotEmpty && inv.invoiceNumber.isNotEmpty && entry.description.contains(inv.invoiceNumber))
      );
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
        notes: old.notes,
        tax: old.tax,
        discount: old.discount,
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
    final existingIndex = _quickEntries.indexWhere((e) => e.id == entry.id);
    if (existingIndex != -1) {
      _quickEntries[existingIndex] = entry;
    } else {
      _quickEntries.add(entry);
    }

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
        runningBalance: 0.0,
      );

      final ledgerIndex = _ledgerEntries.indexWhere((e) => e.id == ledgerItem.id);
      if (ledgerIndex != -1) {
        _ledgerEntries[ledgerIndex] = ledgerItem;
      } else {
        _ledgerEntries.add(ledgerItem);
      }
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

  // --- Ledger Methods (Standard Double-Entry Accounting) ---

  void _recalculateCustomerLedger(String customerName) {
    final cleanName = customerName.toLowerCase().trim();
    if (cleanName.isEmpty) return;

    // 1. Get all entries for this customer
    final customerEntries = _ledgerEntries
        .where((e) => e.customerName.toLowerCase().trim() == cleanName)
        .toList();

    // 2. Sort chronologically by date
    customerEntries.sort((a, b) => a.date.compareTo(b.date));

    // 3. Recalculate running balance: Debit adds, Credit subtracts
    double running = 0.0;
    final updatedEntries = customerEntries.map((e) {
      if (e.type == LedgerEntryType.debit) {
        running += e.amount;
      } else {
        running -= e.amount;
      }

      return LedgerEntry(
        id: e.id,
        customerName: e.customerName,
        date: e.date,
        description: e.description,
        type: e.type,
        amount: e.amount,
        runningBalance: running,
        invoiceId: e.invoiceId,
        customerPhone: e.customerPhone,
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

  void recalculateAllCustomerLedgers() {
    // 1. Ensure EVERY invoice in _invoices has its debit ledger entry
    for (var inv in _invoices) {
      final cleanName = inv.customerName.trim();
      if (cleanName.isEmpty) continue;

      final existingIndex = _ledgerEntries.indexWhere((e) =>
          e.invoiceId == inv.id ||
          e.id == 'L-${inv.id}' ||
          (e.description.isNotEmpty && inv.invoiceNumber.isNotEmpty && e.description == 'Sales Bill ${inv.invoiceNumber}')
      );

      final ledgerItem = LedgerEntry(
        id: 'L-${inv.id}',
        customerName: cleanName,
        date: inv.date,
        description: 'Sales Bill ${inv.invoiceNumber}',
        type: LedgerEntryType.debit,
        amount: inv.grandTotal,
        runningBalance: 0.0,
        invoiceId: inv.id,
        customerPhone: inv.customerPhone.trim().isEmpty ? null : inv.customerPhone.trim(),
      );

      if (existingIndex != -1) {
        _ledgerEntries[existingIndex] = ledgerItem;
      } else {
        _ledgerEntries.add(ledgerItem);
      }
    }

    // 2. Ensure EVERY non-contra Quick Entry has its linked ledger entry
    for (var qe in _quickEntries) {
      if (qe.type != QuickEntryType.contra) {
        final cleanName = qe.partyName.trim();
        if (cleanName.isEmpty) continue;

        final linkedId = 'L-QE-${qe.id}';
        final existingIndex = _ledgerEntries.indexWhere((e) => e.id == linkedId);
        final isReceipt = qe.type == QuickEntryType.receipt;
        final ledgerItem = LedgerEntry(
          id: linkedId,
          customerName: cleanName,
          date: qe.date,
          description: '${qe.type.name.toUpperCase()} (${qe.mode.name.toUpperCase()}) - ${qe.remarks}',
          type: isReceipt ? LedgerEntryType.credit : LedgerEntryType.debit,
          amount: qe.amount,
          runningBalance: 0.0,
        );

        if (existingIndex != -1) {
          _ledgerEntries[existingIndex] = ledgerItem;
        } else {
          _ledgerEntries.add(ledgerItem);
        }
      }
    }

    // 3. Remove orphan invoice debit entries if invoice was deleted
    final validInvoiceIds = _invoices.map((i) => i.id).toSet();
    _ledgerEntries.removeWhere((e) =>
        e.invoiceId != null &&
        e.invoiceId!.isNotEmpty &&
        !validInvoiceIds.contains(e.invoiceId)
    );

    // 4. Remove orphan quick entries if quick entry was deleted
    final validQuickIds = _quickEntries.map((q) => 'L-QE-${q.id}').toSet();
    _ledgerEntries.removeWhere((e) =>
        e.id.startsWith('L-QE-') &&
        !validQuickIds.contains(e.id)
    );

    // 5. Gather all unique customers and calculate clean running balances
    final customers = <String>{};
    for (var entry in _ledgerEntries) {
      if (entry.customerName.trim().isNotEmpty) {
        customers.add(entry.customerName.trim());
      }
    }
    for (var inv in _invoices) {
      if (inv.customerName.trim().isNotEmpty) {
        customers.add(inv.customerName.trim());
      }
    }
    for (var name in customers) {
      _recalculateCustomerLedger(name);
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

  Future<void> removeLedgerEntryById(String id) async {
    _ledgerEntries.removeWhere((e) => e.id == id);
    await _saveAllToPrefs();
  }

  Future<void> addLedgerEntry(LedgerEntry entry) async {
    final existingIndex = _ledgerEntries.indexWhere((e) => e.id == entry.id);
    if (existingIndex != -1) {
      _ledgerEntries[existingIndex] = entry;
    } else {
      _ledgerEntries.add(entry);
    }
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
      if (entry.customerName.trim().isNotEmpty) {
        customers.add(entry.customerName.trim());
      }
    }
    for (var inv in _invoices) {
      if (inv.customerName.trim().isNotEmpty) {
        customers.add(inv.customerName.trim());
      }
    }
    return customers.toList();
  }

  /// Deletes all ledger statements, invoices, and quick entries for a specific customer
  Future<void> deleteLedgerForCustomer(String customerName) async {
    final cleanName = customerName.toLowerCase().trim();
    _ledgerEntries.removeWhere((e) => e.customerName.toLowerCase().trim() == cleanName);
    _invoices.removeWhere((inv) => inv.customerName.toLowerCase().trim() == cleanName);
    _quickEntries.removeWhere((qe) => qe.partyName.toLowerCase().trim() == cleanName);
    await _saveAllToPrefs();
  }

  /// Synchronizes local invoices with cloud snapshot (adds new, updates modified, removes deleted)
  Future<void> syncInvoicesFromCloud(List<Invoice> cloudInvoices) async {
    _invoices.clear();
    _invoices.addAll(cloudInvoices);

    // Remove ledger entries for any bills deleted from cloud
    final cloudInvoiceIds = _invoices.map((i) => i.id).toSet();
    _ledgerEntries.removeWhere((e) =>
        e.invoiceId != null &&
        e.invoiceId!.isNotEmpty &&
        !cloudInvoiceIds.contains(e.invoiceId)
    );

    // Ensure every cloud invoice has its corresponding ledger debit entry
    for (var inv in _invoices) {
      final cleanName = inv.customerName.trim();
      if (cleanName.isEmpty) continue;

      final existingLedger = _ledgerEntries.where((e) =>
          e.invoiceId == inv.id || e.id == 'L-${inv.id}'
      ).firstOrNull;

      if (existingLedger == null) {
        _ledgerEntries.add(LedgerEntry(
          id: 'L-${inv.id}',
          customerName: cleanName,
          date: inv.date,
          description: 'Sales Bill ${inv.invoiceNumber}',
          type: LedgerEntryType.debit,
          amount: inv.grandTotal,
          runningBalance: 0.0,
          invoiceId: inv.id,
          customerPhone: inv.customerPhone.trim().isEmpty ? null : inv.customerPhone.trim(),
        ));
      }
    }

    recalculateAllCustomerLedgers();
    await _saveAllToPrefs();
  }

  /// Synchronizes local ledger entries with cloud snapshot
  Future<void> syncLedgerFromCloud(List<LedgerEntry> cloudLedger) async {
    _ledgerEntries.clear();
    _ledgerEntries.addAll(cloudLedger);
    recalculateAllCustomerLedgers();
    await _saveAllToPrefs();
  }

  /// Synchronizes local quick entries with cloud snapshot
  Future<void> syncQuickEntriesFromCloud(List<QuickEntry> cloudQuick) async {
    _quickEntries.clear();
    _quickEntries.addAll(cloudQuick);
    await _saveAllToPrefs();
  }

  /// Synchronizes local inventory items with cloud snapshot
  Future<void> syncInventoryFromCloud(List<InventoryItem> cloudInventory) async {
    _inventory.clear();
    _inventory.addAll(cloudInventory);
    await _saveAllToPrefs();
  }

  /// Synchronizes local store profile configuration with cloud snapshot
  Future<void> syncStoreProfileFromCloud(String name, String address) async {
    _storeName = name;
    _storeAddress = address;
    if (_prefs != null) {
      await _prefs!.setString('storeName', name);
      await _prefs!.setString('storeAddress', address);
    }
  }

  /// Updates customer details (name, phone) across all ledger entries, invoices, and quick entries
  Future<void> updateCustomerDetails({
    required String oldName,
    required String newName,
    String? phone,
  }) async {
    final cleanOld = oldName.toLowerCase().trim();
    final cleanNew = newName.trim();
    final cleanPhone = phone?.trim().isEmpty == true ? null : phone?.trim();

    // 1. Update ledger entries
    for (int i = 0; i < _ledgerEntries.length; i++) {
      final entry = _ledgerEntries[i];
      if (entry.customerName.toLowerCase().trim() == cleanOld) {
        _ledgerEntries[i] = LedgerEntry(
          id: entry.id,
          customerName: cleanNew,
          date: entry.date,
          description: entry.description,
          type: entry.type,
          amount: entry.amount,
          runningBalance: entry.runningBalance,
          invoiceId: entry.invoiceId,
          customerPhone: cleanPhone ?? entry.customerPhone,
        );
      }
    }

    // 2. Update invoices
    for (int i = 0; i < _invoices.length; i++) {
      final inv = _invoices[i];
      if (inv.customerName.toLowerCase().trim() == cleanOld) {
        _invoices[i] = Invoice(
          id: inv.id,
          invoiceNumber: inv.invoiceNumber,
          customerName: cleanNew,
          customerPhone: cleanPhone ?? inv.customerPhone,
          date: inv.date,
          items: inv.items,
          isPaid: inv.isPaid,
          isSynced: inv.isSynced,
          customerAddress: inv.customerAddress,
          transport: inv.transport,
          lrNo: inv.lrNo,
          siteName: inv.siteName,
          notes: inv.notes,
        );
      }
    }

    // 3. Update quick entries
    for (int i = 0; i < _quickEntries.length; i++) {
      final qe = _quickEntries[i];
      if (qe.partyName.toLowerCase().trim() == cleanOld) {
        _quickEntries[i] = QuickEntry(
          id: qe.id,
          date: qe.date,
          type: qe.type,
          mode: qe.mode,
          partyName: cleanNew,
          amount: qe.amount,
          remarks: qe.remarks,
          isSynced: qe.isSynced,
        );
      }
    }

    _recalculateCustomerLedger(oldName);
    _recalculateCustomerLedger(cleanNew);
    await _saveAllToPrefs();
  }

  /// Get Opening Account entry for customer if exists
  LedgerEntry? getOpeningAccountEntry(String customerName) {
    final cleanName = customerName.toLowerCase().trim();
    for (var entry in _ledgerEntries) {
      if (entry.customerName.toLowerCase().trim() == cleanName &&
          (entry.description == 'Opening Balance' || entry.id.startsWith('L-OP-'))) {
        return entry;
      }
    }
    return null;
  }

  /// Updates or creates opening account for customer
  Future<void> updateOpeningAccount({
    required String customerName,
    required double amount,
    required LedgerEntryType type,
    String? phone,
  }) async {
    final cleanName = customerName.trim();
    final cleanPhone = phone?.trim().isEmpty == true ? null : phone?.trim();
    final existingOp = getOpeningAccountEntry(cleanName);

    if (existingOp != null) {
      final idx = _ledgerEntries.indexWhere((e) => e.id == existingOp.id);
      if (idx != -1) {
        _ledgerEntries[idx] = LedgerEntry(
          id: existingOp.id,
          customerName: cleanName,
          date: existingOp.date,
          description: 'Opening Balance',
          type: type,
          amount: amount,
          runningBalance: 0.0,
          customerPhone: cleanPhone ?? existingOp.customerPhone,
        );
      }
    } else {
      final newOp = LedgerEntry(
        id: 'L-OP-${DateTime.now().millisecondsSinceEpoch}',
        customerName: cleanName,
        date: DateTime.now().subtract(const Duration(days: 365)),
        description: 'Opening Balance',
        type: type,
        amount: amount,
        runningBalance: 0.0,
        customerPhone: cleanPhone,
      );
      _ledgerEntries.add(newOp);
    }

    if (cleanPhone != null) {
      await updateCustomerDetails(oldName: cleanName, newName: cleanName, phone: cleanPhone);
    } else {
      _recalculateCustomerLedger(cleanName);
      await _saveAllToPrefs();
    }
  }

  Future<void> updateLedgerEntry(LedgerEntry updatedEntry) async {
    final idx = _ledgerEntries.indexWhere((e) => e.id == updatedEntry.id);
    if (idx != -1) {
      _ledgerEntries[idx] = updatedEntry;
      _recalculateCustomerLedger(updatedEntry.customerName);
      await _saveAllToPrefs();
    }
  }

  Future<void> updateQuickEntry(QuickEntry updatedEntry) async {
    final idx = _quickEntries.indexWhere((e) => e.id == updatedEntry.id);
    if (idx != -1) {
      _quickEntries[idx] = updatedEntry;

      final linkedLedgerId = 'L-QE-${updatedEntry.id}';
      final lIdx = _ledgerEntries.indexWhere((e) => e.id == linkedLedgerId);
      if (lIdx != -1) {
        final isReceipt = updatedEntry.type == QuickEntryType.receipt;
        _ledgerEntries[lIdx] = LedgerEntry(
          id: linkedLedgerId,
          customerName: updatedEntry.partyName.trim(),
          date: updatedEntry.date,
          description: '${updatedEntry.type.name.toUpperCase()} (${updatedEntry.mode.name.toUpperCase()}) - ${updatedEntry.remarks}',
          type: isReceipt ? LedgerEntryType.credit : LedgerEntryType.debit,
          amount: updatedEntry.amount,
          runningBalance: 0.0,
        );
      }
      _recalculateCustomerLedger(updatedEntry.partyName);
      await _saveAllToPrefs();
    }
  }

  // --- BACKUP / RESTORE / WIPE Methods ---

  Map<String, dynamic> exportAllData() {
    return {
      'version': 2,
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

  /// Robust import with backward compatibility across all past and current app versions
  Future<void> importAllData(Map<String, dynamic> data) async {
    _invoices.clear();
    _ledgerEntries.clear();
    _quickEntries.clear();
    _inventory.clear();

    _storeName = (data['storeName'] ?? data['store_name'] ?? 'HP Bill').toString();
    _storeAddress = (data['storeAddress'] ?? data['store_address'] ?? '').toString();

    // 1. Import Inventory
    final rawInventory = data['inventory'] ?? data['inventory_list'] ?? data['items'] ?? data['products'];
    if (rawInventory is List) {
      for (var item in rawInventory) {
        if (item is Map) {
          _inventory.add(InventoryItem.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    // 2. Import Invoices (Normalizing legacy schemas)
    final rawInvoices = data['invoices'] ?? data['bills'] ?? data['invoices_list'] ?? data['invoice_list'];
    if (rawInvoices is List) {
      for (var item in rawInvoices) {
        if (item is Map) {
          _invoices.add(Invoice.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    // 3. Import Quick Entries (Normalizing legacy schemas)
    final rawQuick = data['quickEntries'] ?? data['quick_entries'] ?? data['quick_entries_list'] ?? data['transactions'];
    if (rawQuick is List) {
      for (var item in rawQuick) {
        if (item is Map) {
          _quickEntries.add(QuickEntry.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    // 4. Import Ledger Entries
    final rawLedger = data['ledgerEntries'] ?? data['ledger_entries'] ?? data['ledger_entries_list'] ?? data['ledger'];
    if (rawLedger is List) {
      for (var item in rawLedger) {
        if (item is Map) {
          _ledgerEntries.add(LedgerEntry.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    // 5. Deduplicate and ensure EVERY invoice has its ledger debit entry if missing
    for (var inv in _invoices) {
      final cleanName = inv.customerName.trim();
      if (cleanName.isEmpty) continue;

      final existingLedger = _ledgerEntries.where((e) =>
          e.invoiceId == inv.id ||
          (e.description.isNotEmpty && inv.invoiceNumber.isNotEmpty && e.description.contains(inv.invoiceNumber)) ||
          e.id == 'L-${inv.id}'
      ).firstOrNull;

      if (existingLedger == null) {
        _ledgerEntries.add(LedgerEntry(
          id: 'L-${inv.id}',
          customerName: cleanName,
          date: inv.date,
          description: 'Sales Bill ${inv.invoiceNumber}',
          type: LedgerEntryType.debit,
          amount: inv.grandTotal,
          runningBalance: 0.0,
          invoiceId: inv.id,
          customerPhone: inv.customerPhone.trim().isEmpty ? null : inv.customerPhone.trim(),
        ));
      }
    }

    // 6. Ensure every Quick Entry has a linked ledger entry if not present
    for (var qe in _quickEntries) {
      if (qe.type != QuickEntryType.contra) {
        final cleanName = qe.partyName.trim();
        if (cleanName.isEmpty) continue;

        final linkedId = 'L-QE-${qe.id}';
        final existingLedger = _ledgerEntries.where((e) => e.id == linkedId).firstOrNull;
        if (existingLedger == null) {
          final isReceipt = qe.type == QuickEntryType.receipt;
          _ledgerEntries.add(LedgerEntry(
            id: linkedId,
            customerName: cleanName,
            date: qe.date,
            description: '${qe.type.name.toUpperCase()} (${qe.mode.name.toUpperCase()}) - ${qe.remarks}',
            type: isReceipt ? LedgerEntryType.credit : LedgerEntryType.debit,
            amount: qe.amount,
            runningBalance: 0.0,
          ));
        }
      }
    }

    // 7. Recalculate all customer running balances with clean double-entry accounting
    recalculateAllCustomerLedgers();

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
