import 'dart:convert';

class BalancesModel {
  String? id;
  double? amount;
  double? pendingAmount;
  String? createdDate;
  BalancesModel({
    this.id,
    this.amount,
    this.pendingAmount,
    this.createdDate,
  });

  BalancesModel copyWith({
    String? id,
    double? amount,
    double? pendingAmount,
    String? createdDate,
  }) {
    return BalancesModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      pendingAmount: pendingAmount ?? this.pendingAmount,
      createdDate: createdDate ?? this.createdDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'pendingAmount': pendingAmount,
      'createdDate': createdDate,
    };
  }

  factory BalancesModel.fromMap(Map<String, dynamic> map) {
    return BalancesModel(
      id: map['id'],
      amount: map['amount']?.toDouble(),
      pendingAmount: map['pendingAmount']?.toDouble(),
      createdDate: map['createdDate'],
    );
  }

  String toJson() => json.encode(toMap());

  factory BalancesModel.fromJson(String source) => BalancesModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'BalancesModel(id: $id, amount: $amount, pendingAmount: $pendingAmount, createdDate: $createdDate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is BalancesModel &&
        other.id == id &&
        other.amount == amount &&
        other.pendingAmount == pendingAmount &&
        other.createdDate == createdDate;
  }

  @override
  int get hashCode {
    return id.hashCode ^ amount.hashCode ^ pendingAmount.hashCode ^ createdDate.hashCode;
  }
}
