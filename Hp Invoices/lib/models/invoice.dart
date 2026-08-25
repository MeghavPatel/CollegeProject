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
      'title': name,
      'quantity': quantity,
      'qty': quantity,
      'rate': rate,
      'amount': total,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id']?.toString() ?? '',
      name: (map['name'] ?? map['title'] ?? map['description'] ?? map['itemName'] ?? '').toString(),
      quantity: ((map['quantity'] ?? map['qty'] ?? map['qnt'] ?? 1) as num).toDouble(),
      rate: ((map['rate'] ?? map['price'] ?? map['unitPrice'] ?? 0) as num).toDouble(),
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
  final String? customerEmail;
  final String? transport;
  final String? lrNo;
  final String? siteName;
  final String? notes;
  final double tax;
  final double discount;

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
    this.customerEmail,
    this.transport,
    this.lrNo,
    this.siteName,
    this.notes,
    this.tax = 0.0,
    this.discount = 0.0,
  });

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.subtotal);

  double get grandTotal {
    final result = subtotal + tax - discount;
    return result < 0 ? 0 : result;
  }

  String get paymentStatus => isPaid ? 'paid' : 'unpaid';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'date': date.toIso8601String(),
      'items': jsonEncode(items.map((item) => item.toMap()).toList()),
      'isPaid': isPaid ? 1 : 0,
      'isSynced': isSynced ? 1 : 0,
      'customerAddress': customerAddress,
      'transport': transport,
      'lrNo': lrNo,
      'siteName': siteName,
      'notes': notes,
      'tax': tax,
      'discount': discount,
      'subtotal': subtotal,
      'grandTotal': grandTotal,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    var itemsList = <InvoiceItem>[];
    if (map['items'] != null) {
      dynamic rawItems = map['items'];
      if (rawItems is String) {
        try {
          rawItems = jsonDecode(rawItems);
        } catch (_) {
          rawItems = [];
        }
      }
      if (rawItems is List) {
        itemsList = rawItems.map((itemMap) {
          if (itemMap is Map) {
            return InvoiceItem.fromMap(Map<String, dynamic>.from(itemMap));
          }
          return InvoiceItem(id: '', name: itemMap.toString(), quantity: 1, rate: 0);
        }).toList();
      }
    }

    final String name = (map['customerName'] ?? map['customer_name'] ?? map['partyName'] ??
        (map['customer'] is Map ? map['customer']['name'] : null) ?? '').toString();
    final String phone = (map['customerPhone'] ?? map['customer_phone'] ??
        (map['customer'] is Map ? map['customer']['phone'] : null) ?? '').toString();
    final String? address = map['customerAddress']?.toString() ?? map['customer_address']?.toString() ??
        (map['customer'] is Map ? map['customer']['address']?.toString() : null);
    final String? email = map['customerEmail']?.toString() ?? map['customer_email']?.toString() ??
        (map['customer'] is Map ? map['customer']['email']?.toString() : null);

    final rawPaid = map['isPaid'] ?? map['is_paid'] ?? map['paymentStatus'] ?? map['payment_status'] ?? map['status'];
    final isPaidVal = rawPaid == true || rawPaid == 1 || rawPaid == '1' || rawPaid == 'true' || rawPaid == 'paid';

    DateTime parsedDate = DateTime.now();
    if (map['date'] != null) {
      parsedDate = DateTime.tryParse(map['date'].toString()) ?? DateTime.now();
    } else if (map['createdAt'] != null) {
      parsedDate = DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now();
    } else if (map['created_at'] != null) {
      parsedDate = DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now();
    }

    final invId = (map['id'] ?? map['invoiceId'] ?? map['invoice_id'] ?? '').toString();
    final invNum = (map['invoiceNumber'] ?? map['invoice_number'] ?? map['billNumber'] ?? map['bill_no'] ?? invId).toString();

    return Invoice(
      id: invId.isNotEmpty ? invId : invNum,
      invoiceNumber: invNum.isNotEmpty ? invNum : invId,
      customerName: name,
      customerPhone: phone,
      customerAddress: address,
      customerEmail: email,
      date: parsedDate,
      items: itemsList,
      isPaid: isPaidVal,
      isSynced: map['isSynced'] == true || map['isSynced'] == 1 || map['is_synced'] == 1,
      transport: map['transport']?.toString(),
      lrNo: map['lrNo']?.toString() ?? map['lr_no']?.toString(),
      siteName: map['siteName']?.toString() ?? map['site_name']?.toString(),
      notes: map['notes']?.toString(),
      tax: ((map['tax'] ?? map['taxAmount'] ?? map['vat'] ?? 0.0) as num).toDouble(),
      discount: ((map['discount'] ?? map['discountAmount'] ?? 0.0) as num).toDouble(),
    );
  }

  // Map representation specifically for Firestore storage under invoice_app/data/bills
  Map<String, dynamic> toFirestore() {
    return {
      'invoiceNumber': invoiceNumber,
      'customer': {
        'name': customerName,
        'phone': customerPhone,
        'email': customerEmail ?? '',
        'address': customerAddress ?? '',
      },
      'items': items.map((item) => {
        'id': item.id,
        'title': item.name,
        'name': item.name,
        'qty': item.quantity,
        'quantity': item.quantity,
        'rate': item.rate,
        'amount': item.total,
      }).toList(),
      'paymentStatus': paymentStatus,
      'isPaid': isPaid,
      'subtotal': subtotal,
      'tax': tax,
      'discount': discount,
      'grandTotal': grandTotal,
      'createdAt': date.toIso8601String(),
      'transport': transport ?? '',
      'lrNo': lrNo ?? '',
      'siteName': siteName ?? '',
      'notes': notes ?? '',
    };
  }

  factory Invoice.fromFirestore(String docId, Map<String, dynamic> data) {
    final customerData = data['customer'] is Map ? data['customer'] as Map<String, dynamic> : {};
    
    List<InvoiceItem> itemList = [];
    if (data['items'] is List) {
      itemList = (data['items'] as List).map((i) {
        if (i is Map) {
          final itemMap = Map<String, dynamic>.from(i);
          return InvoiceItem(
            id: itemMap['id']?.toString() ?? '',
            name: (itemMap['title'] ?? itemMap['name'] ?? '').toString(),
            quantity: ((itemMap['qty'] ?? itemMap['quantity'] ?? 0) as num).toDouble(),
            rate: ((itemMap['rate'] ?? 0) as num).toDouble(),
          );
        }
        return InvoiceItem(id: '', name: i.toString(), quantity: 1, rate: 0);
      }).toList();
    }

    final rawPaid = data['paymentStatus'] ?? data['isPaid'];
    final isPaidVal = rawPaid == 'paid' || rawPaid == true || rawPaid == 1;

    DateTime parsedDate = DateTime.now();
    if (data['createdAt'] != null) {
      parsedDate = DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now();
    } else if (data['date'] != null) {
      parsedDate = DateTime.tryParse(data['date'].toString()) ?? DateTime.now();
    }

    return Invoice(
      id: docId,
      invoiceNumber: (data['invoiceNumber'] ?? data['billNumber'] ?? docId).toString(),
      customerName: (customerData['name'] ?? data['customerName'] ?? '').toString(),
      customerPhone: (customerData['phone'] ?? data['customerPhone'] ?? '').toString(),
      customerAddress: customerData['address']?.toString() ?? data['customerAddress']?.toString(),
      customerEmail: customerData['email']?.toString() ?? data['customerEmail']?.toString(),
      date: parsedDate,
      items: itemList,
      isPaid: isPaidVal,
      isSynced: true,
      transport: data['transport']?.toString(),
      lrNo: data['lrNo']?.toString(),
      siteName: data['siteName']?.toString(),
      notes: data['notes']?.toString(),
      tax: ((data['tax'] ?? 0.0) as num).toDouble(),
      discount: ((data['discount'] ?? 0.0) as num).toDouble(),
    );
  }
}
