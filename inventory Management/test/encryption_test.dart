import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hp/src/core/services/encryption_service.dart';
import 'package:hp/src/core/models/models.dart';

// ignore: subtype_of_sealed_class
class FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic>? _data;

  FakeDocumentSnapshot(this.id, this._data);

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic get(Object field) => _data?[field];

  @override
  dynamic operator [](Object field) => _data?[field];

  @override
  bool get exists => _data != null;

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  DocumentReference<Map<String, dynamic>> get reference => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EncryptionService Unit Tests', () {
    final enc = EncryptionService.instance;

    test('AES-256 Encrypts and Decrypts Dart Map accurately', () {
      final sampleData = {
        'name': 'Praveen Sharma',
        'salary': 35000.0,
        'role': 'Machine Operator',
        'phoneNumber': '9876543210',
        'advanceTaken': 5000.0,
      };

      final encryptedDoc = enc.encryptMap(sampleData);

      // Verify encrypted metadata
      expect(encryptedDoc['_enc'], isTrue);
      expect(encryptedDoc['_v'], 1);
      expect(encryptedDoc['payload'], isNotNull);
      expect(encryptedDoc['iv'], isNotNull);
      expect(encryptedDoc['payload'] != sampleData['name'], isTrue);

      // Decrypt
      final decryptedDoc = enc.decryptDoc(encryptedDoc);
      expect(decryptedDoc['name'], 'Praveen Sharma');
      expect(decryptedDoc['salary'], 35000.0);
      expect(decryptedDoc['role'], 'Machine Operator');
      expect(decryptedDoc['phoneNumber'], '9876543210');
      expect(decryptedDoc['advanceTaken'], 5000.0);
    });

    test('Preserves query index fields at top level for Firestore queries', () {
      final paymentData = {
        'employeeId': 'emp_12345',
        'amount': 12500.0,
        'type': 'Advance',
        'note': 'Emergency Medical advance',
        'paymentDate': '2026-08-25T10:00:00.000',
      };

      final encrypted = enc.encryptMap(paymentData);
      expect(encrypted['employeeId'], 'emp_12345');
      expect(encrypted['paymentDate'], '2026-08-25T10:00:00.000');
      expect(encrypted['_enc'], isTrue);

      final decrypted = enc.decryptDoc(encrypted);
      expect(decrypted['amount'], 12500.0);
      expect(decrypted['note'], 'Emergency Medical advance');
      expect(decrypted['type'], 'Advance');
    });

    test('Gracefully returns raw map for legacy unencrypted documents (Zero Data Loss)', () {
      final legacyUnencryptedData = {
        'itemName': 'Steel Sheet 3mm',
        'currentQuantity': 150.0,
        'lastUpdated': '2026-08-20T12:00:00.000',
      };

      final decrypted = enc.decryptDoc(legacyUnencryptedData);
      expect(decrypted['itemName'], 'Steel Sheet 3mm');
      expect(decrypted['currentQuantity'], 150.0);
    });

    test('Encrypts and Decrypts standalone strings with IV', () {
      const plainSecret = "Confidential business invoice secret message 2026";
      final encrypted = enc.encryptText(plainSecret);
      expect(encrypted.contains(':'), isTrue);
      expect(encrypted, isNot(equals(plainSecret)));

      final decrypted = enc.decryptText(encrypted);
      expect(decrypted, equals(plainSecret));
    });
  });

  group('Model Deserialization with AES-256 Encrypted Firestore Documents', () {
    final enc = EncryptionService.instance;

    test('EmployeeProfile from encrypted Firestore snapshot', () {
      final raw = {
        'name': 'Ramesh Bhai',
        'role': 'Supervisor',
        'salary': 45000.0,
        'phoneNumber': '9988776655',
        'joinedDate': '2026-01-15T09:00:00.000Z',
        'advanceTaken': 2000.0,
      };

      final encrypted = enc.encryptMap(raw);
      final fakeDoc = FakeDocumentSnapshot('emp_001', encrypted);

      final emp = EmployeeProfile.fromFirestore(fakeDoc);
      expect(emp.id, 'emp_001');
      expect(emp.name, 'Ramesh Bhai');
      expect(emp.role, 'Supervisor');
      expect(emp.salary, 45000.0);
      expect(emp.phoneNumber, '9988776655');
      expect(emp.advanceTaken, 2000.0);
      expect(emp.netPayableSalary, 43000.0);
    });

    test('ExpenseEntry from encrypted Firestore snapshot', () {
      final raw = {
        'title': 'Factory Diesel & Generator Oil',
        'amount': 8400.0,
        'category': 'Operations',
        'account': 'Cash',
        'note': 'Monthly generator refuel',
        'date': '2026-08-22T14:30:00.000Z',
      };

      final encrypted = enc.encryptMap(raw);
      final fakeDoc = FakeDocumentSnapshot('exp_001', encrypted);

      final expense = ExpenseEntry.fromFirestore(fakeDoc);
      expect(expense.id, 'exp_001');
      expect(expense.title, 'Factory Diesel & Generator Oil');
      expect(expense.amount, 8400.0);
      expect(expense.category, 'Operations');
      expect(expense.account, 'Cash');
      expect(expense.note, 'Monthly generator refuel');
    });

    test('StockItem and StockVariant from encrypted Firestore snapshots', () {
      final itemRaw = {
        'itemName': 'Aluminium Coils Grade A',
        'serialNumber': 'SN-AL-9981',
        'length': 2400.0,
        'width': 1200.0,
        'thickness': 5.0,
        'thicknessUnit': 'mm',
        'currentQuantity': 85.0,
        'lastUpdated': '2026-08-24T18:00:00.000Z',
      };

      final itemEncrypted = enc.encryptMap(itemRaw);
      final fakeItemDoc = FakeDocumentSnapshot('stock_001', itemEncrypted);

      final stockItem = StockItem.fromFirestore(fakeItemDoc);
      expect(stockItem.id, 'stock_001');
      expect(stockItem.itemName, 'Aluminium Coils Grade A');
      expect(stockItem.serialNumber, 'SN-AL-9981');
      expect(stockItem.thickness, 5.0);
      expect(stockItem.currentQuantity, 85.0);

      final variantRaw = {
        'thickness': 5.0,
        'length': 2400.0,
        'width': 1200.0,
        'currentStock': 35.0,
        'lastUpdated': '2026-08-24T18:00:00.000Z',
      };

      final variantEncrypted = enc.encryptMap(variantRaw);
      final fakeVarDoc = FakeDocumentSnapshot('var_001', variantEncrypted);

      final variant = StockVariant.fromFirestore(fakeVarDoc);
      expect(variant.id, 'var_001');
      expect(variant.currentStock, 35.0);
      expect(variant.thickness, 5.0);
    });

    test('Transporter and TransportPayment from encrypted Firestore snapshots', () {
      final transRaw = {
        'name': 'Gujarat Rajasthan Roadways',
        'createdAt': '2026-02-01T10:00:00.000Z',
      };

      final transEncrypted = enc.encryptMap(transRaw);
      final fakeTransDoc = FakeDocumentSnapshot('trans_001', transEncrypted);

      final transporter = Transporter.fromFirestore(fakeTransDoc);
      expect(transporter.id, 'trans_001');
      expect(transporter.name, 'Gujarat Rajasthan Roadways');

      final payRaw = {
        'transporterId': 'trans_001',
        'amount': 18500.0,
        'note': 'Freight charge Ahmedabad to Surat',
        'date': '2026-08-25T11:00:00.000Z',
      };

      final payEncrypted = enc.encryptMap(payRaw);
      final fakePayDoc = FakeDocumentSnapshot('tpay_001', payEncrypted);

      final payment = TransportPayment.fromFirestore(fakePayDoc);
      expect(payment.id, 'tpay_001');
      expect(payment.transporterId, 'trans_001');
      expect(payment.amount, 18500.0);
      expect(payment.note, 'Freight charge Ahmedabad to Surat');
    });

    test('ChaiWalaLedgerEntry from encrypted Firestore snapshots', () {
      final ledgerRaw = {
        'type': 'DEPOSIT',
        'amount': 2000.0,
        'note': 'Monthly canteen advance deposit',
        'date': '2026-08-01T08:00:00.000Z',
      };

      final ledgerEncrypted = enc.encryptMap(ledgerRaw);
      final fakeLedgerDoc = FakeDocumentSnapshot('chai_001', ledgerEncrypted);

      final entry = ChaiWalaLedgerEntry.fromFirestore(fakeLedgerDoc);
      expect(entry.id, 'chai_001');
      expect(entry.type, 'DEPOSIT');
      expect(entry.amount, 2000.0);
      expect(entry.note, 'Monthly canteen advance deposit');
    });
  });
}
