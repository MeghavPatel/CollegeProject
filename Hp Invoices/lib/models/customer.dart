class Customer {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final DateTime? createdAt;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.email = '',
    this.address = '',
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'createdAt': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      address: map['address'] ?? '',
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'createdAt': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory Customer.fromFirestore(String docId, Map<String, dynamic> data) {
    return Customer(
      id: docId,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      address: data['address'] ?? '',
      createdAt: data['createdAt'] != null ? DateTime.tryParse(data['createdAt'].toString()) : null,
    );
  }
}
