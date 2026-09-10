import 'dart:convert';

class ProductReviewModel {
  int? id;
  String? reviewerId;
  int? productId;
  String? productTitle;
  String? productImage;
  double? rate;
  String? textReview;
  String? imageReview;
  bool? isApproved;

  ProductReviewModel({
    this.id,
    this.reviewerId,
    this.productId,
    this.productTitle,
    this.productImage,
    this.rate,
    this.textReview,
    this.imageReview,
    this.isApproved,
  });

  ProductReviewModel copyWith({
    int? id,
    String? reviewerId,
    int? productId,
    String? productTitle,
    String? productImage,
    double? rate,
    String? textReview,
    String? imageReview,
    bool? isApproved,
  }) {
    return ProductReviewModel(
      id: id ?? this.id,
      reviewerId: reviewerId ?? this.reviewerId,
      productId: productId ?? this.productId,
      productTitle: productTitle ?? this.productTitle,
      productImage: productImage ?? this.productImage,
      rate: rate ?? this.rate,
      textReview: textReview ?? this.textReview,
      imageReview: imageReview ?? this.imageReview,
      isApproved: isApproved ?? this.isApproved,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reviewerId': reviewerId,
      'productId': productId,
      'productTitle': productTitle,
      'productImage': productImage,
      'rate': rate,
      'textReview': textReview,
      'imageReview': imageReview,
      'isApproved': isApproved,
    };
  }

  factory ProductReviewModel.fromMap(Map<String, dynamic> map) {
    return ProductReviewModel(
      id: map['id']?.toInt(),
      reviewerId: map['reviewerId'],
      productId: map['productId']?.toInt(),
      productTitle: map['productTitle'],
      productImage: map['productImage'],
      rate: map['rate']?.toDouble(),
      textReview: map['textReview'],
      imageReview: map['imageReview'],
      isApproved: map['isApproved'],
    );
  }

  String toJson() => json.encode(toMap());

  factory ProductReviewModel.fromJson(String source) => ProductReviewModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'ProductReviewModel(id: $id, reviewerId: $reviewerId, productId: $productId, productTitle: $productTitle, productImage: $productImage, rate: $rate, textReview: $textReview, imageReview: $imageReview, isApproved: $isApproved)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ProductReviewModel &&
        other.id == id &&
        other.reviewerId == reviewerId &&
        other.productId == productId &&
        other.productTitle == productTitle &&
        other.productImage == productImage &&
        other.rate == rate &&
        other.textReview == textReview &&
        other.imageReview == imageReview &&
        other.isApproved == isApproved;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        reviewerId.hashCode ^
        productId.hashCode ^
        productTitle.hashCode ^
        productImage.hashCode ^
        rate.hashCode ^
        textReview.hashCode ^
        imageReview.hashCode ^
        isApproved.hashCode;
  }
}
