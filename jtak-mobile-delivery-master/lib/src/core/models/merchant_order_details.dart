import 'dart:convert';

import 'package:app_jtak_delivery/src/core/enums/order_details_status_enum.dart';
import 'package:flutter/foundation.dart';

import 'package:app_jtak_delivery/src/core/models/order_details_model.dart';

class MerchentOrderDetailsModel {
  OrderDetailsStatus? orderDetailStatus;
  String? orderDetailStatusString;
  int? merchantId;
  String? merchantTitle;
  double? lat;
  double? lng;
  List<OrderDetailsModel>? orderDetails;
  MerchentOrderDetailsModel({
    this.orderDetailStatus,
    this.orderDetailStatusString,
    this.merchantId,
    this.merchantTitle,
    this.lat,
    this.lng,
    this.orderDetails,
  });

  MerchentOrderDetailsModel copyWith({
    OrderDetailsStatus? orderDetailStatus,
    String? orderDetailStatusString,
    int? merchantId,
    String? merchantTitle,
    double? lat,
    double? lng,
    List<OrderDetailsModel>? orderDetails,
  }) {
    return MerchentOrderDetailsModel(
      orderDetailStatus: orderDetailStatus ?? this.orderDetailStatus,
      orderDetailStatusString:
          orderDetailStatusString ?? this.orderDetailStatusString,
      merchantId: merchantId ?? this.merchantId,
      merchantTitle: merchantTitle ?? this.merchantTitle,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      orderDetails: orderDetails ?? this.orderDetails,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderDetailStatus': orderDetailStatus?.index,
      'orderDetailStatusString': orderDetailStatusString,
      'merchantId': merchantId,
      'merchantTitle': merchantTitle,
      'lat': lat,
      'lng': lng,
      'orderDetails': orderDetails?.map((x) => x.toMap()).toList(),
    };
  }

  factory MerchentOrderDetailsModel.fromMap(Map<String, dynamic> map) {
    return MerchentOrderDetailsModel(
      orderDetailStatus:
          (map['orderDetailStatus'] as int).parseOrderDetailsStatus,
      orderDetailStatusString: map['orderDetailStatusString'],
      merchantId: map['merchantId']?.toInt(),
      merchantTitle: map['merchantTitle'],
      lat: map['lat']?.toDouble(),
      lng: map['lng']?.toDouble(),
      orderDetails: map['orderDetails'] != null
          ? List<OrderDetailsModel>.from(
              map['orderDetails']?.map((x) => OrderDetailsModel.fromMap(x)))
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory MerchentOrderDetailsModel.fromJson(String source) =>
      MerchentOrderDetailsModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'MerchentOrderDetails(orderDetailStatus: $orderDetailStatus, orderDetailStatusString: $orderDetailStatusString, merchantId: $merchantId, merchantTitle: $merchantTitle, lat: $lat, lng: $lng, orderDetails: $orderDetails)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MerchentOrderDetailsModel &&
        other.orderDetailStatus == orderDetailStatus &&
        other.orderDetailStatusString == orderDetailStatusString &&
        other.merchantId == merchantId &&
        other.merchantTitle == merchantTitle &&
        other.lat == lat &&
        other.lng == lng &&
        listEquals(other.orderDetails, orderDetails);
  }

  @override
  int get hashCode {
    return orderDetailStatus.hashCode ^
        orderDetailStatusString.hashCode ^
        merchantId.hashCode ^
        merchantTitle.hashCode ^
        lat.hashCode ^
        lng.hashCode ^
        orderDetails.hashCode;
  }
}
