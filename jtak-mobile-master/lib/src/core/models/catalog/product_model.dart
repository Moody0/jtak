import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:jtek_app/src/core/models/order/order_details_model.dart';

import 'dynamic_field_values.dart';
import 'review_model.dart';
import 'tag_model.dart';
import '../../services/locator.dart';
import '../../controllers/catalog/markets_provider.dart';

class ProductModel {
  int? id;
  String? title;
  String? description;
  List<String>? photos;
  int? totalCount;
  int? soldCount;
  int? availableCount;
  String? unit;
  double? price;
  double? discount;
  double? finalPrice;
  double? originalPrice;
  double? priceUsd;
  int? currency;
  String? currencyString;
  bool? active;
  String? expiryDate;
  bool? isFeatured;
  double? rate;
  int? rateCount;
  ReviewModel? myReview;
  bool? canReview;
  int? merchantId;
  String? merchant;
  String? merchantOwnerId;
  double? shippingCost;
  double? shopMinOrder;
  int? categoryId;
  String? category;
  String? createdDate;
  List<TagModel>? tags;
  List<DynamicFieldValuesModel>? dynamicFieldValues;
  ProductModel({
    this.id,
    this.title,
    this.description,
    this.photos,
    this.totalCount,
    this.soldCount,
    this.availableCount,
    this.unit,
    this.price,
    this.discount,
    this.finalPrice,
    this.originalPrice,
    this.priceUsd,
    this.currency,
    this.currencyString,
    this.active,
    this.expiryDate,
    this.isFeatured,
    this.rate,
    this.rateCount,
    this.myReview,
    this.canReview,
    this.merchantId,
    this.merchant,
    this.merchantOwnerId,
    this.shippingCost,
    this.shopMinOrder,
    this.categoryId,
    this.category,
    this.createdDate,
    this.tags,
    this.dynamicFieldValues,
  });

  double canonicalSellingPriceWithRate([double? exchangeRate]) {
    final rate = exchangeRate ?? _resolveExchangeRate();
    if (priceUsd != null && priceUsd! > 0) {
      return (priceUsd! * rate).roundToDouble();
    }
    final raw = finalPrice ?? price ?? 0.0;
    final isExplicitUsd = (currency == 840 || currency == 2) ||
        (currencyString != null &&
            (currencyString!.toUpperCase() == 'USD' ||
                currencyString == 'دولار أمريكي'));
    if (isExplicitUsd && raw > 0) {
      return (raw * rate).roundToDouble();
    }
    return raw;
  }

  static double _resolveExchangeRate() {
    try {
      if (locator.isRegistered<MarketsProvider>()) {
        final r = locator<MarketsProvider>().exchangeRate;
        if (r > 0) return r;
      }
    } catch (_) {}
    return 15000.0;
  }

  double get canonicalSellingPrice => canonicalSellingPriceWithRate();

  /// Whether this product has an authoritative promotional discount to display.
  /// Business Rule:
  /// 1. discount must be > 0
  /// 2. originalPrice must be != null and > canonicalSellingPrice
  ///
  /// If discount == 0 or originalPrice == null, NO discount/old price is shown.
  bool get hasAuthoritativeDiscount {
    if (discount == null || discount! <= 0) return false;
    if (originalPrice == null || originalPrice! <= 0) return false;
    final selling = canonicalSellingPrice;
    return originalPrice! > selling;
  }

  ProductModel copyWith({
    int? id,
    String? title,
    String? description,
    List<String>? photos,
    int? totalCount,
    int? soldCount,
    int? availableCount,
    String? unit,
    double? price,
    double? discount,
    double? finalPrice,
    double? originalPrice,
    double? priceUsd,
    int? currency,
    String? currencyString,
    bool? active,
    String? expiryDate,
    bool? isFeatured,
    double? rate,
    int? rateCount,
    ReviewModel? myReview,
    bool? canReview,
    int? merchantId,
    String? merchant,
    String? merchantOwnerId,
    double? shippingCost,
    double? shopMinOrder,
    int? categoryId,
    String? category,
    String? createdDate,
    List<TagModel>? tags,
    List<DynamicFieldValuesModel>? dynamicFieldValues,
  }) {
    return ProductModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      photos: photos ?? this.photos,
      totalCount: totalCount ?? this.totalCount,
      soldCount: soldCount ?? this.soldCount,
      availableCount: availableCount ?? this.availableCount,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      discount: discount ?? this.discount,
      finalPrice: finalPrice ?? this.finalPrice,
      originalPrice: originalPrice ?? this.originalPrice,
      priceUsd: priceUsd ?? this.priceUsd,
      currency: currency ?? this.currency,
      currencyString: currencyString ?? this.currencyString,
      active: active ?? this.active,
      expiryDate: expiryDate ?? this.expiryDate,
      isFeatured: isFeatured ?? this.isFeatured,
      rate: rate ?? this.rate,
      rateCount: rateCount ?? this.rateCount,
      myReview: myReview ?? this.myReview,
      canReview: canReview ?? this.canReview,
      merchantId: merchantId ?? this.merchantId,
      merchant: merchant ?? this.merchant,
      merchantOwnerId: merchantOwnerId ?? this.merchantOwnerId,
      shippingCost: shippingCost ?? this.shippingCost,
      shopMinOrder: shopMinOrder ?? this.shopMinOrder,
      categoryId: categoryId ?? this.categoryId,
      category: category ?? this.category,
      createdDate: createdDate ?? this.createdDate,
      tags: tags ?? this.tags,
      dynamicFieldValues: dynamicFieldValues ?? this.dynamicFieldValues,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'photos': photos,
      'totalCount': totalCount,
      'soldCount': soldCount,
      'availableCount': availableCount,
      'unit': unit,
      'price': price,
      'discount': discount,
      'finalPrice': finalPrice,
      'originalPrice': originalPrice,
      'priceUsd': priceUsd,
      'currency': currency,
      'currencyString': currencyString,
      'active': active,
      'expiryDate': expiryDate,
      'isFeatured': isFeatured,
      'rate': rate,
      'rateCount': rateCount,
      'myReview': myReview?.toMap(),
      'canReview': canReview,
      'merchantId': merchantId,
      'merchant': merchant,
      'merchantOwnerId': merchantOwnerId,
      'shippingCost': shippingCost,
      'shopMinOrder': shopMinOrder,
      'categoryId': categoryId,
      'category': category,
      'createdDate': createdDate,
      'tags': tags?.map((x) => x.toMap()).toList(),
      'dynamicFieldValues': dynamicFieldValues?.map((x) => x.toMap()).toList(),
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      photos: map['photos']?.split(','),
      totalCount: map['totalCount'],
      soldCount: map['soldCount'],
      availableCount: map['availableCount'],
      unit: map['unit'],
      price: map['price']?.toDouble() ?? 0.0,
      discount: (map['discount'] ?? map['Discount'])?.toDouble() ?? 0.0,
      finalPrice: map['finalPrice']?.toDouble() ?? 0.0,
      originalPrice: (map['originalPrice'] ?? map['OriginalPrice']) != null
          ? ((map['originalPrice'] ?? map['OriginalPrice']) as num).toDouble()
          : null,
      priceUsd: (map['priceUsd'] ?? map['PriceUsd']) != null
          ? ((map['priceUsd'] ?? map['PriceUsd']) as num).toDouble()
          : null,
      currency: map['currency'],
      currencyString: map['currencyString'],
      active: map['active'],
      expiryDate: map['expiryDate'],
      isFeatured: map['isFeatured'],
      rate: map['rate']?.toDouble() ?? 0.0,
      rateCount: map['rateCount'],
      myReview: map['myReview'] != null ? ReviewModel.fromMap(map['myReview']) : null,
      canReview: map['canReview'],
      merchantId: map['merchantId'] ?? map['MerchantId'],
      merchant: map['merchant'],
      merchantOwnerId: map['merchantOwnerId'],
      shippingCost: map['shippingCost']?.toDouble() ?? 0.0,
      shopMinOrder: map['shopMinOrder']?.toDouble() ?? 0.0,
      categoryId: map['categoryId'],
      category: map['category'],
      createdDate: map['createdDate'],
      tags: map['tags'] != null ? List<TagModel>.from(map['tags']?.map((x) => TagModel.fromMap(x))) : null,
      dynamicFieldValues: map['dynamicFieldValues'] != null
          ? List<DynamicFieldValuesModel>.from(map['dynamicFieldValues']?.map((x) => DynamicFieldValuesModel.fromMap(x)))
          : null,
    );
  }

  factory ProductModel.fromOrderDetails(OrderDetailsModel item) {
    return ProductModel(
      id: item.productId,
      title: item.productTitle,
      photos: item.productImage?.split(','),
      unit: item.productUnit,
      price: item.singlePrice ?? 0.0,
      finalPrice: item.singleFinalPrice ?? 0.0,
      priceUsd: (item.currency == 840 || item.currency == 2) ? item.singlePrice : null,
      currency: item.currency,
      currencyString: item.currencyString,
      merchantId: item.merchantId,
      merchant: item.merchantTitle,
    );
  }

  String toJson() => json.encode(toMap());

  factory ProductModel.fromJson(String source) => ProductModel.fromMap(json.decode(source));

  @override
  String toString() {
    return title ?? '';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ProductModel &&
        other.id == id &&
        other.title == title &&
        other.description == description &&
        listEquals(other.photos, photos) &&
        other.totalCount == totalCount &&
        other.soldCount == soldCount &&
        other.availableCount == availableCount &&
        other.unit == unit &&
        other.price == price &&
        other.discount == discount &&
        other.finalPrice == finalPrice &&
        other.originalPrice == originalPrice &&
        other.priceUsd == priceUsd &&
        other.currency == currency &&
        other.currencyString == currencyString &&
        other.active == active &&
        other.expiryDate == expiryDate &&
        other.isFeatured == isFeatured &&
        other.rate == rate &&
        other.rateCount == rateCount &&
        other.myReview == myReview &&
        other.canReview == canReview &&
        other.merchantId == merchantId &&
        other.merchant == merchant &&
        other.merchantOwnerId == merchantOwnerId &&
        other.shippingCost == shippingCost &&
        other.shopMinOrder == shopMinOrder &&
        other.categoryId == categoryId &&
        other.category == category &&
        other.createdDate == createdDate &&
        listEquals(other.tags, tags) &&
        listEquals(other.dynamicFieldValues, dynamicFieldValues);
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        description.hashCode ^
        photos.hashCode ^
        totalCount.hashCode ^
        soldCount.hashCode ^
        availableCount.hashCode ^
        unit.hashCode ^
        price.hashCode ^
        discount.hashCode ^
        finalPrice.hashCode ^
        originalPrice.hashCode ^
        priceUsd.hashCode ^
        currency.hashCode ^
        currencyString.hashCode ^
        active.hashCode ^
        expiryDate.hashCode ^
        isFeatured.hashCode ^
        rate.hashCode ^
        rateCount.hashCode ^
        myReview.hashCode ^
        canReview.hashCode ^
        merchantId.hashCode ^
        merchant.hashCode ^
        merchantOwnerId.hashCode ^
        shippingCost.hashCode ^
        shopMinOrder.hashCode ^
        categoryId.hashCode ^
        category.hashCode ^
        createdDate.hashCode ^
        tags.hashCode ^
        dynamicFieldValues.hashCode;
  }
}
