import 'dart:convert';

class FavoriteProductModel {
  String? userId;
  int? productId;
  String? productTitle;
  String? productImage;

  FavoriteProductModel({
    this.userId,
    this.productId,
    this.productTitle,
    this.productImage,
  });

  FavoriteProductModel copyWith({
    String? userId,
    int? productId,
    String? productTitle,
    String? productImage,
  }) {
    return FavoriteProductModel(
      userId: userId ?? this.userId,
      productId: productId ?? this.productId,
      productTitle: productTitle ?? this.productTitle,
      productImage: productImage ?? this.productImage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'productId': productId,
      'productTitle': productTitle,
      'productImage': productImage,
    };
  }

  factory FavoriteProductModel.fromMap(Map<String, dynamic> map) {
    return FavoriteProductModel(
      userId: map['userId'],
      productId: map['productId']?.toInt(),
      productTitle: map['productTitle'],
      productImage: map['productImage'],
    );
  }

  String toJson() => json.encode(toMap());

  factory FavoriteProductModel.fromJson(String source) => FavoriteProductModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'FavoriteProductModel(userId: $userId, productId: $productId, productTitle: $productTitle, productImage: $productImage)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is FavoriteProductModel &&
        other.userId == userId &&
        other.productId == productId &&
        other.productTitle == productTitle &&
        other.productImage == productImage;
  }

  @override
  int get hashCode {
    return userId.hashCode ^ productId.hashCode ^ productTitle.hashCode ^ productImage.hashCode;
  }
}
