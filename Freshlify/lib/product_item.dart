class ProductItem {
  final String name;
  final String expiryText;
  final int daysLeft;
  final String status;

  ProductItem({
    required this.name,
    required this.expiryText,
    required this.daysLeft,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'expiryText': expiryText,
      'daysLeft': daysLeft,
      'status': status,
    };
  }

  factory ProductItem.fromMap(Map<String, dynamic> map) {
    return ProductItem(
      name: map['name'] ?? '',
      expiryText: map['expiryText'] ?? '',
      daysLeft: map['daysLeft'] ?? 0,
      status: map['status'] ?? '',
    );
  }
}