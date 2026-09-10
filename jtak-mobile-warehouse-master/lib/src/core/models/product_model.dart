import 'dart:convert';

class ProductModel {
  int? merchantId;
  int? productId;
  String? product;
  String? productPhotos;
  String? productCat1;
  String? productCat2;
  int? profitOutOfMerchantPricePercent;
  int? profitOutOfMerchantPrice;
  int? merchantProfit;
  int? merchantPrice;
  int? additionalProfitPercent;
  int? additionalProfit;
  double? discount;
  double? price;
  double? finalPrice;
  ProductModel({
    this.merchantId,
    this.productId,
    this.product,
    this.productPhotos,
    this.productCat1,
    this.productCat2,
    this.profitOutOfMerchantPricePercent,
    this.profitOutOfMerchantPrice,
    this.merchantProfit,
    this.merchantPrice,
    this.additionalProfitPercent,
    this.additionalProfit,
    this.discount,
    this.price,
    this.finalPrice,
  });

  ProductModel copyWith({
    int? merchantId,
    int? productId,
    String? product,
    String? productPhotos,
    String? productCat1,
    String? productCat2,
    int? profitOutOfMerchantPricePercent,
    int? profitOutOfMerchantPrice,
    int? merchantProfit,
    int? merchantPrice,
    int? additionalProfitPercent,
    int? additionalProfit,
    double? discount,
    double? price,
    double? finalPrice,
  }) {
    return ProductModel(
      merchantId: merchantId ?? this.merchantId,
      productId: productId ?? this.productId,
      product: product ?? this.product,
      productPhotos: productPhotos ?? this.productPhotos,
      productCat1: productCat1 ?? this.productCat1,
      productCat2: productCat2 ?? this.productCat2,
      profitOutOfMerchantPricePercent: profitOutOfMerchantPricePercent ?? this.profitOutOfMerchantPricePercent,
      profitOutOfMerchantPrice: profitOutOfMerchantPrice ?? this.profitOutOfMerchantPrice,
      merchantProfit: merchantProfit ?? this.merchantProfit,
      merchantPrice: merchantPrice ?? this.merchantPrice,
      additionalProfitPercent: additionalProfitPercent ?? this.additionalProfitPercent,
      additionalProfit: additionalProfit ?? this.additionalProfit,
      discount: discount ?? this.discount,
      price: price ?? this.price,
      finalPrice: finalPrice ?? this.finalPrice,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'merchantId': merchantId,
      'productId': productId,
      'product': product,
      'productPhotos': productPhotos,
      'productCat1': productCat1,
      'productCat2': productCat2,
      'profitOutOfMerchantPricePercent': profitOutOfMerchantPricePercent,
      'profitOutOfMerchantPrice': profitOutOfMerchantPrice,
      'merchantProfit': merchantProfit,
      'merchantPrice': merchantPrice,
      'additionalProfitPercent': additionalProfitPercent,
      'additionalProfit': additionalProfit,
      'discount': discount,
      'price': price,
      'finalPrice': finalPrice,
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      merchantId: map['merchantId']?.toInt(),
      productId: map['productId']?.toInt(),
      product: map['product'],
      productPhotos: map['productPhotos'],
      productCat1: map['productCat1'],
      productCat2: map['productCat2'],
      profitOutOfMerchantPricePercent: map['profitOutOfMerchantPricePercent']?.toInt(),
      profitOutOfMerchantPrice: map['profitOutOfMerchantPrice']?.toInt(),
      merchantProfit: map['merchantProfit']?.toInt(),
      merchantPrice: map['merchantPrice']?.toInt(),
      additionalProfitPercent: map['additionalProfitPercent']?.toInt(),
      additionalProfit: map['additionalProfit']?.toInt(),
      discount: map['discount']?.toDouble(),
      price: map['price']?.toDouble(),
      finalPrice: map['finalPrice']?.toDouble(),
    );
  }

  String toJson() => json.encode(toMap());

  factory ProductModel.fromJson(String source) => ProductModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'ProductModel(merchantId: $merchantId, productId: $productId, product: $product, productPhotos: $productPhotos, productCat1: $productCat1, productCat2: $productCat2, profitOutOfMerchantPricePercent: $profitOutOfMerchantPricePercent, profitOutOfMerchantPrice: $profitOutOfMerchantPrice, merchantProfit: $merchantProfit, merchantPrice: $merchantPrice, additionalProfitPercent: $additionalProfitPercent, additionalProfit: $additionalProfit, discount: $discount, price: $price, finalPrice: $finalPrice)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ProductModel &&
        other.merchantId == merchantId &&
        other.productId == productId &&
        other.product == product &&
        other.productPhotos == productPhotos &&
        other.productCat1 == productCat1 &&
        other.productCat2 == productCat2 &&
        other.profitOutOfMerchantPricePercent == profitOutOfMerchantPricePercent &&
        other.profitOutOfMerchantPrice == profitOutOfMerchantPrice &&
        other.merchantProfit == merchantProfit &&
        other.merchantPrice == merchantPrice &&
        other.additionalProfitPercent == additionalProfitPercent &&
        other.additionalProfit == additionalProfit &&
        other.discount == discount &&
        other.price == price &&
        other.finalPrice == finalPrice;
  }

  @override
  int get hashCode {
    return merchantId.hashCode ^
        productId.hashCode ^
        product.hashCode ^
        productPhotos.hashCode ^
        productCat1.hashCode ^
        productCat2.hashCode ^
        profitOutOfMerchantPricePercent.hashCode ^
        profitOutOfMerchantPrice.hashCode ^
        merchantProfit.hashCode ^
        merchantPrice.hashCode ^
        additionalProfitPercent.hashCode ^
        additionalProfit.hashCode ^
        discount.hashCode ^
        price.hashCode ^
        finalPrice.hashCode;
  }
}
