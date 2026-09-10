import 'dart:convert';

class LocalCartItem {
  int productId;
  int merchantId;
  double singleFinalPrice;
  int quantity;
  LocalCartItem({
    required this.productId,
    required this.merchantId,
    required this.singleFinalPrice,
    required this.quantity,
  });

  LocalCartItem copyWith({
    int? productId,
    int? merchantId,
    double? singleFinalPrice,
    int? quantity,
  }) {
    return LocalCartItem(
      productId: productId ?? this.productId,
      merchantId: merchantId ?? this.merchantId,
      singleFinalPrice: singleFinalPrice ?? this.singleFinalPrice,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'merchantId': merchantId,
      'singleFinalPrice': singleFinalPrice,
      'quantity': quantity,
    };
  }

  factory LocalCartItem.fromMap(Map<String, dynamic> map) {
    return LocalCartItem(
      productId: map['productId']?.toInt() ?? 0,
      merchantId: map['merchantId']?.toInt() ?? 0,
      singleFinalPrice: map['singleFinalPrice']?.toDouble() ?? 0.0,
      quantity: map['quantity']?.toInt() ?? 0,
    );
  }

  String toJson() => json.encode(toMap());

  factory LocalCartItem.fromJson(String source) => LocalCartItem.fromMap(json.decode(source));

  @override
  String toString() {
    return 'LocalCartItem(productId: $productId, merchantId: $merchantId, singleFinalPrice: $singleFinalPrice, quantity: $quantity)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LocalCartItem &&
        other.productId == productId &&
        other.merchantId == merchantId &&
        other.singleFinalPrice == singleFinalPrice &&
        other.quantity == quantity;
  }

  @override
  int get hashCode {
    return productId.hashCode ^ merchantId.hashCode ^ singleFinalPrice.hashCode ^ quantity.hashCode;
  }

  static String encode(List<LocalCartItem> items) => json.encode(
        items.map<Map<String, dynamic>>((cartItme) => cartItme.toMap()).toList(),
      );

  static List<LocalCartItem> decode(String items) =>
      (json.decode(items) as List<dynamic>).map<LocalCartItem>((cartItme) => LocalCartItem.fromMap(cartItme)).toList();
}
