import 'dart:convert';

class InvoiceItem {
  final String id;
  final String name;
  final double quantity;
  final double rate;

  InvoiceItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.rate,
  });

  double get subtotal => quantity * rate;
  double get total => subtotal;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'rate': rate,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      quantity: (map['quantity'] as num).toDouble(),
      rate: (map['rate'] as num).toDouble(),
    );
  }
}

class Invoice {
  final String id;
  final String invoiceNumber;
  final String customerName;
  final String customerPhone;
  final DateTime date;
  final List<InvoiceItem> items;
  final bool isPaid;
  final bool isSynced;
  final String? customerAddress;
  final String? transport;
  final String? lrNo;
  final String? siteName;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.customerName,
    required this.customerPhone,
    required this.date,
    required this.items,
    this.isPaid = false,
    this.isSynced = false,
    this.customerAddress,
    this.transport,
    this.lrNo,
    this.siteName,
  });

  double get subtotal {
    return items.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  double get grandTotal {
    return subtotal;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'date': date.toIso8601String(),
      'items': jsonEncode(items.map((item) => item.toMap()).toList()),
      'isPaid': isPaid ? 1 : 0,
      'isSynced': isSynced ? 1 : 0,
      'customerAddress': customerAddress,
      'transport': transport,
      'lrNo': lrNo,
      'siteName': siteName,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    var itemsList = <InvoiceItem>[];
    if (map['items'] != null) {
      final decoded = jsonDecode(map['items']);
      if (decoded is List) {
        itemsList = decoded.map((itemMap) => InvoiceItem.fromMap(itemMap)).toList();
      }
    }
    return Invoice(
      id: map['id'] ?? '',
      invoiceNumber: map['invoiceNumber'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      date: DateTime.parse(map['date']),
      items: itemsList,
      isPaid: map['isPaid'] == 1,
      isSynced: map['isSynced'] == 1,
      customerAddress: map['customerAddress'],
      transport: map['transport'],
      lrNo: map['lrNo'],
      siteName: map['siteName'],
    );
  }
}
