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
    return LedgerEntry(
      id: map['id'] ?? '',
      customerName: map['customerName'] ?? '',
      date: DateTime.parse(map['date']),
      description: map['description'] ?? '',
      type: map['type'] == 'credit' ? LedgerEntryType.credit : LedgerEntryType.debit,
      amount: (map['amount'] as num).toDouble(),
      runningBalance: (map['runningBalance'] as num).toDouble(),
      invoiceId: map['invoiceId'],
      customerPhone: map['customerPhone'],
    );
  }
}
