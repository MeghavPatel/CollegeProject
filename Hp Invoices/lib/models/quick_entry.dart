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
    DateTime parsedDate = DateTime.now();
    if (map['date'] != null) {
      parsedDate = DateTime.tryParse(map['date'].toString()) ?? DateTime.now();
    } else if (map['createdAt'] != null) {
      parsedDate = DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now();
    }

    final typeStr = (map['type'] ?? 'receipt').toString().toLowerCase().trim();
    QuickEntryType entryType = QuickEntryType.receipt;
    if (typeStr == 'payment') {
      entryType = QuickEntryType.payment;
    } else if (typeStr == 'contra') {
      entryType = QuickEntryType.contra;
    }

    final modeStr = (map['mode'] ?? 'cash').toString().toLowerCase().trim();
    AccountMode accountMode = AccountMode.cash;
    if (modeStr == 'bank') {
      accountMode = AccountMode.bank;
    }

    return QuickEntry(
      id: (map['id'] ?? '').toString(),
      date: parsedDate,
      type: entryType,
      mode: accountMode,
      partyName: (map['partyName'] ?? map['party_name'] ?? map['customerName'] ?? '').toString(),
      amount: ((map['amount'] ?? 0.0) as num).toDouble(),
      remarks: (map['remarks'] ?? map['description'] ?? '').toString(),
      isSynced: map['isSynced'] == 1 || map['isSynced'] == true || map['is_synced'] == 1,
    );
  }
}
