import 'dart:convert';

import 'package:app_jtak_delivery/src/core/enums/order_details_status_enum.dart';

class OrderDetailsModel {
  int? id;
  int? quantity;
  double? singlePrice;
  double? singleFinalPrice;
  double? totalPrice;
  double? totalFinalPrice;
  int? currency;
  String? currencyString;
  OrderDetailsStatus? orderDetailStatus;
  String? orderDetailStatusString;
  String? warning;
  int? productId;
  String? productTitle;
  String? productUnit;
  String? productImage;
  int? merchantId;
  String? merchantTitle;
  int? orderId;
  OrderDetailsModel({
    this.id,
    this.quantity,
    this.singlePrice,
    this.singleFinalPrice,
    this.totalPrice,
    this.totalFinalPrice,
    this.currency,
    this.currencyString,
    this.orderDetailStatus,
    this.orderDetailStatusString,
    this.warning,
    this.productId,
    this.productTitle,
    this.productUnit,
    this.productImage,
    this.merchantId,
    this.merchantTitle,
    this.orderId,
  });

  OrderDetailsModel copyWith({
    int? id,
    int? quantity,
    double? singlePrice,
    double? singleFinalPrice,
    double? totalPrice,
    double? totalFinalPrice,
    int? currency,
    String? currencyString,
    OrderDetailsStatus? orderDetailStatus,
    String? orderDetailStatusString,
    String? warning,
    int? productId,
    String? productTitle,
    String? productUnit,
    String? productImage,
    int? merchantId,
    String? merchantTitle,
    int? orderId,
  }) {
    return OrderDetailsModel(
      id: id ?? this.id,
      quantity: quantity ?? this.quantity,
      singlePrice: singlePrice ?? this.singlePrice,
      singleFinalPrice: singleFinalPrice ?? this.singleFinalPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      totalFinalPrice: totalFinalPrice ?? this.totalFinalPrice,
      currency: currency ?? this.currency,
      currencyString: currencyString ?? this.currencyString,
      orderDetailStatus: orderDetailStatus ?? this.orderDetailStatus,
      orderDetailStatusString: orderDetailStatusString ?? this.orderDetailStatusString,
      warning: warning ?? this.warning,
      productId: productId ?? this.productId,
      productTitle: productTitle ?? this.productTitle,
      productUnit: productUnit ?? this.productUnit,
      productImage: productImage ?? this.productImage,
      merchantId: merchantId ?? this.merchantId,
      merchantTitle: merchantTitle ?? this.merchantTitle,
      orderId: orderId ?? this.orderId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'quantity': quantity,
      'singlePrice': singlePrice,
      'singleFinalPrice': singleFinalPrice,
      'totalPrice': totalPrice,
      'totalFinalPrice': totalFinalPrice,
      'currency': currency,
      'currencyString': currencyString,
      'orderDetailStatus': orderDetailStatus?.index,
      'orderDetailStatusString': orderDetailStatusString,
      'warning': warning,
      'productId': productId,
      'productTitle': productTitle,
      'productUnit': productUnit,
      'productImage': productImage,
      'merchantId': merchantId,
      'merchantTitle': merchantTitle,
      'orderId': orderId,
    };
  }

  factory OrderDetailsModel.fromMap(Map<String, dynamic> map) {
    final statusRaw = map['orderDetailStatus'] ?? map['OrderDetailStatus'];
    return OrderDetailsModel(
      id: (map['id'] ?? map['Id']) != null ? int.tryParse((map['id'] ?? map['Id']).toString()) : null,
      quantity: (map['quantity'] ?? map['Quantity']) != null ? int.tryParse((map['quantity'] ?? map['Quantity']).toString()) : null,
      singlePrice: (map['singlePrice'] ?? map['SinglePrice']) != null ? double.tryParse((map['singlePrice'] ?? map['SinglePrice']).toString()) : null,
      singleFinalPrice: (map['singleFinalPrice'] ?? map['SingleFinalPrice']) != null ? double.tryParse((map['singleFinalPrice'] ?? map['SingleFinalPrice']).toString()) : null,
      totalPrice: (map['totalPrice'] ?? map['TotalPrice']) != null ? double.tryParse((map['totalPrice'] ?? map['TotalPrice']).toString()) : null,
      totalFinalPrice: (map['totalFinalPrice'] ?? map['TotalFinalPrice']) != null ? double.tryParse((map['totalFinalPrice'] ?? map['TotalFinalPrice']).toString()) : null,
      currency: (map['currency'] ?? map['Currency']) != null ? int.tryParse((map['currency'] ?? map['Currency']).toString()) : null,
      currencyString: map['currencyString'] ?? map['CurrencyString'],
      orderDetailStatus: statusRaw != null
          ? (statusRaw is int
              ? statusRaw.parseOrderDetailsStatus
              : int.tryParse(statusRaw.toString())?.parseOrderDetailsStatus)
          : null,
      orderDetailStatusString: map['orderDetailStatusString'] ?? map['OrderDetailStatusString'],
      warning: map['warning'] ?? map['Warning'],
      productId: (map['productId'] ?? map['ProductId']) != null ? int.tryParse((map['productId'] ?? map['ProductId']).toString()) : null,
      productTitle: map['productTitle'] ?? map['ProductTitle'],
      productUnit: map['productUnit'] ?? map['ProductUnit'],
      productImage: map['productImage'] ??
          map['ProductImage'] ??
          map['photos'] ??
          map['Photos'] ??
          map['image'] ??
          map['Image'] ??
          map['imageUrl'] ??
          map['ImageUrl'],
      merchantId: (map['merchantId'] ?? map['MerchantId']) != null ? int.tryParse((map['merchantId'] ?? map['MerchantId']).toString()) : null,
      merchantTitle: map['merchantTitle'] ?? map['MerchantTitle'],
      orderId: (map['orderId'] ?? map['OrderId']) != null ? int.tryParse((map['orderId'] ?? map['OrderId']).toString()) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory OrderDetailsModel.fromJson(String source) => OrderDetailsModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'OrderDetailsModel(id: $id, quantity: $quantity, singlePrice: $singlePrice, singleFinalPrice: $singleFinalPrice, totalPrice: $totalPrice, totalFinalPrice: $totalFinalPrice, currency: $currency, currencyString: $currencyString, orderDetailStatus: $orderDetailStatus, orderDetailStatusString: $orderDetailStatusString, warning: $warning, productId: $productId, productTitle: $productTitle, productUnit: $productUnit, productImage: $productImage, merchantId: $merchantId, merchantTitle: $merchantTitle, orderId: $orderId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is OrderDetailsModel &&
        other.id == id &&
        other.quantity == quantity &&
        other.singlePrice == singlePrice &&
        other.singleFinalPrice == singleFinalPrice &&
        other.totalPrice == totalPrice &&
        other.totalFinalPrice == totalFinalPrice &&
        other.currency == currency &&
        other.currencyString == currencyString &&
        other.orderDetailStatus == orderDetailStatus &&
        other.orderDetailStatusString == orderDetailStatusString &&
        other.warning == warning &&
        other.productId == productId &&
        other.productTitle == productTitle &&
        other.productUnit == productUnit &&
        other.productImage == productImage &&
        other.merchantId == merchantId &&
        other.merchantTitle == merchantTitle &&
        other.orderId == orderId;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        quantity.hashCode ^
        singlePrice.hashCode ^
        singleFinalPrice.hashCode ^
        totalPrice.hashCode ^
        totalFinalPrice.hashCode ^
        currency.hashCode ^
        currencyString.hashCode ^
        orderDetailStatus.hashCode ^
        orderDetailStatusString.hashCode ^
        warning.hashCode ^
        productId.hashCode ^
        productTitle.hashCode ^
        productUnit.hashCode ^
        productImage.hashCode ^
        merchantId.hashCode ^
        merchantTitle.hashCode ^
        orderId.hashCode;
  }
}
