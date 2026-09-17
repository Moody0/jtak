import 'dart:convert';

class LocalCartItem {
  int productId;
  int merchantId;
  double singleFinalPrice;
  int quantity;
  String? productTitle;
  String? productImage;
  String? merchantTitle;

  LocalCartItem({
    required this.productId,
    required this.merchantId,
    required this.singleFinalPrice,
    required this.quantity,
    this.productTitle,
    this.productImage,
    this.merchantTitle,
  });

  LocalCartItem copyWith({
    int? productId,
    int? merchantId,
    double? singleFinalPrice,
    int? quantity,
    String? productTitle,
    String? productImage,
    String? merchantTitle,
  }) {
    return LocalCartItem(
      productId: productId ?? this.productId,
      merchantId: merchantId ?? this.merchantId,
      singleFinalPrice: singleFinalPrice ?? this.singleFinalPrice,
      quantity: quantity ?? this.quantity,
      productTitle: productTitle ?? this.productTitle,
      productImage: productImage ?? this.productImage,
      merchantTitle: merchantTitle ?? this.merchantTitle,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'merchantId': merchantId,
      'singleFinalPrice': singleFinalPrice,
      'quantity': quantity,
      if (productTitle != null) 'productTitle': productTitle,
      if (productImage != null) 'productImage': productImage,
      if (merchantTitle != null) 'merchantTitle': merchantTitle,
    };
  }

  factory LocalCartItem.fromMap(Map<String, dynamic> map) {
    return LocalCartItem(
      productId: (map['productId'] ?? map['ProductId'])?.toInt() ?? 0,
      merchantId: (map['merchantId'] ?? map['MerchantId'])?.toInt() ?? 0,
      singleFinalPrice: (map['singleFinalPrice'] ?? map['SingleFinalPrice'])?.toDouble() ?? 0.0,
      quantity: (map['quantity'] ?? map['Quantity'])?.toInt() ?? 0,
      productTitle: map['productTitle'] ?? map['ProductTitle'],
      productImage: map['productImage'] ?? map['ProductImage'] ?? map['photos'] ?? map['Photos'],
      merchantTitle: map['merchantTitle'] ?? map['MerchantTitle'] ?? map['merchant'] ?? map['Merchant'],
    );
  }

  String toJson() => json.encode(toMap());

  factory LocalCartItem.fromJson(String source) => LocalCartItem.fromMap(json.decode(source));

  @override
  String toString() {
    return 'LocalCartItem(productId: $productId, merchantId: $merchantId, singleFinalPrice: $singleFinalPrice, quantity: $quantity, productTitle: $productTitle, productImage: $productImage)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LocalCartItem &&
        other.productId == productId &&
        other.merchantId == merchantId &&
        other.singleFinalPrice == singleFinalPrice &&
        other.quantity == quantity &&
        other.productTitle == productTitle &&
        other.productImage == productImage;
  }

  @override
  int get hashCode {
    return productId.hashCode ^
        merchantId.hashCode ^
        singleFinalPrice.hashCode ^
        quantity.hashCode ^
        (productTitle?.hashCode ?? 0) ^
        (productImage?.hashCode ?? 0);
  }

  static String encode(List<LocalCartItem> items) => json.encode(
        items.map<Map<String, dynamic>>((cartItme) => cartItme.toMap()).toList(),
      );

  static List<LocalCartItem> decode(String items) =>
      (json.decode(items) as List<dynamic>).map<LocalCartItem>((cartItme) => LocalCartItem.fromMap(cartItme)).toList();
}
