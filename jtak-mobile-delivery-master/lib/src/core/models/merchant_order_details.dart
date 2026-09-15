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
  String? merchantAddress;
  String? merchantPhone;
  String? merchantLogo;
  bool isDarkStore;
  List<OrderDetailsModel>? orderDetails;
  MerchentOrderDetailsModel({
    this.orderDetailStatus,
    this.orderDetailStatusString,
    this.merchantId,
    this.merchantTitle,
    this.lat,
    this.lng,
    this.merchantAddress,
    this.merchantPhone,
    this.merchantLogo,
    this.isDarkStore = false,
    this.orderDetails,
  });

  MerchentOrderDetailsModel copyWith({
    OrderDetailsStatus? orderDetailStatus,
    String? orderDetailStatusString,
    int? merchantId,
    String? merchantTitle,
    double? lat,
    double? lng,
    String? merchantAddress,
    String? merchantPhone,
    String? merchantLogo,
    bool? isDarkStore,
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
      merchantAddress: merchantAddress ?? this.merchantAddress,
      merchantPhone: merchantPhone ?? this.merchantPhone,
      merchantLogo: merchantLogo ?? this.merchantLogo,
      isDarkStore: isDarkStore ?? this.isDarkStore,
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
      'merchantAddress': merchantAddress,
      'merchantPhone': merchantPhone,
      'merchantLogo': merchantLogo,
      'isDarkStore': isDarkStore,
      'orderDetails': orderDetails?.map((x) => x.toMap()).toList(),
    };
  }

  factory MerchentOrderDetailsModel.fromMap(Map<String, dynamic> map) {
    final statusRaw = map['orderDetailStatus'] ?? map['OrderDetailStatus'];
    return MerchentOrderDetailsModel(
      orderDetailStatus: statusRaw != null
          ? (statusRaw is int
              ? statusRaw.parseOrderDetailsStatus
              : int.tryParse(statusRaw.toString())?.parseOrderDetailsStatus)
          : null,
      orderDetailStatusString:
          map['orderDetailStatusString'] ?? map['OrderDetailStatusString'],
      merchantId: (map['merchantId'] ?? map['MerchantId']) != null
          ? int.tryParse((map['merchantId'] ?? map['MerchantId']).toString())
          : null,
      merchantTitle: map['merchantTitle'] ?? map['MerchantTitle'],
      lat: (map['lat'] ?? map['Lat']) != null
          ? double.tryParse((map['lat'] ?? map['Lat']).toString())
          : null,
      lng: (map['lng'] ?? map['Lng']) != null
          ? double.tryParse((map['lng'] ?? map['Lng']).toString())
          : null,
      merchantAddress: map['merchantAddress'] ??
          map['MerchantAddress'] ??
          map['address'] ??
          map['Address'],
      merchantPhone: map['merchantPhone'] ??
          map['MerchantPhone'] ??
          map['phone'] ??
          map['Phone'],
      merchantLogo: map['merchantLogo'] ??
          map['MerchantLogo'] ??
          map['photo'] ??
          map['Photo'] ??
          map['logo'] ??
          map['Logo'],
      isDarkStore: (map['isDarkStore'] ?? map['IsDarkStore']) == true,
      orderDetails: (map['orderDetails'] ?? map['OrderDetails']) != null
          ? List<OrderDetailsModel>.from(
              (map['orderDetails'] ?? map['OrderDetails'])
                  ?.map((x) => OrderDetailsModel.fromMap(x)))
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
