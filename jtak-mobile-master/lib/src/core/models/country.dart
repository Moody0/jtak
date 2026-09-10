import 'dart:convert';

import 'package:flutter/foundation.dart';

class CountryModel {
  int id;
  String title;
  String nationalityName;
  int? defaultCurrency;
  List<CityModel> cities;
  CountryModel({
    required this.id,
    required this.title,
    required this.nationalityName,
    this.defaultCurrency,
    required this.cities,
  });

  CountryModel copyWith({
    int? id,
    String? title,
    String? nationalityName,
    int? defaultCurrency,
    List<CityModel>? cities,
  }) {
    return CountryModel(
      id: id ?? this.id,
      title: title ?? this.title,
      nationalityName: nationalityName ?? this.nationalityName,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      cities: cities ?? this.cities,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'nationalityName': nationalityName,
      'defaultCurrency': defaultCurrency,
      'cities': cities.map((x) => x.toMap()).toList(),
    };
  }

  factory CountryModel.fromMap(Map<String, dynamic> map) {
    return CountryModel(
      id: map['id']?.toInt() ?? 0,
      title: map['title'] ?? '',
      nationalityName: map['nationalityName'] ?? '',
      defaultCurrency: map['defaultCurrency']?.toInt(),
      cities: List<CityModel>.from(map['cities']?.map((x) => CityModel.fromMap(x))),
    );
  }

  String toJson() => json.encode(toMap());

  factory CountryModel.fromJson(String source) => CountryModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'Country(id: $id, title: $title, nationalityName: $nationalityName, defaultCurrency: $defaultCurrency, cities: $cities)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CountryModel &&
        other.id == id &&
        other.title == title &&
        other.nationalityName == nationalityName &&
        other.defaultCurrency == defaultCurrency &&
        listEquals(other.cities, cities);
  }

  @override
  int get hashCode {
    return id.hashCode ^ title.hashCode ^ nationalityName.hashCode ^ defaultCurrency.hashCode ^ cities.hashCode;
  }
}

class CityModel {
  int id;
  String title;
  int countryId;
  CityModel({
    required this.id,
    required this.title,
    required this.countryId,
  });

  CityModel copyWith({
    int? id,
    String? title,
    int? countryId,
  }) {
    return CityModel(
      id: id ?? this.id,
      title: title ?? this.title,
      countryId: countryId ?? this.countryId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'countryId': countryId,
    };
  }

  factory CityModel.fromMap(Map<String, dynamic> map) {
    return CityModel(
      id: map['id']?.toInt() ?? 0,
      title: map['title'] ?? '',
      countryId: map['countryId']?.toInt() ?? 0,
    );
  }

  String toJson() => json.encode(toMap());

  factory CityModel.fromJson(String source) => CityModel.fromMap(json.decode(source));

  @override
  String toString() => 'City(id: $id, title: $title, countryId: $countryId)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CityModel && other.id == id && other.title == title && other.countryId == countryId;
  }

  @override
  int get hashCode => id.hashCode ^ title.hashCode ^ countryId.hashCode;
}
