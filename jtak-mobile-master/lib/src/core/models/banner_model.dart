import 'dart:convert';

class BannerModel {
  int? id;
  String? title;
  String? description;
  int? order;
  String? url;
  bool? active;
  String? featuredImage;
  String? createdDate;
  int? bannerLocation;
  BannerModel({
    this.id,
    this.title,
    this.description,
    this.order,
    this.url,
    this.active,
    this.featuredImage,
    this.createdDate,
    this.bannerLocation,
  });

  BannerModel copyWith({
    int? id,
    String? title,
    String? description,
    int? order,
    String? url,
    bool? active,
    String? featuredImage,
    String? createdDate,
    int? bannerLocation,
  }) {
    return BannerModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      order: order ?? this.order,
      url: url ?? this.url,
      active: active ?? this.active,
      featuredImage: featuredImage ?? this.featuredImage,
      createdDate: createdDate ?? this.createdDate,
      bannerLocation: bannerLocation ?? this.bannerLocation,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'order': order,
      'url': url,
      'active': active,
      'featuredImage': featuredImage,
      'createdDate': createdDate,
      'bannerLocation': bannerLocation,
    };
  }

  factory BannerModel.fromMap(Map<String, dynamic> map) {
    return BannerModel(
      id: map['id']?.toInt(),
      title: map['title'],
      description: map['description'],
      order: map['order']?.toInt(),
      url: map['url'],
      active: map['active'],
      featuredImage: map['featuredImage'],
      createdDate: map['createdDate'],
      bannerLocation: map['bannerLocation']?.toInt(),
    );
  }

  String toJson() => json.encode(toMap());

  factory BannerModel.fromJson(String source) => BannerModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'bannerModel(id: $id, title: $title, description: $description, order: $order, url: $url, active: $active, featuredImage: $featuredImage, createdDate: $createdDate, bannerLocation: $bannerLocation)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is BannerModel &&
        other.id == id &&
        other.title == title &&
        other.description == description &&
        other.order == order &&
        other.url == url &&
        other.active == active &&
        other.featuredImage == featuredImage &&
        other.createdDate == createdDate &&
        other.bannerLocation == bannerLocation;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        description.hashCode ^
        order.hashCode ^
        url.hashCode ^
        active.hashCode ^
        featuredImage.hashCode ^
        createdDate.hashCode ^
        bannerLocation.hashCode;
  }
}
