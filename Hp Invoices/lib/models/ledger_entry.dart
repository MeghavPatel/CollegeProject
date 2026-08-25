enum LedgerEntryType { debit, credit }

class LedgerEntry {
  final String id;
  final String customerName;
  final DateTime date;
  final String description;
  final LedgerEntryType type;
  final double amount;
  final double runningBalance;
  final String? invoiceId;
  final String? customerPhone;

  LedgerEntry({
    required this.id,
    required this.customerName,
    required this.date,
    required this.description,
    required this.type,
    required this.amount,
    required this.runningBalance,
    this.invoiceId,
    this.customerPhone,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerName': customerName,
      'date': date.toIso8601String(),
      'description': description,
      'type': type == LedgerEntryType.debit ? 'debit' : 'credit',
      'amount': amount,
      'runningBalance': runningBalance,
      'invoiceId': invoiceId,
      'customerPhone': customerPhone,
    };
  }

  factory LedgerEntry.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate = DateTime.now();
    if (map['date'] != null) {
      parsedDate = DateTime.tryParse(map['date'].toString()) ?? DateTime.now();
    } else if (map['createdAt'] != null) {
      parsedDate = DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now();
    }

    final typeStr = (map['type'] ?? 'debit').toString().toLowerCase().trim();
    final entryType = typeStr == 'credit' ? LedgerEntryType.credit : LedgerEntryType.debit;

    return LedgerEntry(
      id: (map['id'] ?? map['entryId'] ?? map['entry_id'] ?? '').toString(),
      customerName: (map['customerName'] ?? map['customer_name'] ?? map['partyName'] ?? map['party_name'] ?? '').toString().trim(),
      date: parsedDate,
      description: (map['description'] ?? map['remarks'] ?? '').toString(),
      type: entryType,
      amount: ((map['amount'] ?? 0.0) as num).toDouble(),
      runningBalance: ((map['runningBalance'] ?? map['running_balance'] ?? map['balance'] ?? 0.0) as num).toDouble(),
      invoiceId: map['invoiceId']?.toString() ?? map['invoice_id']?.toString(),
      customerPhone: map['customerPhone']?.toString() ?? map['customer_phone']?.toString(),
    );
  }
}
