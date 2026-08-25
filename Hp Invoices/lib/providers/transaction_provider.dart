import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hp_bill/models/ledger_entry.dart';
import 'package:hp_bill/models/quick_entry.dart';
import 'package:hp_bill/services/database_helper.dart';
import 'package:hp_bill/services/firestore_invoice_service.dart';
import 'package:uuid/uuid.dart';

class OutstandingSummary {
  final String customerName;
  final double balance;
  final DateTime lastTransactionDate;

  OutstandingSummary({
    required this.customerName,
    required this.balance,
    required this.lastTransactionDate,
  });
}

class TransactionProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final FirestoreInvoiceService _cloud = FirestoreInvoiceService.instance;

  List<QuickEntry> _quickEntries = [];
  List<LedgerEntry> _selectedCustomerLedger = [];
  List<String> _customers = [];
  String? _activeSearchCustomer;
  bool _isLoading = false;

  // Real-time stream subscriptions
  StreamSubscription? _quickEntryStreamSub;
  StreamSubscription? _ledgerStreamSub;

  // Getters
  List<QuickEntry> get quickEntries => _quickEntries;
  List<LedgerEntry> get selectedCustomerLedger => _selectedCustomerLedger;
  List<String> get customers => _customers;
  String? get activeSearchCustomer => _activeSearchCustomer;
  bool get isLoading => _isLoading;

  // Metrics for Dashboard Quick Summary
  double get totalOutstanding {
    double total = 0;
    final summaries = getOutstandingSummaries();
    for (var s in summaries) {
      if (s.balance > 0) total += s.balance;
    }
    return total;
  }

  double get cashInHand {
    double cash = 15000.0;
    for (var q in _quickEntries) {
      if (q.mode == AccountMode.cash) {
        if (q.type == QuickEntryType.receipt) cash += q.amount;
        if (q.type == QuickEntryType.payment) cash -= q.amount;
      }
    }
    return cash;
  }

  // =====================================================================
  // REAL-TIME SYNC — Listen to Firestore for live updates across phones
  // =====================================================================

  void startRealtimeSync() {
    _quickEntryStreamSub?.cancel();
    _ledgerStreamSub?.cancel();

    if (!_cloud.isAvailable) {
      debugPrint("Firestore not available — skipping transaction real-time sync.");
      return;
    }

    // Stream quick entries from cloud — full reconciliation (adds, updates, deletes)
    _quickEntryStreamSub = _cloud.streamQuickEntries().listen(
      (cloudEntries) async {
        await _db.syncQuickEntriesFromCloud(cloudEntries);

        _quickEntries = await _db.getQuickEntries();
        _quickEntries.sort((a, b) => b.date.compareTo(a.date));
        _customers = await _db.getUniqueCustomers();
        notifyListeners();
      },
      onError: (e) => debugPrint("QuickEntry stream error: $e"),
    );

    // Stream ledger entries from cloud — full reconciliation (adds, updates, deletes)
    _ledgerStreamSub = _cloud.streamLedgerEntries().listen(
      (cloudLedger) async {
        await _db.syncLedgerFromCloud(cloudLedger);

        _customers = await _db.getUniqueCustomers();
        if (_activeSearchCustomer != null) {
          _selectedCustomerLedger = await _db.getLedger(_activeSearchCustomer!);
        }
        notifyListeners();
      },
      onError: (e) => debugPrint("Ledger stream error: $e"),
    );

    debugPrint("Real-time transaction sync started.");
  }

  void pauseRealtimeSync() {
    _quickEntryStreamSub?.cancel();
    _ledgerStreamSub?.cancel();
  }

  @override
  void dispose() {
    _quickEntryStreamSub?.cancel();
    _ledgerStreamSub?.cancel();
    super.dispose();
  }

  // =====================================================================
  // FETCH TRANSACTIONS
  // =====================================================================

  Future<void> fetchTransactions() async {
    _isLoading = true;
    notifyListeners();

    _quickEntries = await _db.getQuickEntries();
    _quickEntries.sort((a, b) => b.date.compareTo(a.date));
    _customers = await _db.getUniqueCustomers();

    _isLoading = false;
    notifyListeners();
  }

  // =====================================================================
  // QUICK ENTRY (Cash/Bank) — Local + Cloud
  // =====================================================================

  Future<void> addQuickEntry({
    required QuickEntryType type,
    required AccountMode mode,
    required String partyName,
    required double amount,
    required String remarks,
  }) async {
    _isLoading = true;
    notifyListeners();

    final entry = QuickEntry(
      id: const Uuid().v4(),
      date: DateTime.now(),
      type: type,
      mode: mode,
      partyName: partyName,
      amount: amount,
      remarks: remarks,
      isSynced: false,
    );

    // Save locally
    await _db.saveQuickEntry(entry);

    // Sync to cloud (other phones will see this instantly via stream)
    try {
      await _cloud.saveQuickEntry(entry);
    } catch (e) {
      debugPrint("Cloud quick entry save notice: $e");
    }

    await fetchTransactions();

    if (_activeSearchCustomer != null &&
        _activeSearchCustomer!.toLowerCase() == partyName.toLowerCase()) {
      await fetchLedger(partyName);
    }

    _isLoading = false;
    notifyListeners();
  }

  // =====================================================================
  // LEDGER
  // =====================================================================

  Future<void> fetchLedger(String customerName) async {
    _isLoading = true;
    _activeSearchCustomer = customerName;
    notifyListeners();

    _selectedCustomerLedger = await _db.getLedger(customerName);

    _isLoading = false;
    notifyListeners();
  }

  void clearLedgerSearch() {
    _selectedCustomerLedger = [];
    _activeSearchCustomer = null;
    notifyListeners();
  }

  // =====================================================================
  // OUTSTANDING SUMMARIES
  // =====================================================================

  List<OutstandingSummary> getOutstandingSummaries() {
    final Map<String, double> balances = {};
    final Map<String, DateTime> dates = {};

    final allData = _db.exportAllData();
    final allEntries = allData['ledgerEntries'] as List<dynamic>? ?? [];

    for (var entryMap in allEntries) {
      final customerName = (entryMap['customerName'] ?? entryMap['customer_name'] ?? '').toString().trim();
      if (customerName.isEmpty) continue;

      final amount = (entryMap['amount'] as num?)?.toDouble() ?? 0.0;
      final type = (entryMap['type'] ?? 'debit').toString().toLowerCase();
      final date = DateTime.tryParse(entryMap['date']?.toString() ?? '') ?? DateTime.now();

      if (!balances.containsKey(customerName)) {
        balances[customerName] = 0.0;
      }

      if (type == 'debit') {
        balances[customerName] = balances[customerName]! + amount;
      } else {
        balances[customerName] = balances[customerName]! - amount;
      }

      if (!dates.containsKey(customerName) || date.isAfter(dates[customerName]!)) {
        dates[customerName] = date;
      }
    }

    final List<OutstandingSummary> summaries = [];
    balances.forEach((name, balance) {
      // Only show customers who owe money (unpaid / missed payments) in Outstanding
      if (balance > 0.01) {
        summaries.add(OutstandingSummary(
          customerName: name,
          balance: balance,
          lastTransactionDate: dates[name] ?? DateTime.now(),
        ));
      }
    });

    summaries.sort((a, b) => b.balance.compareTo(a.balance));
    return summaries;
  }

  // =====================================================================
  // DELETE OPERATIONS — Local + Cloud
  // =====================================================================

  Future<void> deleteQuickEntry(String id) async {
    _isLoading = true;
    notifyListeners();

    await _db.deleteQuickEntry(id);

    // Delete from cloud too
    try {
      await _cloud.deleteQuickEntry(id);
    } catch (e) {
      debugPrint("Cloud quick entry delete notice: $e");
    }

    await fetchTransactions();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteLedgerForCustomer(String customerName) async {
    _isLoading = true;
    notifyListeners();

    // 1. Delete locally from db
    await _db.deleteLedgerForCustomer(customerName);
    _db.recalculateAllCustomerLedgers();

    // 2. Delete from cloud
    try {
      await _cloud.deleteLedgerForCustomer(customerName);
    } catch (e) {
      debugPrint("Cloud ledger delete notice: $e");
    }

    // 3. Refresh local transactions & state
    await fetchTransactions();

    if (_activeSearchCustomer != null &&
        _activeSearchCustomer!.toLowerCase() == customerName.toLowerCase()) {
      clearLedgerSearch();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteLedgerEntry(String entryId, String customerName) async {
    _isLoading = true;
    notifyListeners();

    // 1. Remove from local DB
    await _db.removeLedgerEntryById(entryId);
    _db.recalculateAllCustomerLedgers();

    // 2. Delete from cloud
    try {
      await _cloud.deleteLedgerEntry(entryId);
    } catch (e) {
      debugPrint("Cloud delete ledger entry notice: $e");
    }

    // 3. Refresh local transactions & active ledger
    await fetchTransactions();
    if (_activeSearchCustomer != null &&
        _activeSearchCustomer!.toLowerCase() == customerName.toLowerCase()) {
      await fetchLedger(customerName);
    }

    _isLoading = false;
    notifyListeners();
  }

  // =====================================================================
  // SETTLE OUTSTANDING
  // =====================================================================

  Future<void> settleOutstanding(String customerName, double amount) async {
    _isLoading = true;
    notifyListeners();

    // 1. Add credit receipt entry so ledger reflects settlement
    await addQuickEntry(
      type: QuickEntryType.receipt,
      mode: AccountMode.cash,
      partyName: customerName,
      amount: amount,
      remarks: "Settled via Outstanding Tick",
    );

    // 2. Mark any unpaid invoices for this customer as paid
    final allInvoices = await _db.getInvoices();
    final customerUnpaidInvoices = allInvoices.where((inv) =>
      inv.customerName.toLowerCase().trim() == customerName.toLowerCase().trim() && !inv.isPaid
    ).toList();

    for (var inv in customerUnpaidInvoices) {
      await _db.toggleInvoicePaymentStatus(inv.id);
      try {
        await _cloud.updatePaymentStatus(inv.id, true);
      } catch (e) {
        debugPrint("Cloud payment status notice: $e");
      }
    }

    await fetchTransactions();

    _isLoading = false;
    notifyListeners();
  }

  // =====================================================================
  // ACCOUNT MANAGEMENT — Local + Cloud
  // =====================================================================

  Future<void> startOpeningAccount({
    required String name,
    required String phone,
    required double openingAmount,
    required LedgerEntryType type,
  }) async {
    _isLoading = true;
    notifyListeners();

    final entry = LedgerEntry(
      id: 'L-OP-${const Uuid().v4()}',
      customerName: name.trim(),
      date: DateTime.now().subtract(const Duration(seconds: 5)),
      description: 'Opening Balance',
      type: type,
      amount: openingAmount,
      runningBalance: 0.0,
      customerPhone: phone.trim().isEmpty ? null : phone.trim(),
    );

    await _db.addLedgerEntry(entry);

    // Sync to cloud
    try {
      await _cloud.saveLedgerEntry(entry);
    } catch (e) {
      debugPrint("Cloud ledger save notice: $e");
    }

    await fetchTransactions();

    _isLoading = false;
    notifyListeners();
  }

  Future<String?> getCustomerPhone(String customerName) async {
    return await _db.getCustomerPhone(customerName);
  }

  LedgerEntry? getOpeningAccountEntry(String customerName) {
    return _db.getOpeningAccountEntry(customerName);
  }

  Future<void> updateCustomerDetails({
    required String oldName,
    required String newName,
    String? phone,
  }) async {
    _isLoading = true;
    notifyListeners();

    await _db.updateCustomerDetails(oldName: oldName, newName: newName, phone: phone);
    await fetchTransactions();

    if (_activeSearchCustomer != null &&
        _activeSearchCustomer!.toLowerCase().trim() == oldName.toLowerCase().trim()) {
      await fetchLedger(newName);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateOpeningAccount({
    required String customerName,
    required double amount,
    required LedgerEntryType type,
    String? phone,
  }) async {
    _isLoading = true;
    notifyListeners();

    await _db.updateOpeningAccount(
      customerName: customerName,
      amount: amount,
      type: type,
      phone: phone,
    );

    // Sync updated opening account to Cloud
    final updatedOp = _db.getOpeningAccountEntry(customerName);
    if (updatedOp != null) {
      try {
        await _cloud.saveLedgerEntry(updatedOp);
      } catch (e) {
        debugPrint("Cloud opening account update notice: $e");
      }
    }

    await fetchTransactions();

    if (_activeSearchCustomer != null &&
        _activeSearchCustomer!.toLowerCase().trim() == customerName.toLowerCase().trim()) {
      await fetchLedger(customerName);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateLedgerEntry(LedgerEntry entry) async {
    _isLoading = true;
    notifyListeners();

    await _db.updateLedgerEntry(entry);

    // Sync to cloud
    try {
      await _cloud.updateLedgerEntry(entry);
    } catch (e) {
      debugPrint("Cloud ledger update notice: $e");
    }

    await fetchTransactions();

    if (_activeSearchCustomer != null &&
        _activeSearchCustomer!.toLowerCase().trim() == entry.customerName.toLowerCase().trim()) {
      await fetchLedger(entry.customerName);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateQuickEntry(QuickEntry entry) async {
    _isLoading = true;
    notifyListeners();

    await _db.updateQuickEntry(entry);

    // Sync to cloud
    try {
      await _cloud.updateQuickEntry(entry);
    } catch (e) {
      debugPrint("Cloud quick entry update notice: $e");
    }

    await fetchTransactions();

    if (_activeSearchCustomer != null &&
        _activeSearchCustomer!.toLowerCase().trim() == entry.partyName.toLowerCase().trim()) {
      await fetchLedger(entry.partyName);
    }

    _isLoading = false;
    notifyListeners();
  }
}
