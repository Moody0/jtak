import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:jtek_app/src/core/enums/order_status_enum.dart';
import 'package:jtek_app/src/core/enums/payment_method_enum.dart';

import 'order_details_model.dart';

class OrderModel {
  int? id;
  String? user;
  String? userId;
  String? purchaseDate;
  String? description;
  String? phonenumber;
  double? lat;
  double? lng;
  String? deliveryId;
  String? deliveryUser;
  String? deliveryUserPhone;
  double? deliveryLat;
  double? deliveryLng;
  String? deliveryLocationUpdatedAt;
  String? deliveryOtp;
  String? deliveredAt;
  String? address;
  PaymentMethod? paymentMethod;
  OrderStatus? orderStatus;
  List<OrderDetailsModel>? orderDetails;
  double? price;
  String? createdDate;
  String? warning;
  String? notes;
  bool? canSubmit;

  OrderModel({
    this.id,
    this.user,
    this.userId,
    this.purchaseDate,
    this.description,
    this.phonenumber,
    this.lat,
    this.lng,
    this.deliveryId,
    this.deliveryUser,
    this.deliveryUserPhone,
    this.deliveryLat,
    this.deliveryLng,
    this.deliveryLocationUpdatedAt,
    this.deliveryOtp,
    this.deliveredAt,
    this.address,
    this.paymentMethod,
    this.orderStatus,
    this.orderDetails,
    this.price,
    this.createdDate,
    this.warning,
    this.notes,
    this.canSubmit,
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
    String? deliveryId,
    String? deliveryUser,
    double? deliveryLat,
    double? deliveryLng,
    String? deliveryLocationUpdatedAt,
    String? deliveryOtp,
    String? deliveredAt,
    String? address,
    PaymentMethod? paymentMethod,
    OrderStatus? orderStatus,
    List<OrderDetailsModel>? orderDetails,
    double? price,
    String? createdDate,
    String? warning,
    String? notes,
    bool? canSubmit,
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
      deliveryId: deliveryId ?? this.deliveryId,
      deliveryUser: deliveryUser ?? this.deliveryUser,
      deliveryLat: deliveryLat ?? this.deliveryLat,
      deliveryLng: deliveryLng ?? this.deliveryLng,
      deliveryLocationUpdatedAt:
          deliveryLocationUpdatedAt ?? this.deliveryLocationUpdatedAt,
      deliveryOtp: deliveryOtp ?? this.deliveryOtp,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      address: address ?? this.address,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      orderStatus: orderStatus ?? this.orderStatus,
      orderDetails: orderDetails ?? this.orderDetails,
      price: price ?? this.price,
      createdDate: createdDate ?? this.createdDate,
      warning: warning ?? this.warning,
      canSubmit: canSubmit ?? this.canSubmit,
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
      'deliveryId': deliveryId,
      'deliveryUser': deliveryUser,
      'deliveryUserPhone': deliveryUserPhone,
      'deliveryLat': deliveryLat,
      'deliveryLng': deliveryLng,
      'deliveryLocationUpdatedAt': deliveryLocationUpdatedAt,
      'deliveryOtp': deliveryOtp,
      'deliveredAt': deliveredAt,
      'address': address,
      'paymentMethod': paymentMethod?.index,
      'orderStatus': orderStatus?.index,
      'orderDetails': orderDetails?.map((x) => x.toMap()).toList(),
      'price': price,
      'createdDate': createdDate,
      'warning': warning,
      'notes': notes,
      'canSubmit': canSubmit,
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: map['id']?.toInt(),
      user: map['user'],
      userId: map['userId'],
      purchaseDate: map['purchaseDate'],
      description: map['description'],
      phonenumber: map['phonenumber'],
      lat: map['lat']?.toDouble(),
      lng: map['lng']?.toDouble(),
      deliveryId: map['deliveryId'],
      deliveryUser: map['deliveryUser'],
      deliveryUserPhone: map['deliveryUserPhone']?.toString(),
      deliveryLat: map['deliveryLat']?.toDouble(),
      deliveryLng: map['deliveryLng']?.toDouble(),
      deliveryLocationUpdatedAt: map['deliveryLocationUpdatedAt'],
      deliveryOtp: map['deliveryOtp']?.toString(),
      deliveredAt: map['deliveredAt']?.toString(),
      address: map['address'],
      paymentMethod: map['paymentMethod'] != null
          ? (map['paymentMethod'] as int).parsePaymentMethod
          : null,
      orderStatus: map['orderStatus'] != null
          ? (map['orderStatus'] as int).parseOrderStatus
          : null,
      orderDetails: (map['orderDetails'] ?? map['OrderDetails']) != null
          ? List<OrderDetailsModel>.from(
              (map['orderDetails'] ?? map['OrderDetails'])
                  ?.map((x) => OrderDetailsModel.fromMap(x)))
          : null,
      price: map['price']?.toDouble(),
      createdDate: map['createdDate'],
      notes: map['notes'] ?? map['Notes'],
      warning: map['warning'] ?? map['Warning'] ?? map['notes'] ?? map['Notes'],
      canSubmit: map['canSubmit'],
    );
  }

  String toJson() => json.encode(toMap());

  factory OrderModel.fromJson(String source) =>
      OrderModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'OrderModel(id: $id, user: $user, userId: $userId, purchaseDate: $purchaseDate, description: $description, phonenumber: $phonenumber, lat: $lat, lng: $lng, address: $address, paymentMethod: $paymentMethod, orderStatus: $orderStatus, orderDetails: $orderDetails, price: $price, createdDate: $createdDate)';
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
        other.createdDate == createdDate;
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
        createdDate.hashCode;
  }
}
