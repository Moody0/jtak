import 'dart:convert';

class BalancesModel {
  String? id;
  double? amount;
  double? pendingAmount;
  double? maxCashFloat;
  double? availableAmount;
  bool hasPendingSettlement;
  String? createdDate;
  BalancesModel({
    this.id,
    this.amount,
    this.pendingAmount,
    this.maxCashFloat = 5000.0,
    this.availableAmount,
    this.hasPendingSettlement = false,
    this.createdDate,
  });

  BalancesModel copyWith({
    String? id,
    double? amount,
    double? pendingAmount,
    double? maxCashFloat,
    double? availableAmount,
    bool? hasPendingSettlement,
    String? createdDate,
  }) {
    return BalancesModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      pendingAmount: pendingAmount ?? this.pendingAmount,
      maxCashFloat: maxCashFloat ?? this.maxCashFloat,
      availableAmount: availableAmount ?? this.availableAmount,
      hasPendingSettlement: hasPendingSettlement ?? this.hasPendingSettlement,
      createdDate: createdDate ?? this.createdDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'pendingAmount': pendingAmount,
      'maxCashFloat': maxCashFloat,
      'availableAmount': availableAmount,
      'hasPendingSettlement': hasPendingSettlement,
      'createdDate': createdDate,
    };
  }

  factory BalancesModel.fromMap(Map<String, dynamic> map) {
    final rawMaxCashFloat = map['maxCashFloat'] ?? map['maxCashLimit'];
    final parsedMaxCashFloat = rawMaxCashFloat is num
        ? rawMaxCashFloat.toDouble()
        : double.tryParse(rawMaxCashFloat?.toString() ?? '');

    return BalancesModel(
      id: map['id']?.toString(),
      amount: _readAmount(map['amount']),
      pendingAmount: _readAmount(map['pendingAmount']),
      maxCashFloat: parsedMaxCashFloat ?? 5000.0,
      availableAmount: _readAmount(map['availableAmount']),
      hasPendingSettlement: map['hasPendingSettlement'] == true ||
          (_readAmount(map['pendingAmount']) ?? 0) > 0,
      createdDate: map['createdDate']?.toString(),
    );
  }

  static double? _readAmount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String toJson() => json.encode(toMap());

  factory BalancesModel.fromJson(String source) =>
      BalancesModel.fromMap(json.decode(source));

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
    return id.hashCode ^
        amount.hashCode ^
        pendingAmount.hashCode ^
        createdDate.hashCode;
  }
}
