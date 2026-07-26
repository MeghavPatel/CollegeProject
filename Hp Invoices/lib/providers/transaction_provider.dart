import 'package:flutter/material.dart';
import 'package:hp_bill/models/ledger_entry.dart';
import 'package:hp_bill/models/quick_entry.dart';
import 'package:hp_bill/services/database_helper.dart';
import 'package:uuid/uuid.dart';

class OutstandingSummary {
  final String customerName;
  final double balance; // Outstanding balance (Positive for Outstanding/Receivable, Negative for Advance/Payable)
  final DateTime lastTransactionDate;

  OutstandingSummary({
    required this.customerName,
    required this.balance,
    required this.lastTransactionDate,
  });
}

class TransactionProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<QuickEntry> _quickEntries = [];
  List<LedgerEntry> _selectedCustomerLedger = [];
  List<String> _customers = [];
  String? _activeSearchCustomer;
  bool _isLoading = false;

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
    double cash = 15000.0; // Base cash-in-hand balance
    for (var q in _quickEntries) {
      if (q.mode == AccountMode.cash) {
        if (q.type == QuickEntryType.receipt) cash += q.amount;
        if (q.type == QuickEntryType.payment) cash -= q.amount;
      }
    }
    return cash;
  }

  // Load overall quick entries and customer lists
  Future<void> fetchTransactions() async {
    _isLoading = true;
    notifyListeners();

    _quickEntries = await _db.getQuickEntries();
    _quickEntries.sort((a, b) => b.date.compareTo(a.date));
    _customers = await _db.getUniqueCustomers();

    _isLoading = false;
    notifyListeners();
  }

  // Log a cash/bank quick entry
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

    await _db.saveQuickEntry(entry);
    await fetchTransactions(); // Reload metrics

    // If we have an active ledger open for this customer, reload it
    if (_activeSearchCustomer != null &&
        _activeSearchCustomer!.toLowerCase() == partyName.toLowerCase()) {
      await fetchLedger(partyName);
    }

    _isLoading = false;
    notifyListeners();
  }

  // Fetch Ledger statement for a customer
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

  // Calculate Outstandings from REAL ledger data
  List<OutstandingSummary> getOutstandingSummaries() {
    final Map<String, double> balances = {};
    final Map<String, DateTime> dates = {};

    // Build from all ledger entries that exist in DB
    final allData = _db.exportAllData();
    final allEntries = allData['ledgerEntries'] as List<dynamic>? ?? [];
    final allInvoices = allData['invoices'] as List<dynamic>? ?? [];

    for (var entryMap in allEntries) {
      final customerName = entryMap['customerName'] as String? ?? '';
      final amount = (entryMap['amount'] as num?)?.toDouble() ?? 0.0;
      final type = entryMap['type'] as String? ?? 'debit';
      final date = DateTime.tryParse(entryMap['date'] ?? '') ?? DateTime.now();
      final invoiceId = entryMap['invoiceId'] as String?;

      if (!balances.containsKey(customerName)) {
        balances[customerName] = 0.0;
      }

      // Check if this is a paid invoice
      bool isPaidInvoice = false;
      if (invoiceId != null) {
        final invMap = allInvoices.where((inv) => inv['id'] == invoiceId).firstOrNull;
        if (invMap != null && invMap['isPaid'] == 1) {
          isPaidInvoice = true;
        }
      }

      if (type == 'debit') {
        if (!isPaidInvoice) {
          balances[customerName] = balances[customerName]! + amount;
        }
      } else {
        balances[customerName] = balances[customerName]! - amount;
      }

      if (!dates.containsKey(customerName) || date.isAfter(dates[customerName]!)) {
        dates[customerName] = date;
      }
    }

    final List<OutstandingSummary> summaries = [];
    balances.forEach((name, balance) {
      if (balance.abs() > 0.01) {
        summaries.add(OutstandingSummary(
          customerName: name,
          balance: balance,
          lastTransactionDate: dates[name] ?? DateTime.now(),
        ));
      }
    });

    // Sort by balance descending
    summaries.sort((a, b) => b.balance.abs().compareTo(a.balance.abs()));
    return summaries;
  }

  // Delete a quick entry
  Future<void> deleteQuickEntry(String id) async {
    _isLoading = true;
    notifyListeners();

    await _db.deleteQuickEntry(id);
    await fetchTransactions();

    _isLoading = false;
    notifyListeners();
  }

  // Delete the ledger for a customer
  Future<void> deleteLedgerForCustomer(String customerName) async {
    _isLoading = true;
    notifyListeners();

    await _db.deleteLedgerForCustomer(customerName);
    await fetchTransactions(); // Refresh customer lists and quick entries

    if (_activeSearchCustomer != null &&
        _activeSearchCustomer!.toLowerCase() == customerName.toLowerCase()) {
      clearLedgerSearch();
    }

    _isLoading = false;
    notifyListeners();
  }

  // Settle outstanding balance via checkmark tick
  Future<void> settleOutstanding(String customerName, double amount) async {
    _isLoading = true;
    notifyListeners();

    final allInvoices = await _db.getInvoices();
    final customerUnpaidInvoices = allInvoices.where((inv) =>
      inv.customerName.toLowerCase().trim() == customerName.toLowerCase().trim() && !inv.isPaid
    ).toList();

    if (customerUnpaidInvoices.isNotEmpty) {
      // Toggle unpaid invoices to paid status to clear them!
      for (var inv in customerUnpaidInvoices) {
        await _db.toggleInvoicePaymentStatus(inv.id);
      }
    } else {
      // If there are no unpaid invoices, add a generic cash receipt quick entry to settle the balance
      await addQuickEntry(
        type: QuickEntryType.receipt,
        mode: AccountMode.cash,
        partyName: customerName,
        amount: amount,
        remarks: "Settled via Outstanding Tick",
      );
    }

    await fetchTransactions();

    _isLoading = false;
    notifyListeners();
  }

  // Create customer account with opening balance
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
    await fetchTransactions();

    _isLoading = false;
    notifyListeners();
  }
}
