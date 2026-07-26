class InventoryItem {
  final String id;
  final String name;
  final double? defaultRate;

  InventoryItem({
    required this.id,
    required this.name,
    this.defaultRate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      if (defaultRate != null) 'defaultRate': defaultRate,
    };
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      defaultRate: map['defaultRate'] != null ? (map['defaultRate'] as num).toDouble() : null,
    );
  }
}
