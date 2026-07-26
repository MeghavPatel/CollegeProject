import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hp_bill/models/inventory_item.dart';
import 'package:hp_bill/models/invoice.dart';
import 'package:hp_bill/services/database_helper.dart';
import 'package:hp_bill/services/print_service.dart';
import 'package:hp_bill/services/share_service.dart';
import 'package:uuid/uuid.dart';

class InvoiceProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Invoice> _invoices = [];
  bool _isLoading = false;

  // Store & Profile Configuration
  String _storeName = 'HP Bill';
  String _storeAddress = '';

  // Global Item Inventory
  List<InventoryItem> _inventory = [];

  // Active Invoice form states
  String _activeInvoiceNumber = '';
  String _customerName = '';
  String _customerPhone = '';
  String? _customerAddress;
  String? _transport;
  String? _lrNo;
  String? _siteName;
  List<InvoiceItem> _activeItems = [];
  bool _isPaid = false;

  // Getters
  List<Invoice> get invoices => _invoices;
  bool get isLoading => _isLoading;
  
  String get storeName => _storeName;
  String get storeAddress => _storeAddress;
  List<InventoryItem> get inventory => _inventory;
  
  String get activeInvoiceNumber => _activeInvoiceNumber;
  String get customerName => _customerName;
  String get customerPhone => _customerPhone;
  String? get customerAddress => _customerAddress;
  String? get transport => _transport;
  String? get lrNo => _lrNo;
  String? get siteName => _siteName;
  List<InvoiceItem> get activeItems => _activeItems;
  bool get isPaid => _isPaid;

  double get activeSubtotal => _activeItems.fold(0.0, (sum, item) => sum + item.subtotal);
  double get activeGrandTotal => activeSubtotal;

  // Load store details and inventory
  Future<void> fetchStoreDetails() async {
    final profile = await _db.getStoreProfile();
    _storeName = profile['storeName'] ?? 'HP Bill';
    _storeAddress = profile['storeAddress'] ?? '';
    _inventory = await _db.getInventory();
    notifyListeners();
  }

  // Update and save Store profile details in database
  Future<void> saveStoreProfile(String name, String address) async {
    _isLoading = true;
    notifyListeners();

    await _db.saveStoreProfile(name, address);
    await fetchStoreDetails();

    _isLoading = false;
    notifyListeners();
  }

  // Inventory Management methods (NO TAX RATE)
  Future<void> addInventoryItem(String name, double? rate) async {
    _isLoading = true;
    notifyListeners();

    final newItem = InventoryItem(
      id: const Uuid().v4(),
      name: name,
      defaultRate: rate,
    );

    await _db.saveInventoryItem(newItem);
    await fetchStoreDetails();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateInventoryItem(InventoryItem item) async {
    _isLoading = true;
    notifyListeners();

    await _db.saveInventoryItem(item);
    await fetchStoreDetails();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteInventoryItem(String id) async {
    _isLoading = true;
    notifyListeners();

    await _db.deleteInventoryItem(id);
    await fetchStoreDetails();

    _isLoading = false;
    notifyListeners();
  }

  // Load Invoices from DB/Cache
  Future<void> fetchInvoices() async {
    _isLoading = true;
    notifyListeners();

    _invoices = await _db.getInvoices();
    _invoices.sort((a, b) => b.date.compareTo(a.date));

    _isLoading = false;
    notifyListeners();
  }

  // Initialize a step-by-step invoice creation session
  Future<void> initializeNewInvoice() async {
    _isLoading = true;
    notifyListeners();

    // Reload store profile and inventory
    await fetchStoreDetails();
    _activeInvoiceNumber = await _db.generateNextInvoiceNumber();
    
    // Reset form states
    _customerName = '';
    _customerPhone = '';
    _customerAddress = null;
    _transport = null;
    _lrNo = null;
    _siteName = null;
    _activeItems = [];
    _isPaid = false;

    _isLoading = false;
    notifyListeners();
  }

  // Setters for Form fields
  void setCustomerInfo(String name, String phone) {
    _customerName = name;
    _customerPhone = phone;
    notifyListeners();
  }

  void setCustomerDetails({
    required String name,
    required String phone,
    String? address,
    String? transport,
    String? lrNo,
    String? siteName,
  }) {
    _customerName = name;
    _customerPhone = phone;
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

  // Item list modifiers (NO TAX)
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

  void removeInvoiceItem(String id) {
    _activeItems = List.from(_activeItems)..removeWhere((item) => item.id == id);
    notifyListeners();
  }

  // Save the active invoice session
  Future<Invoice> saveActiveInvoice() async {
    if (_customerName.isEmpty || _activeItems.isEmpty) {
      throw Exception("Customer details or items list cannot be empty.");
    }

    final newInvoice = Invoice(
      id: const Uuid().v4(),
      invoiceNumber: _activeInvoiceNumber,
      customerName: _customerName,
      customerPhone: _customerPhone,
      date: DateTime.now(),
      items: List.from(_activeItems),
      isPaid: _isPaid,
      isSynced: false,
      customerAddress: _customerAddress,
      transport: _transport,
      lrNo: _lrNo,
      siteName: _siteName,
    );

    await _db.saveInvoice(newInvoice);
    await fetchInvoices();
    
    return newInvoice;
  }

  // --- DATA CONTROL ACTIONS ---
  
  Future<void> deleteInvoice(String invoiceId) async {
    _isLoading = true;
    notifyListeners();

    await _db.deleteInvoice(invoiceId);
    await fetchInvoices();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> toggleInvoicePaymentStatus(String invoiceId) async {
    _isLoading = true;
    notifyListeners();

    await _db.toggleInvoicePaymentStatus(invoiceId);
    await fetchInvoices();

    _isLoading = false;
    notifyListeners();
  }

  // --- BACKUP / RESTORE / WIPE ---

  String exportBackupJson() {
    return _db.exportAllDataAsJson();
  }

  Future<void> restoreFromJson(String jsonString) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      await _db.importAllData(data);
      await fetchStoreDetails();
      await fetchInvoices();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw Exception("Invalid backup file format.");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> wipeAllData() async {
    _isLoading = true;
    notifyListeners();

    await _db.wipeAllData();
    _invoices = [];
    _inventory = [];
    _activeItems = [];
    _storeName = 'HP Bill';
    _storeAddress = '';

    _isLoading = false;
    notifyListeners();
  }

  // Action Engines
  Future<void> printInvoice(Invoice invoice) async {
    await PrintService.instance.printInvoice(invoice);
  }

  Future<void> shareInvoice(Invoice invoice) async {
    await ShareService.instance.shareInvoicePdf(invoice);
  }

  Future<void> shareWhatsAppDirect(Invoice invoice) async {
    await ShareService.instance.launchWhatsAppDirect(invoice);
  }
}
