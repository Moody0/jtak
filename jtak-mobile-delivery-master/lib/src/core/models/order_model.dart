import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:app_jtak_delivery/src/core/enums/order_details_status_enum.dart';
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
  String? notes;
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
    this.notes,
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
    String? notes,
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
      notes: notes ?? this.notes,
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
      'notes': notes,
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
      notes: map['notes'] ?? map['Notes'],
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

  // ---------------------------------------------------------------------------
  // Delivery Lifecycle & Status Helpers
  // ---------------------------------------------------------------------------

  /// List of active (non-canceled, non-rejected) merchant stops
  List<MerchentOrderDetailsModel> get activeMerchants {
    if (orderDetails == null || orderDetails!.isEmpty) {
      return [];
    }
    return orderDetails!.where((m) =>
        m.orderDetailStatus != OrderDetailsStatus.merchantRejected &&
        m.orderDetailStatus != OrderDetailsStatus.customerCanceled &&
        m.orderDetailStatus != OrderDetailsStatus.deliveryCanceled).toList();
  }

  /// Evaluates the true driver-facing fulfillment status of this order
  OrderDetailsStatus get deliveryStatus {
    if (orderDetails == null || orderDetails!.isEmpty) {
      return OrderDetailsStatus.pending;
    }

    final allItems = orderDetails!;

    // 1. All merchants terminal canceled/rejected
    final allTerminal = allItems.every((e) =>
        e.orderDetailStatus == OrderDetailsStatus.merchantRejected ||
        e.orderDetailStatus == OrderDetailsStatus.customerCanceled ||
        e.orderDetailStatus == OrderDetailsStatus.deliveryCanceled);
    if (allTerminal) {
      if (allItems.any((e) => e.orderDetailStatus == OrderDetailsStatus.deliveryCanceled)) {
        return OrderDetailsStatus.deliveryCanceled;
      }
      if (allItems.any((e) => e.orderDetailStatus == OrderDetailsStatus.customerCanceled)) {
        return OrderDetailsStatus.customerCanceled;
      }
      return OrderDetailsStatus.merchantRejected;
    }

    final active = activeMerchants;
    if (active.isEmpty) return OrderDetailsStatus.pending;

    // 2. All active merchants delivered
    if (active.every((e) => e.orderDetailStatus == OrderDetailsStatus.delivered)) {
      return OrderDetailsStatus.delivered;
    }

    // 3. All active merchants picked up and in transit to customer
    if (active.every((e) =>
        e.orderDetailStatus == OrderDetailsStatus.shipping ||
        e.orderDetailStatus == OrderDetailsStatus.delivered)) {
      return OrderDetailsStatus.shipping;
    }

    // 4. Any active merchant ready for pickup
    if (active.any((e) => e.orderDetailStatus == OrderDetailsStatus.readyForPickup)) {
      return OrderDetailsStatus.readyForPickup;
    }

    // 5. Merchant preparing
    if (active.any((e) => e.orderDetailStatus == OrderDetailsStatus.merchantAccepted)) {
      return OrderDetailsStatus.merchantAccepted;
    }

    // 6. Customer pending / pending
    if (active.any((e) => e.orderDetailStatus == OrderDetailsStatus.customerPending)) {
      return OrderDetailsStatus.customerPending;
    }

    return OrderDetailsStatus.pending;
  }

  bool get isDelivered => deliveryStatus == OrderDetailsStatus.delivered;

  bool get isCanceled =>
      deliveryStatus == OrderDetailsStatus.deliveryCanceled ||
      deliveryStatus == OrderDetailsStatus.customerCanceled ||
      deliveryStatus == OrderDetailsStatus.merchantRejected;

  bool get isTerminal => isDelivered || isCanceled;

  /// True if payment is Cash on Delivery (driver collects cash from customer)
  bool get isCod => paymentMethod == PaymentMethod.payOnDelivery;

  /// True when all active merchant items are in transit and the order can be delivered to customer
  bool get canDeliverToCustomer {
    if (isTerminal) return false;
    final active = activeMerchants;
    return active.isNotEmpty &&
        active.every((e) =>
            e.orderDetailStatus == OrderDetailsStatus.shipping ||
            e.orderDetailStatus == OrderDetailsStatus.delivered);
  }

  /// True if there are merchant pickups still waiting to be collected
  bool get hasPendingPickups {
    if (isTerminal) return false;
    return activeMerchants.any((e) =>
        e.orderDetailStatus == OrderDetailsStatus.readyForPickup ||
        e.orderDetailStatus == OrderDetailsStatus.merchantAccepted ||
        e.orderDetailStatus == OrderDetailsStatus.pending);
  }

  /// The next merchant stop requiring courier pickup
  MerchentOrderDetailsModel? get nextPendingMerchant {
    return activeMerchants.cast<MerchentOrderDetailsModel?>().firstWhere(
      (m) =>
          m != null &&
          (m.orderDetailStatus == OrderDetailsStatus.readyForPickup ||
              m.orderDetailStatus == OrderDetailsStatus.merchantAccepted ||
              m.orderDetailStatus == OrderDetailsStatus.pending),
      orElse: () => null,
    );
  }

  int get totalMerchantsCount => activeMerchants.length;

  int get pickedUpMerchantsCount => activeMerchants
      .where((m) =>
          m.orderDetailStatus == OrderDetailsStatus.shipping ||
          m.orderDetailStatus == OrderDetailsStatus.delivered)
      .length;

  String get primaryMerchantTitle {
    if (orderDetails != null && orderDetails!.isNotEmpty) {
      final title = orderDetails!.first.merchantTitle?.trim();
      if (title != null && title.isNotEmpty && title != 'null') return title;
    }
    return 'متجر غير محدد';
  }

  String get primaryMerchantAddress {
    if (orderDetails != null && orderDetails!.isNotEmpty) {
      final addr = orderDetails!.first.merchantAddress?.trim();
      if (addr != null && addr.isNotEmpty && addr != 'null') return addr;
    }
    return address?.trim() ?? 'العنوان غير متوفر';
  }
}
