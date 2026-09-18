import 'dart:convert';

import 'package:app_jtak_warehouse/src/core/enums/order_details_status_enum.dart';
import 'package:app_jtak_warehouse/src/core/enums/order_status_enum.dart';
import 'package:flutter/foundation.dart';

import 'package:app_jtak_warehouse/src/core/enums/payment_method_enum.dart';

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
  String? address;
  PaymentMethod? paymentMethod;
  OrderStatus? orderStatus;
  List<OrderDetailsModel>? orderDetails;
  double? price;
  String? createdDate;
  String? deliveryId;
  String? deliveryUser;
  String? deliveryUserPhone;
  String? deliveryNotes;
  String? notes;
  int? prepTimeMinutes;
  bool? isDeliveryAssigned;
  bool? isDeliveryAccepted;

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
    this.deliveryId,
    this.deliveryUser,
    this.deliveryUserPhone,
    this.deliveryNotes,
    this.notes,
    this.prepTimeMinutes,
    this.isDeliveryAssigned,
    this.isDeliveryAccepted,
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
    List<OrderDetailsModel>? orderDetails,
    double? price,
    String? createdDate,
    String? deliveryId,
    String? deliveryUser,
    String? deliveryUserPhone,
    String? deliveryNotes,
    String? notes,
    int? prepTimeMinutes,
    bool? isDeliveryAssigned,
    bool? isDeliveryAccepted,
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
      deliveryId: deliveryId ?? this.deliveryId,
      deliveryUser: deliveryUser ?? this.deliveryUser,
      deliveryUserPhone: deliveryUserPhone ?? this.deliveryUserPhone,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      notes: notes ?? this.notes,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      isDeliveryAssigned: isDeliveryAssigned ?? this.isDeliveryAssigned,
      isDeliveryAccepted: isDeliveryAccepted ?? this.isDeliveryAccepted,
    );
  }

  bool get hasCourierAssigned =>
      (deliveryId != null && deliveryId!.isNotEmpty) ||
      (deliveryUser != null && deliveryUser!.trim().isNotEmpty) ||
      (deliveryUserPhone != null && deliveryUserPhone!.trim().isNotEmpty);

  bool get isCourierAccepted {
    if (isDeliveryAccepted == true) return true;
    if (orderDetails != null && orderDetails!.isNotEmpty) {
      return orderDetails!.any((d) =>
          d.orderDetailStatus == OrderDetailsStatus.shipping ||
          d.orderDetailStatus == OrderDetailsStatus.delivered);
    }
    return false;
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
      'deliveryId': deliveryId,
      'deliveryUser': deliveryUser,
      'deliveryUserPhone': deliveryUserPhone,
      'deliveryNotes': deliveryNotes,
      'notes': notes,
      'prepTimeMinutes': prepTimeMinutes,
      'isDeliveryAssigned': isDeliveryAssigned,
      'isDeliveryAccepted': isDeliveryAccepted,
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    final paymentRaw = map['paymentMethod'] ?? map['PaymentMethod'];
    final statusRaw = map['orderStatus'] ?? map['OrderStatus'];
    final detailsRaw = map['orderDetails'] ?? map['OrderDetails'];

    return OrderModel(
      id: (map['id'] ?? map['Id']) is num ? (map['id'] ?? map['Id']).toInt() : int.tryParse('${map['id'] ?? map['Id']}'),
      user: (map['user'] ?? map['User'])?.toString(),
      userId: (map['userId'] ?? map['UserId'])?.toString(),
      purchaseDate: (map['purchaseDate'] ?? map['PurchaseDate'])?.toString(),
      description: (map['description'] ?? map['Description'])?.toString(),
      phonenumber: (map['phonenumber'] ?? map['Phonenumber'] ?? map['phoneNumber'])?.toString(),
      lat: (map['lat'] ?? map['Lat']) is num ? (map['lat'] ?? map['Lat']).toDouble() : double.tryParse('${map['lat'] ?? map['Lat']}'),
      lng: (map['lng'] ?? map['Lng']) is num ? (map['lng'] ?? map['Lng']).toDouble() : double.tryParse('${map['lng'] ?? map['Lng']}'),
      address: (map['address'] ?? map['Address'])?.toString(),
      paymentMethod: paymentRaw != null ? parsePaymentMethodSafe(paymentRaw) : PaymentMethod.payOnDelivery,
      orderStatus: statusRaw != null ? parseOrderStatusSafe(statusRaw) : OrderStatus.pending,
      orderDetails: detailsRaw != null
          ? List<OrderDetailsModel>.from(
              detailsRaw.map((x) => OrderDetailsModel.fromMap(x is Map<String, dynamic> ? x : Map<String, dynamic>.from(x))),
            )
          : null,
      price: (map['price'] ?? map['Price']) is num ? (map['price'] ?? map['Price']).toDouble() : double.tryParse('${map['price'] ?? map['Price']}'),
      createdDate: (map['createdDate'] ?? map['CreatedDate'])?.toString(),
      deliveryId: (map['deliveryId'] ?? map['DeliveryId'])?.toString(),
      deliveryUser: (map['deliveryUser'] ?? map['DeliveryUser'])?.toString(),
      deliveryUserPhone: (map['deliveryUserPhone'] ?? map['DeliveryUserPhone'])?.toString(),
      deliveryNotes: (map['deliveryNotes'] ?? map['DeliveryNotes'])?.toString(),
      notes: (map['notes'] ?? map['Notes'])?.toString(),
      prepTimeMinutes: (map['prepTimeMinutes'] ?? map['PrepTimeMinutes']) is num ? (map['prepTimeMinutes'] ?? map['PrepTimeMinutes']).toInt() : int.tryParse('${map['prepTimeMinutes'] ?? map['PrepTimeMinutes']}'),
      isDeliveryAssigned: map['isDeliveryAssigned'] ?? map['IsDeliveryAssigned'],
      isDeliveryAccepted: map['isDeliveryAccepted'] ?? map['IsDeliveryAccepted'],
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
