import 'package:flutter_test/flutter_test.dart';
import 'package:hp_bill/models/inventory_item.dart';
import 'package:hp_bill/models/ledger_entry.dart';
import 'package:hp_bill/services/database_helper.dart';
import 'package:hp_bill/services/encryption_service.dart';
import 'package:hp_bill/providers/transaction_provider.dart';
import 'package:hp_bill/providers/invoice_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.instance.init();
    await DatabaseHelper.instance.wipeAllData();
  });

  test('EncryptionService encrypts and decrypts correctly', () {
    final enc = EncryptionService.instance;
    final testData = {
      'customerName': 'Ramesh Kumar',
      'amount': 15000.0,
      'invoiceNumber': 'INV-2026-08-22--0001',
    };

    final encryptedDoc = enc.encryptMap(testData);
    expect(encryptedDoc['_enc'], isTrue);
    expect(encryptedDoc['payload'], isNotNull);
    expect(encryptedDoc['iv'], isNotNull);

    final decryptedDoc = enc.decryptDoc(encryptedDoc);
    expect(decryptedDoc['customerName'], 'Ramesh Kumar');
    expect(decryptedDoc['amount'], 15000.0);
    expect(decryptedDoc['invoiceNumber'], 'INV-2026-08-22--0001');
  });

  test('InventoryItem encryption and decryption with AES-256 works seamlessly', () {
    final enc = EncryptionService.instance;
    final item = InventoryItem(
      id: 'prod-001',
      name: 'HP Synthetic Engine Oil 1L',
      defaultRate: 480.0,
    );

    final encryptedDoc = enc.encryptMap(item.toMap());
    expect(encryptedDoc['_enc'], isTrue);
    expect(encryptedDoc['payload'], isNotNull);

    final decryptedDoc = enc.decryptDoc(encryptedDoc);
    final restoredItem = InventoryItem.fromMap(decryptedDoc);
    expect(restoredItem.id, 'prod-001');
    expect(restoredItem.name, 'HP Synthetic Engine Oil 1L');
    expect(restoredItem.defaultRate, 480.0);
  });

  test('DatabaseHelper and InvoiceProvider synchronize inventory from cloud', () async {
    final db = DatabaseHelper.instance;
    final invProv = InvoiceProvider();

    final cloudProducts = [
      InventoryItem(id: 'p1', name: 'Product Alpha', defaultRate: 100.0),
      InventoryItem(id: 'p2', name: 'Product Beta', defaultRate: 250.0),
    ];

    await db.syncInventoryFromCloud(cloudProducts);
    final localItems = await db.getInventory();
    expect(localItems.length, 2);
    expect(localItems[0].name, 'Product Alpha');
    expect(localItems[1].name, 'Product Beta');

    await invProv.fetchStoreDetails();
    expect(invProv.inventory.length, 2);
    expect(invProv.inventory[0].defaultRate, 100.0);
    expect(invProv.inventory[1].defaultRate, 250.0);
  });

  test('Opening Account with Missed Payment shows in Outstanding; Received / Paid does NOT', () async {
    final db = DatabaseHelper.instance;
    final transProv = TransactionProvider();

    // 1. Customer A: Started account with Missed Payment (Debit ₹5,000)
    await transProv.startOpeningAccount(
      name: 'Aman Missed',
      phone: '9876543210',
      openingAmount: 5000.0,
      type: LedgerEntryType.debit,
    );

    // 2. Customer B: Started account with Received (Credit ₹3,000)
    await transProv.startOpeningAccount(
      name: 'Riya Paid',
      phone: '9812345678',
      openingAmount: 3000.0,
      type: LedgerEntryType.credit,
    );

    final outstanding = transProv.getOutstandingSummaries();
    
    // Only Aman Missed should be in Outstanding (has missed payment / amount due)
    expect(outstanding.length, 1);
    expect(outstanding.first.customerName, 'Aman Missed');
    expect(outstanding.first.balance, 5000.0);
    expect(transProv.totalOutstanding, 5000.0);

    // Both should be in Ledger
    final amanLedger = await db.getLedger('Aman Missed');
    final riyaLedger = await db.getLedger('Riya Paid');
    expect(amanLedger.length, 1);
    expect(riyaLedger.length, 1);
    expect(riyaLedger.first.type, LedgerEntryType.credit);
    expect(riyaLedger.first.amount, 3000.0);
  });
}
