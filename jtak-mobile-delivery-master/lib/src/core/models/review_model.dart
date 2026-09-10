import 'dart:convert';

class ReviewModel {
  int? id;
  String? text;
  double? rate;
  String? reviewerId;
  String? reviewer;
  int? productId;
  bool? isApproved;
  ReviewModel({
    this.id,
    this.text,
    this.rate,
    this.reviewerId,
    this.reviewer,
    this.productId,
    this.isApproved,
  });

  ReviewModel copyWith({
    int? id,
    String? text,
    double? rate,
    String? reviewerId,
    String? reviewer,
    int? productId,
    bool? isApproved,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      text: text ?? this.text,
      rate: rate ?? this.rate,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewer: reviewer ?? this.reviewer,
      productId: productId ?? this.productId,
      isApproved: isApproved ?? this.isApproved,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'rate': rate,
      'reviewerId': reviewerId,
      'reviewer': reviewer,
      'productId': productId,
      'isApproved': isApproved,
    };
  }

  factory ReviewModel.fromMap(Map<String, dynamic> map) {
    return ReviewModel(
      id: map['id'],
      text: map['text'],
      rate: map['rate']?.toDouble() ?? 0.0,
      reviewerId: map['reviewerId'],
      reviewer: map['reviewer'],
      productId: map['productId'],
      isApproved: map['isApproved'],
    );
  }

  String toJson() => json.encode(toMap());

  factory ReviewModel.fromJson(String source) => ReviewModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'Review(id: $id, text: $text, rate: $rate, reviewerId: $reviewerId, reviewer: $reviewer, productId: $productId, isApproved: $isApproved)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ReviewModel &&
        other.id == id &&
        other.text == text &&
        other.rate == rate &&
        other.reviewerId == reviewerId &&
        other.reviewer == reviewer &&
        other.productId == productId &&
        other.isApproved == isApproved;
  }

  @override
  int get hashCode {
    return id.hashCode ^ text.hashCode ^ rate.hashCode ^ reviewerId.hashCode ^ reviewer.hashCode ^ productId.hashCode ^ isApproved.hashCode;
  }
}
