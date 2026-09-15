import 'dart:convert';

import 'package:app_jtak_warehouse/src/core/enums/order_details_status_enum.dart';

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

  // Dark Store WMS Fields
  String? locationBin;
  String? batchNumber;
  String? barcode;
  String? expirationDate;
  bool isPicked;

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
    this.locationBin,
    this.batchNumber,
    this.barcode,
    this.expirationDate,
    this.isPicked = false,
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
    String? locationBin,
    String? batchNumber,
    String? barcode,
    String? expirationDate,
    bool? isPicked,
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
      locationBin: locationBin ?? this.locationBin,
      batchNumber: batchNumber ?? this.batchNumber,
      barcode: barcode ?? this.barcode,
      expirationDate: expirationDate ?? this.expirationDate,
      isPicked: isPicked ?? this.isPicked,
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
      'locationBin': locationBin,
      'batchNumber': batchNumber,
      'barcode': barcode,
      'expirationDate': expirationDate,
      'isPicked': isPicked,
    };
  }

  factory OrderDetailsModel.fromMap(Map<String, dynamic> map) {
    final statusRaw = map['orderDetailStatus'] ?? map['OrderDetailStatus'];
    return OrderDetailsModel(
      id: (map['id'] ?? map['Id']) is num ? (map['id'] ?? map['Id']).toInt() : int.tryParse('${map['id'] ?? map['Id']}'),
      quantity: (map['quantity'] ?? map['Quantity']) is num ? (map['quantity'] ?? map['Quantity']).toInt() : int.tryParse('${map['quantity'] ?? map['Quantity']}'),
      singlePrice: (map['singlePrice'] ?? map['SinglePrice']) is num ? (map['singlePrice'] ?? map['SinglePrice']).toDouble() : double.tryParse('${map['singlePrice'] ?? map['SinglePrice']}'),
      singleFinalPrice: (map['singleFinalPrice'] ?? map['SingleFinalPrice']) is num ? (map['singleFinalPrice'] ?? map['SingleFinalPrice']).toDouble() : double.tryParse('${map['singleFinalPrice'] ?? map['SingleFinalPrice']}'),
      totalPrice: (map['totalPrice'] ?? map['TotalPrice']) is num ? (map['totalPrice'] ?? map['TotalPrice']).toDouble() : double.tryParse('${map['totalPrice'] ?? map['TotalPrice']}'),
      totalFinalPrice: (map['totalFinalPrice'] ?? map['TotalFinalPrice']) is num ? (map['totalFinalPrice'] ?? map['TotalFinalPrice']).toDouble() : double.tryParse('${map['totalFinalPrice'] ?? map['TotalFinalPrice']}'),
      currency: (map['currency'] ?? map['Currency']) is num ? (map['currency'] ?? map['Currency']).toInt() : int.tryParse('${map['currency'] ?? map['Currency']}'),
      currencyString: (map['currencyString'] ?? map['CurrencyString'])?.toString(),
      orderDetailStatus: statusRaw != null ? parseOrderDetailsStatusSafe(statusRaw) : null,
      orderDetailStatusString: (map['orderDetailStatusString'] ?? map['OrderDetailStatusString'])?.toString(),
      warning: (map['warning'] ?? map['Warning'])?.toString(),
      productId: (map['productId'] ?? map['ProductId']) is num ? (map['productId'] ?? map['ProductId']).toInt() : int.tryParse('${map['productId'] ?? map['ProductId']}'),
      productTitle: (map['productTitle'] ?? map['ProductTitle'])?.toString(),
      productUnit: (map['productUnit'] ?? map['ProductUnit'])?.toString(),
      productImage: (map['productImage'] ?? map['ProductImage'])?.toString(),
      merchantId: (map['merchantId'] ?? map['MerchantId']) is num ? (map['merchantId'] ?? map['MerchantId']).toInt() : int.tryParse('${map['merchantId'] ?? map['MerchantId']}'),
      merchantTitle: (map['merchantTitle'] ?? map['MerchantTitle'])?.toString(),
      orderId: (map['orderId'] ?? map['OrderId']) is num ? (map['orderId'] ?? map['OrderId']).toInt() : int.tryParse('${map['orderId'] ?? map['OrderId']}'),
      locationBin: (map['locationBin'] ?? map['LocationBin'])?.toString(),
      batchNumber: (map['batchNumber'] ?? map['BatchNumber'])?.toString(),
      barcode: (map['barcode'] ?? map['Barcode'])?.toString(),
      expirationDate: (map['expirationDate'] ?? map['ExpirationDate'])?.toString(),
      isPicked: (map['isPicked'] ?? map['IsPicked']) ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory OrderDetailsModel.fromJson(String source) => OrderDetailsModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'OrderDetailsModel(id: $id, quantity: $quantity, singlePrice: $singlePrice, singleFinalPrice: $singleFinalPrice, totalPrice: $totalPrice, totalFinalPrice: $totalFinalPrice, currency: $currency, currencyString: $currencyString, orderDetailStatus: $orderDetailStatus, orderDetailStatusString: $orderDetailStatusString, warning: $warning, productId: $productId, productTitle: $productTitle, productUnit: $productUnit, productImage: $productImage, merchantId: $merchantId, merchantTitle: $merchantTitle, orderId: $orderId, locationBin: $locationBin, batchNumber: $batchNumber, barcode: $barcode, isPicked: $isPicked)';
  }
}
