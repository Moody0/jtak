import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:app_jtak_delivery/src/core/enums/order_status_enum.dart';
import 'package:app_jtak_delivery/src/core/enums/payment_method_enum.dart';
import 'package:app_jtak_delivery/src/core/models/merchant_order_details.dart';

class OrderModel {
  int? id;
  String? user;
  String? userId;
  String? purchaseDate;
  String? description;
  String? phonenumber;
  double? lat;
  double? lng;
  String? address;
  PaymentMethod? paymentMethod;
  OrderStatus? orderStatus;
  List<MerchentOrderDetailsModel>? orderDetails;
  double? price;
  String? createdDate;
  String? mapsUrl;
  OrderModel({
    this.id,
    this.user,
    this.userId,
    this.purchaseDate,
    this.description,
    this.phonenumber,
    this.lat,
    this.lng,
    this.address,
    this.paymentMethod,
    this.orderStatus,
    this.orderDetails,
    this.price,
    this.createdDate,
    this.mapsUrl,
  });

  OrderModel copyWith({
    int? id,
    String? user,
    String? userId,
    String? purchaseDate,
    String? description,
    String? phonenumber,
    double? lat,
    double? lng,
    String? address,
    PaymentMethod? paymentMethod,
    OrderStatus? orderStatus,
    List<MerchentOrderDetailsModel>? orderDetails,
    double? price,
    String? createdDate,
    String? mapsUrl,
  }) {
    return OrderModel(
      id: id ?? this.id,
      user: user ?? this.user,
      userId: userId ?? this.userId,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      description: description ?? this.description,
      phonenumber: phonenumber ?? this.phonenumber,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      address: address ?? this.address,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      orderStatus: orderStatus ?? this.orderStatus,
      orderDetails: orderDetails ?? this.orderDetails,
      price: price ?? this.price,
      createdDate: createdDate ?? this.createdDate,
      mapsUrl: mapsUrl ?? this.mapsUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user': user,
      'userId': userId,
      'purchaseDate': purchaseDate,
      'description': description,
      'phonenumber': phonenumber,
      'lat': lat,
      'lng': lng,
      'address': address,
      'paymentMethod': paymentMethod?.index,
      'orderStatus': orderStatus?.index,
      'orderDetails': orderDetails?.map((x) => x.toMap()).toList(),
      'price': price,
      'createdDate': createdDate,
      'mapsUrl': mapsUrl,
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    final pmRaw = map['paymentMethod'] ?? map['PaymentMethod'];
    final osRaw = map['orderStatus'] ?? map['OrderStatus'];
    return OrderModel(
      id: (map['id'] ?? map['Id']) != null ? int.tryParse((map['id'] ?? map['Id']).toString()) : null,
      user: map['user'] ?? map['User'],
      userId: map['userId'] ?? map['UserId'],
      purchaseDate: map['purchaseDate'] ?? map['PurchaseDate'],
      description: map['description'] ?? map['Description'],
      phonenumber: map['phonenumber'] ?? map['Phonenumber'] ?? map['phoneNumber'] ?? map['PhoneNumber'],
      lat: (map['lat'] ?? map['Lat']) != null ? double.tryParse((map['lat'] ?? map['Lat']).toString()) : null,
      lng: (map['lng'] ?? map['Lng']) != null ? double.tryParse((map['lng'] ?? map['Lng']).toString()) : null,
      address: map['address'] ?? map['Address'],
      paymentMethod: pmRaw != null
          ? (pmRaw is int ? pmRaw.parsePaymentMethod : int.tryParse(pmRaw.toString())?.parsePaymentMethod)
          : null,
      orderStatus: osRaw != null
          ? (osRaw is int ? osRaw.parseOrderStatus : int.tryParse(osRaw.toString())?.parseOrderStatus)
          : null,
      orderDetails: (map['orderDetails'] ?? map['OrderDetails']) != null
          ? List<MerchentOrderDetailsModel>.from((map['orderDetails'] ?? map['OrderDetails'])
              ?.map((x) => MerchentOrderDetailsModel.fromMap(x)))
          : null,
      price: (map['price'] ?? map['Price']) != null ? double.tryParse((map['price'] ?? map['Price']).toString()) : null,
      createdDate: map['createdDate'] ?? map['CreatedDate'],
      mapsUrl: map['mapsUrl'] ?? map['MapsUrl'],
    );
  }

  String toJson() => json.encode(toMap());

  factory OrderModel.fromJson(String source) =>
      OrderModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'OrderModel(id: $id, user: $user, userId: $userId, purchaseDate: $purchaseDate, description: $description, phonenumber: $phonenumber, lat: $lat, lng: $lng, address: $address, paymentMethod: $paymentMethod, orderStatus: $orderStatus, orderDetails: $orderDetails, price: $price, createdDate: $createdDate, mapsUrl: $mapsUrl)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is OrderModel &&
        other.id == id &&
        other.user == user &&
        other.userId == userId &&
        other.purchaseDate == purchaseDate &&
        other.description == description &&
        other.phonenumber == phonenumber &&
        other.lat == lat &&
        other.lng == lng &&
        other.address == address &&
        other.paymentMethod == paymentMethod &&
        other.orderStatus == orderStatus &&
        listEquals(other.orderDetails, orderDetails) &&
        other.price == price &&
        other.createdDate == createdDate &&
        other.mapsUrl == mapsUrl;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        user.hashCode ^
        userId.hashCode ^
        purchaseDate.hashCode ^
        description.hashCode ^
        phonenumber.hashCode ^
        lat.hashCode ^
        lng.hashCode ^
        address.hashCode ^
        paymentMethod.hashCode ^
        orderStatus.hashCode ^
        orderDetails.hashCode ^
        price.hashCode ^
        createdDate.hashCode ^
        mapsUrl.hashCode;
  }
}
