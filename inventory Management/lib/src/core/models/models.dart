import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeProfile {
  final String id;
  final String name;
  final String? role;
  final double salary;
  final String phoneNumber;
  final DateTime joinedDate;
  final double advanceTaken;

  EmployeeProfile({
    required this.id,
    required this.name,
    this.role,
    this.salary = 0.0,
    this.phoneNumber = '',
    required this.joinedDate,
    this.advanceTaken = 0.0,
  });

  double get netPayableSalary => salary - advanceTaken;

  factory EmployeeProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmployeeProfile(
      id: doc.id,
      name: data['name'] ?? '',
      role: data['role'],
      salary: (data['salary'] ?? 0.0).toDouble(),
      phoneNumber: data['phoneNumber'] ?? '',
      joinedDate: (data['joinedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      advanceTaken: (data['advanceTaken'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'role': role,
      'salary': salary,
      'phoneNumber': phoneNumber,
      'joinedDate': Timestamp.fromDate(joinedDate),
      'advanceTaken': advanceTaken,
    };
  }
}

class ExpenseEntry {
  final String id;
  final String title;
  final double amount;
  final String category;
  final String? account;
  final String? note;
  final DateTime date;

  ExpenseEntry({
    required this.id, required this.title, required this.amount, 
    required this.category, this.account, this.note, required this.date
  });

  factory ExpenseEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExpenseEntry(
      id: doc.id,
      title: data['title'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      category: data['category'] ?? '',
      account: data['account'],
      note: data['note'],
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'category': category,
      'account': account,
      'note': note,
      'date': Timestamp.fromDate(date),
    };
  }
}

class Transporter {
  final String id;
  final String name;
  final DateTime createdAt;

  Transporter({required this.id, required this.name, required this.createdAt});

  factory Transporter.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Transporter(
      id: doc.id,
      name: data['name'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class TransportPayment {
  final String id;
  final String transporterId;
  final double amount;
  final String? note;
  final DateTime date;

  TransportPayment({
    required this.id, required this.transporterId, required this.amount, 
    this.note, required this.date
  });

  factory TransportPayment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransportPayment(
      id: doc.id,
      transporterId: data['transporterId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      note: data['note'],
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'transporterId': transporterId,
      'amount': amount,
      'note': note,
      'date': Timestamp.fromDate(date),
    };
  }
}

class TransporterWithBalance {
  final Transporter transporter;
  final double totalAmount;

  TransporterWithBalance({required this.transporter, required this.totalAmount});
}

class StockItem {
  final String id;
  final String itemName;
  final String? serialNumber;
  final double? length;
  final double? width;
  final double? thickness;
  final String? thicknessUnit;
  final double currentQuantity;
  final DateTime lastUpdated;

  StockItem({
    required this.id, required this.itemName, this.serialNumber,
    this.length, this.width, this.thickness, this.thicknessUnit,
    required this.currentQuantity, required this.lastUpdated
  });

  factory StockItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StockItem(
      id: doc.id,
      itemName: data['itemName'] ?? '',
      serialNumber: data['serialNumber'],
      length: (data['length'])?.toDouble(),
      width: (data['width'])?.toDouble(),
      thickness: (data['thickness'])?.toDouble(),
      thicknessUnit: data['thicknessUnit'] ?? 'mm',
      currentQuantity: (data['currentQuantity'] ?? 0).toDouble(),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemName': itemName,
      'serialNumber': serialNumber,
      'length': length,
      'width': width,
      'thickness': thickness,
      'thicknessUnit': thicknessUnit ?? 'mm',
      'currentQuantity': currentQuantity,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}

class StockLog {
  final String id;
  final String itemId;
  final String? variantId;
  final String type;
  final double quantityChange;
  final DateTime date;
  final String? note;

  StockLog({
    required this.id, required this.itemId, this.variantId, required this.type,
    required this.quantityChange, required this.date, this.note
  });

  factory StockLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StockLog(
      id: doc.id,
      itemId: data['itemId'] ?? '',
      variantId: data['variantId'],
      type: data['type'] ?? '',
      quantityChange: (data['quantityChange'] ?? 0).toDouble(),
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: data['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'variantId': variantId,
      'type': type,
      'quantityChange': quantityChange,
      'date': Timestamp.fromDate(date),
      'note': note,
    };
  }
}

class ActivityLog {
  final String id;
  final String moduleName;
  final String description;
  final DateTime timestamp;

  ActivityLog({
    required this.id, required this.moduleName, 
    required this.description, required this.timestamp
  });

  factory ActivityLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActivityLog(
      id: doc.id,
      moduleName: data['moduleName'] ?? '',
      description: data['description'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'moduleName': moduleName,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class SalaryPayment {
  final String id;
  final String employeeId;
  final double amount;
  final String? note;
  final DateTime paymentDate;
  final String type;
  final double? overtimeBonus;

  SalaryPayment({
    required this.id, required this.employeeId, required this.amount,
    this.note, required this.paymentDate,
    this.type = 'Salary',
    this.overtimeBonus,
  });

  factory SalaryPayment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SalaryPayment(
      id: doc.id,
      employeeId: data['employeeId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      note: data['note'],
      paymentDate: (data['paymentDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: data['type'] ?? 'Salary',
      overtimeBonus: (data['overtimeBonus'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'amount': amount,
      'note': note,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'type': type,
      'overtimeBonus': overtimeBonus,
    };
  }
}

class EmployeeAttendanceData {
  final String id;
  final String employeeId;
  final DateTime date;
  final String status;
  final String? checkIn;
  final String? checkOut;

  EmployeeAttendanceData({
    required this.id, required this.employeeId, 
    required this.date, required this.status,
    this.checkIn, this.checkOut
  });

  factory EmployeeAttendanceData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmployeeAttendanceData(
      id: doc.id,
      employeeId: data['employeeId'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'Present',
      checkIn: data['checkIn'],
      checkOut: data['checkOut'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'date': Timestamp.fromDate(date),
      'status': status,
      'checkIn': checkIn,
      'checkOut': checkOut,
    };
  }
}

class CompanyProfile {
  final String id;
  final String companyName;
  final String? contactNumber;
  final DateTime createdAt;

  CompanyProfile({
    required this.id, required this.companyName, 
    this.contactNumber, required this.createdAt
  });

  factory CompanyProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CompanyProfile(
      id: doc.id,
      companyName: data['companyName'] ?? '',
      contactNumber: data['contactNumber'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyName': companyName,
      'contactNumber': contactNumber,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class CompanyProduct {
  final String id;
  final String companyId;
  final String productName;
  final String? serialNumber;
  final double price;
  final DateTime lastUpdated;

  CompanyProduct({
    required this.id, required this.companyId, required this.productName,
    this.serialNumber, required this.price, required this.lastUpdated
  });

  factory CompanyProduct.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CompanyProduct(
      id: doc.id,
      companyId: data['companyId'] ?? '',
      productName: data['productName'] ?? '',
      serialNumber: data['serialNumber'],
      price: (data['price'] ?? 0).toDouble(),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'productName': productName,
      'serialNumber': serialNumber,
      'price': price,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}

class CompanyTransaction {
  final String id;
  final String companyId;
  final String transactionType;
  final String itemName;
  final double quantity;
  final double amount;
  final String? note;
  final DateTime transactionDate;

  CompanyTransaction({
    required this.id, required this.companyId, required this.transactionType,
    required this.itemName, required this.quantity, required this.amount,
    this.note, required this.transactionDate
  });

  factory CompanyTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CompanyTransaction(
      id: doc.id,
      companyId: data['companyId'] ?? '',
      transactionType: data['transactionType'] ?? '',
      itemName: data['itemName'] ?? '',
      quantity: (data['quantity'] ?? 0).toDouble(),
      amount: (data['amount'] ?? 0).toDouble(),
      note: data['note'],
      transactionDate: (data['transactionDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'transactionType': transactionType,
      'itemName': itemName,
      'quantity': quantity,
      'amount': amount,
      'note': note,
      'transactionDate': Timestamp.fromDate(transactionDate),
    };
  }
}

class StockVariant {
  final String id;
  final double? thickness;
  final double? length;
  final double? width;
  final double currentStock;
  final DateTime lastUpdated;

  StockVariant({
    required this.id,
    this.thickness,
    this.length,
    this.width,
    required this.currentStock,
    required this.lastUpdated,
  });

  factory StockVariant.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StockVariant(
      id: doc.id,
      thickness: (data['thickness'])?.toDouble(),
      length: (data['length'])?.toDouble(),
      width: (data['width'])?.toDouble(),
      currentStock: (data['currentStock'] ?? 0).toDouble(),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'thickness': thickness,
      'length': length,
      'width': width,
      'currentStock': currentStock,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}

class ChaiWalaLedgerEntry {
  final String id;
  final String type; // 'DEPOSIT' or 'EXPENSE'
  final double amount;
  final String? note;
  final DateTime date;

  ChaiWalaLedgerEntry({
    required this.id,
    required this.type,
    required this.amount,
    this.note,
    required this.date,
  });

  factory ChaiWalaLedgerEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChaiWalaLedgerEntry(
      id: doc.id,
      type: data['type'] ?? 'EXPENSE',
      amount: (data['amount'] ?? 0).toDouble(),
      note: data['note'],
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'amount': amount,
      'note': note,
      'date': Timestamp.fromDate(date),
    };
  }
}
