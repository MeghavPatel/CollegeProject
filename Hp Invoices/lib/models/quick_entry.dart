enum QuickEntryType { receipt, payment, contra }
enum AccountMode { cash, bank }

class QuickEntry {
  final String id;
  final DateTime date;
  final QuickEntryType type;
  final AccountMode mode;
  final String partyName;
  final double amount;
  final String remarks;
  final bool isSynced;

  QuickEntry({
    required this.id,
    required this.date,
    required this.type,
    required this.mode,
    required this.partyName,
    required this.amount,
    this.remarks = '',
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'type': type.name,
      'mode': mode.name,
      'partyName': partyName,
      'amount': amount,
      'remarks': remarks,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory QuickEntry.fromMap(Map<String, dynamic> map) {
    return QuickEntry(
      id: map['id'] ?? '',
      date: DateTime.parse(map['date']),
      type: QuickEntryType.values.byName(map['type']),
      mode: AccountMode.values.byName(map['mode']),
      partyName: map['partyName'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      remarks: map['remarks'] ?? '',
      isSynced: map['isSynced'] == 1,
    );
  }
}
