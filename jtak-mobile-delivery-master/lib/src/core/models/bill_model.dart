import 'dart:convert';

import 'package:app_jtak_delivery/src/core/enums/payment_method_enum.dart';

class BillModel {
  int? id;
  int? merchantId;
  int? merchantAmount;
  double? totalAmount;
  int? jTakAmount;
  int? jTakAdditionalAmount;
  PaymentMethod? paymentMethod;
  int? orderId;
  String? dueDate;
  String? createdDate;
  BillModel({
    this.id,
    this.merchantId,
    this.merchantAmount,
    this.totalAmount,
    this.jTakAmount,
    this.jTakAdditionalAmount,
    this.paymentMethod,
    this.orderId,
    this.dueDate,
    this.createdDate,
  });

  BillModel copyWith({
    int? id,
    int? merchantId,
    int? merchantAmount,
    double? totalAmount,
    int? jTakAmount,
    int? jTakAdditionalAmount,
    PaymentMethod? paymentMethod,
    int? orderId,
    String? dueDate,
    String? createdDate,
  }) {
    return BillModel(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      merchantAmount: merchantAmount ?? this.merchantAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      jTakAmount: jTakAmount ?? this.jTakAmount,
      jTakAdditionalAmount: jTakAdditionalAmount ?? this.jTakAdditionalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      orderId: orderId ?? this.orderId,
      dueDate: dueDate ?? this.dueDate,
      createdDate: createdDate ?? this.createdDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'merchantId': merchantId,
      'merchantAmount': merchantAmount,
      'totalAmount': totalAmount,
      'jTakAmount': jTakAmount,
      'jTakAdditionalAmount': jTakAdditionalAmount,
      'paymentMethod': paymentMethod?.index,
      'orderId': orderId,
      'dueDate': dueDate,
      'createdDate': createdDate,
    };
  }

  factory BillModel.fromMap(Map<String, dynamic> map) {
    return BillModel(
      id: map['id']?.toInt(),
      merchantId: map['merchantId']?.toInt(),
      merchantAmount: map['merchantAmount']?.toInt(),
      totalAmount: map['totalAmount']?.toDouble(),
      jTakAmount: map['jTakAmount']?.toInt(),
      jTakAdditionalAmount: map['jTakAdditionalAmount']?.toInt(),
      paymentMethod: map['paymentMethod'] != null ? (map['paymentMethod'] as int).parsePaymentMethod : null,
      orderId: map['orderId']?.toInt(),
      dueDate: map['dueDate'],
      createdDate: map['createdDate'],
    );
  }

  String toJson() => json.encode(toMap());

  factory BillModel.fromJson(String source) => BillModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'BillModel(id: $id, merchantId: $merchantId, merchantAmount: $merchantAmount, totalAmount: $totalAmount, jTakAmount: $jTakAmount, jTakAdditionalAmount: $jTakAdditionalAmount, paymentMethod: $paymentMethod, orderId: $orderId, dueDate: $dueDate, createdDate: $createdDate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is BillModel &&
        other.id == id &&
        other.merchantId == merchantId &&
        other.merchantAmount == merchantAmount &&
        other.totalAmount == totalAmount &&
        other.jTakAmount == jTakAmount &&
        other.jTakAdditionalAmount == jTakAdditionalAmount &&
        other.paymentMethod == paymentMethod &&
        other.orderId == orderId &&
        other.dueDate == dueDate &&
        other.createdDate == createdDate;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        merchantId.hashCode ^
        merchantAmount.hashCode ^
        totalAmount.hashCode ^
        jTakAmount.hashCode ^
        jTakAdditionalAmount.hashCode ^
        paymentMethod.hashCode ^
        orderId.hashCode ^
        dueDate.hashCode ^
        createdDate.hashCode;
  }
}
