import 'dart:convert';

class BalancesModel {
  String? id;
  double amount;
  double pendingAmount;
  String? createdDate;
  double todayGrossSales;
  double todayNetEarnings;
  int todayOrdersCount;
  double monthGrossSales;
  double monthNetEarnings;
  int monthOrdersCount;
  double totalPayoutsReceived;
  int totalPayoutsCount;

  BalancesModel({
    this.id,
    this.amount = 0.0,
    this.pendingAmount = 0.0,
    this.createdDate,
    this.todayGrossSales = 0.0,
    this.todayNetEarnings = 0.0,
    this.todayOrdersCount = 0,
    this.monthGrossSales = 0.0,
    this.monthNetEarnings = 0.0,
    this.monthOrdersCount = 0,
    this.totalPayoutsReceived = 0.0,
    this.totalPayoutsCount = 0,
  });

  BalancesModel copyWith({
    String? id,
    double? amount,
    double? pendingAmount,
    String? createdDate,
    double? todayGrossSales,
    double? todayNetEarnings,
    int? todayOrdersCount,
    double? monthGrossSales,
    double? monthNetEarnings,
    int? monthOrdersCount,
    double? totalPayoutsReceived,
    int? totalPayoutsCount,
  }) {
    return BalancesModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      pendingAmount: pendingAmount ?? this.pendingAmount,
      createdDate: createdDate ?? this.createdDate,
      todayGrossSales: todayGrossSales ?? this.todayGrossSales,
      todayNetEarnings: todayNetEarnings ?? this.todayNetEarnings,
      todayOrdersCount: todayOrdersCount ?? this.todayOrdersCount,
      monthGrossSales: monthGrossSales ?? this.monthGrossSales,
      monthNetEarnings: monthNetEarnings ?? this.monthNetEarnings,
      monthOrdersCount: monthOrdersCount ?? this.monthOrdersCount,
      totalPayoutsReceived: totalPayoutsReceived ?? this.totalPayoutsReceived,
      totalPayoutsCount: totalPayoutsCount ?? this.totalPayoutsCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'pendingAmount': pendingAmount,
      'createdDate': createdDate,
      'todayGrossSales': todayGrossSales,
      'todayNetEarnings': todayNetEarnings,
      'todayOrdersCount': todayOrdersCount,
      'monthGrossSales': monthGrossSales,
      'monthNetEarnings': monthNetEarnings,
      'monthOrdersCount': monthOrdersCount,
      'totalPayoutsReceived': totalPayoutsReceived,
      'totalPayoutsCount': totalPayoutsCount,
    };
  }

  factory BalancesModel.fromMap(Map<String, dynamic> map) {
    return BalancesModel(
      id: map['id'],
      amount: ((map['currentBalance'] ?? map['amount']) as num?)?.toDouble() ?? 0.0,
      pendingAmount: ((map['pendingBalance'] ?? map['pendingAmount']) as num?)?.toDouble() ?? 0.0,
      createdDate: map['createdDate'],
      todayGrossSales: (map['todayGrossSales'] as num?)?.toDouble() ?? 0.0,
      todayNetEarnings: (map['todayNetEarnings'] as num?)?.toDouble() ?? 0.0,
      todayOrdersCount: (map['todayOrdersCount'] as num?)?.toInt() ?? 0,
      monthGrossSales: (map['monthGrossSales'] as num?)?.toDouble() ?? 0.0,
      monthNetEarnings: (map['monthNetEarnings'] as num?)?.toDouble() ?? 0.0,
      monthOrdersCount: (map['monthOrdersCount'] as num?)?.toInt() ?? 0,
      totalPayoutsReceived: (map['totalPayoutsReceived'] as num?)?.toDouble() ?? 0.0,
      totalPayoutsCount: (map['totalPayoutsCount'] as num?)?.toInt() ?? 0,
    );
  }

  String toJson() => json.encode(toMap());

  factory BalancesModel.fromJson(String source) => BalancesModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'BalancesModel(amount: $amount, todayGrossSales: $todayGrossSales, todayOrdersCount: $todayOrdersCount)';
  }
}
