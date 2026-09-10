import 'dart:convert';

class PaymentModel {
  int? id;
  String? toUserId;
  String? toUser;
  String? byUserId;
  String? byUser;
  double? amount;
  double? newBalance;
  String? handoverDate;
  PaymentModel({
    this.id,
    this.toUserId,
    this.toUser,
    this.byUserId,
    this.byUser,
    this.amount,
    this.newBalance,
    this.handoverDate,
  });

  PaymentModel copyWith({
    int? id,
    String? toUserId,
    String? toUser,
    String? byUserId,
    String? byUser,
    double? amount,
    double? newBalance,
    String? handoverDate,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      toUserId: toUserId ?? this.toUserId,
      toUser: toUser ?? this.toUser,
      byUserId: byUserId ?? this.byUserId,
      byUser: byUser ?? this.byUser,
      amount: amount ?? this.amount,
      newBalance: newBalance ?? this.newBalance,
      handoverDate: handoverDate ?? this.handoverDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'toUserId': toUserId,
      'toUser': toUser,
      'byUserId': byUserId,
      'byUser': byUser,
      'amount': amount,
      'newBalance': newBalance,
      'handoverDate': handoverDate,
    };
  }

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      id: map['id']?.toInt(),
      toUserId: map['toUserId'],
      toUser: map['toUser'],
      byUserId: map['byUserId'],
      byUser: map['byUser'],
      amount: map['amount']?.toDouble(),
      newBalance: map['newBalance']?.toDouble(),
      handoverDate: map['handoverDate'],
    );
  }

  String toJson() => json.encode(toMap());

  factory PaymentModel.fromJson(String source) => PaymentModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'PaymentModel(id: $id, toUserId: $toUserId, toUser: $toUser, byUserId: $byUserId, byUser: $byUser, amount: $amount, newBalance: $newBalance, handoverDate: $handoverDate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PaymentModel &&
        other.id == id &&
        other.toUserId == toUserId &&
        other.toUser == toUser &&
        other.byUserId == byUserId &&
        other.byUser == byUser &&
        other.amount == amount &&
        other.newBalance == newBalance &&
        other.handoverDate == handoverDate;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        toUserId.hashCode ^
        toUser.hashCode ^
        byUserId.hashCode ^
        byUser.hashCode ^
        amount.hashCode ^
        newBalance.hashCode ^
        handoverDate.hashCode;
  }
}
