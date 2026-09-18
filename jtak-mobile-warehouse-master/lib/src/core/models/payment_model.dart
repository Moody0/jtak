import 'dart:convert';

class PaymentModel {
  int? id;
  String? requestId;
  String? requestNumber;
  int? status; // 0: Pending, 1: Approved, 2: Rejected, 3: Completed
  String? toUserId;
  String? toUser;
  String? byUserId;
  String? byUser;
  double? amount;
  String? currency;
  String? method;
  String? accountDetails;
  String? notes;
  String? rejectionReason;
  double? newBalance;
  String? handoverDate;
  String? reviewedAt;
  String? completedAt;
  String? createdDate;

  PaymentModel({
    this.id,
    this.requestId,
    this.requestNumber,
    this.status,
    this.toUserId,
    this.toUser,
    this.byUserId,
    this.byUser,
    this.amount,
    this.currency,
    this.method,
    this.accountDetails,
    this.notes,
    this.rejectionReason,
    this.newBalance,
    this.handoverDate,
    this.reviewedAt,
    this.completedAt,
    this.createdDate,
  });

  bool get isSettlementRequest => requestId != null && requestId!.isNotEmpty;
  bool get isReceived => (handoverDate != null && handoverDate!.isNotEmpty) || (status == 3);
  bool get isApprovedPendingReceipt => status == 1;
  bool get isPendingReview => status == 0;
  bool get isRejected => status == 2;
  String get displayId => requestNumber ?? (id != null ? '#$id' : '');

  PaymentModel copyWith({
    int? id,
    String? requestId,
    String? requestNumber,
    int? status,
    String? toUserId,
    String? toUser,
    String? byUserId,
    String? byUser,
    double? amount,
    String? currency,
    String? method,
    String? accountDetails,
    String? notes,
    String? rejectionReason,
    double? newBalance,
    String? handoverDate,
    String? reviewedAt,
    String? completedAt,
    String? createdDate,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      requestNumber: requestNumber ?? this.requestNumber,
      status: status ?? this.status,
      toUserId: toUserId ?? this.toUserId,
      toUser: toUser ?? this.toUser,
      byUserId: byUserId ?? this.byUserId,
      byUser: byUser ?? this.byUser,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      method: method ?? this.method,
      accountDetails: accountDetails ?? this.accountDetails,
      notes: notes ?? this.notes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      newBalance: newBalance ?? this.newBalance,
      handoverDate: handoverDate ?? this.handoverDate,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      completedAt: completedAt ?? this.completedAt,
      createdDate: createdDate ?? this.createdDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requestId': requestId,
      'requestNumber': requestNumber,
      'status': status,
      'toUserId': toUserId,
      'toUser': toUser,
      'byUserId': byUserId,
      'byUser': byUser,
      'amount': amount,
      'currency': currency,
      'method': method,
      'accountDetails': accountDetails,
      'notes': notes,
      'rejectionReason': rejectionReason,
      'newBalance': newBalance,
      'handoverDate': handoverDate,
      'reviewedAt': reviewedAt,
      'completedAt': completedAt,
      'createdDate': createdDate,
    };
  }

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? ''),
      requestId: map['requestId']?.toString() ?? (map['id'] is String ? map['id'] : null),
      requestNumber: map['requestNumber']?.toString(),
      status: (map['status'] as num?)?.toInt(),
      toUserId: map['toUserId']?.toString(),
      toUser: map['toUser']?.toString(),
      byUserId: map['byUserId']?.toString(),
      byUser: map['byUser']?.toString(),
      amount: (map['amount'] as num?)?.toDouble(),
      currency: map['currency']?.toString() ?? 'SYP',
      method: map['method']?.toString(),
      accountDetails: map['accountDetails']?.toString(),
      notes: map['notes']?.toString(),
      rejectionReason: map['rejectionReason']?.toString(),
      newBalance: (map['newBalance'] as num?)?.toDouble(),
      handoverDate: map['handoverDate']?.toString(),
      reviewedAt: map['reviewedAt']?.toString(),
      completedAt: map['completedAt']?.toString(),
      createdDate: map['createdDate']?.toString(),
    );
  }

  factory PaymentModel.fromSettlementRequest(Map<String, dynamic> map) {
    final status = (map['status'] as num?)?.toInt() ?? 0;
    final isCompleted = status == 3;
    final completedAt = map['completedAt']?.toString();
    return PaymentModel(
      id: null,
      requestId: map['id']?.toString(),
      requestNumber: map['requestNumber']?.toString(),
      status: status,
      toUserId: map['requestedByUserId']?.toString(),
      toUser: map['requestedByName']?.toString(),
      byUserId: map['reviewedByAdminId']?.toString(),
      byUser: map['method']?.toString() ?? 'إدارة جيتك',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency']?.toString() ?? 'SYP',
      method: map['method']?.toString(),
      accountDetails: map['accountDetails']?.toString(),
      notes: map['notes']?.toString(),
      rejectionReason: map['rejectionReason']?.toString(),
      newBalance: null,
      handoverDate: isCompleted ? (completedAt ?? DateTime.now().toUtc().toIso8601String()) : null,
      reviewedAt: map['reviewedAt']?.toString(),
      completedAt: completedAt,
      createdDate: map['createdDate']?.toString(),
    );
  }

  String toJson() => json.encode(toMap());

  factory PaymentModel.fromJson(String source) => PaymentModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'PaymentModel(id: $id, requestId: $requestId, requestNumber: $requestNumber, status: $status, amount: $amount, handoverDate: $handoverDate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PaymentModel &&
        other.id == id &&
        other.requestId == requestId &&
        other.requestNumber == requestNumber &&
        other.status == status &&
        other.amount == amount &&
        other.handoverDate == handoverDate;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        requestId.hashCode ^
        requestNumber.hashCode ^
        status.hashCode ^
        amount.hashCode ^
        handoverDate.hashCode;
  }
}
