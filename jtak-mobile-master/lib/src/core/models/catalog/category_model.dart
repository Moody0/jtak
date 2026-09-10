import 'dart:convert';

import 'package:flutter/foundation.dart';

class CategoryModel {
  int? id;
  String? title;
  String? icon;
  int? merchantId;
  String? merchant;
  int? parentId;
  String? parent;
  bool? active;
  int? order;
  List<CategoryModel>? subCategories;

  CategoryModel({
    this.id,
    this.title,
    this.icon,
    this.merchantId,
    this.merchant,
    this.parentId,
    this.parent,
    this.active,
    this.order,
    this.subCategories,
  }) {
    subCategories ??= [];
  }

  CategoryModel copyWith({
    int? id,
    String? title,
    String? icon,
    int? merchantId,
    String? merchant,
    int? parentId,
    String? parent,
    bool? active,
    int? order,
    List<CategoryModel>? subCategories,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      merchantId: merchantId ?? this.merchantId,
      merchant: merchant ?? this.merchant,
      parentId: parentId ?? this.parentId,
      parent: parent ?? this.parent,
      active: active ?? this.active,
      order: order ?? this.order,
      subCategories: subCategories ?? this.subCategories,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'icon': icon,
      'merchantId': merchantId,
      'merchant': merchant,
      'parentId': parentId,
      'parent': parent,
      'active': active,
      'order': order,
      'subCategories': subCategories!.map((x) => x.toMap()).toList(),
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'],
      title: map['title'],
      icon: map['icon'],
      merchantId: map['merchantId'],
      merchant: map['merchant'],
      parentId: map['parentId'],
      parent: map['parent'],
      active: map['active'],
      order: map['order'] != null ? int.tryParse(map['order'].toString()) : null,
      subCategories: List<CategoryModel>.from(map['subCategories']?.map((x) => CategoryModel.fromMap(x))),
    );
  }

  String toJson() => json.encode(toMap());

  factory CategoryModel.fromJson(String source) => CategoryModel.fromMap(json.decode(source));

  @override
  String toString() {
    return title ?? '';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CategoryModel &&
        other.id == id &&
        other.title == title &&
        other.icon == icon &&
        other.merchantId == merchantId &&
        other.merchant == merchant &&
        other.parentId == parentId &&
        other.parent == parent &&
        other.active == active &&
        listEquals(other.subCategories, subCategories);
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        icon.hashCode ^
        merchantId.hashCode ^
        merchant.hashCode ^
        parentId.hashCode ^
        parent.hashCode ^
        active.hashCode ^
        subCategories.hashCode;
  }
}
