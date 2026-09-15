import 'dart:convert';

class ProductModel {
  int? merchantId;
  int? productId;
  String? product;
  String? productPhotos;
  String? productCat1;
  String? productCat2;
  String? productDescription;
  String? productUnit;
  int? productCategoryId;
  bool productActive;
  bool productIsFeatured;
  String? categoryIcon;
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
    this.productDescription,
    this.productUnit,
    this.productCategoryId,
    this.productActive = true,
    this.productIsFeatured = false,
    this.categoryIcon,
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
    String? productDescription,
    String? productUnit,
    int? productCategoryId,
    bool? productActive,
    bool? productIsFeatured,
    String? categoryIcon,
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
      productDescription: productDescription ?? this.productDescription,
      productUnit: productUnit ?? this.productUnit,
      productCategoryId: productCategoryId ?? this.productCategoryId,
      productActive: productActive ?? this.productActive,
      productIsFeatured: productIsFeatured ?? this.productIsFeatured,
      categoryIcon: categoryIcon ?? this.categoryIcon,
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
      'productDescription': productDescription,
      'productUnit': productUnit,
      'productCategoryId': productCategoryId,
      'productActive': productActive,
      'productIsFeatured': productIsFeatured,
      'categoryIcon': categoryIcon,
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
      productId: map['productId']?.toInt() ?? map['id']?.toInt(),
      product: map['product'] ?? map['title'],
      productPhotos: map['productPhotos'] ?? map['photos'],
      productCat1: map['productCat1'] ?? map['productCategory'],
      productCat2: map['productCat2'],
      productDescription: map['productDescription'] ?? map['description'],
      productUnit: map['productUnit'] ?? map['unit'],
      productCategoryId: map['productCategoryId']?.toInt(),
      productActive: map['productActive'] ?? map['active'] ?? true,
      productIsFeatured: map['productIsFeatured'] ?? map['isFeatured'] ?? false,
      categoryIcon: map['categoryIcon'],
      profitOutOfMerchantPricePercent: map['profitOutOfMerchantPricePercent']?.toInt(),
      profitOutOfMerchantPrice: map['profitOutOfMerchantPrice']?.toInt(),
      merchantProfit: map['merchantProfit']?.toInt(),
      merchantPrice: map['merchantPrice']?.toInt() ?? (map['price'] != null ? (map['price'] as num).toInt() : null),
      additionalProfitPercent: map['additionalProfitPercent']?.toInt(),
      additionalProfit: map['additionalProfit']?.toInt(),
      discount: map['discount'] != null ? (map['discount'] as num).toDouble() : null,
      price: map['price'] != null ? (map['price'] as num).toDouble() : null,
      finalPrice: map['finalPrice'] != null
          ? (map['finalPrice'] as num).toDouble()
          : (map['merchantPrice'] != null
              ? (map['merchantPrice'] as num).toDouble()
              : (map['price'] != null ? (map['price'] as num).toDouble() : null)),
    );
  }

  String toJson() => json.encode(toMap());

  factory ProductModel.fromJson(String source) => ProductModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'ProductModel(productId: $productId, product: $product, price: $finalPrice, active: $productActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductModel && other.productId == productId;
  }

  @override
  int get hashCode => productId.hashCode;
}
