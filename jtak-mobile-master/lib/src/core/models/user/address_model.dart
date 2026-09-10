import 'dart:convert';

import '../../enums/address_type_enum.dart';

class AddressModel {
  int? id;
  String? userId;
  String? title;
  String? fullName;
  String? phoneNumber;
  String? taxNumber;
  int? country;
  String? level1;
  String? level2;
  String? level3;
  String? level4;
  String? zipPostalCode;
  String? fullAddress;
  String? apartment;
  double? lng;
  double? lat;
  bool? isCompany;
  AddressType? addressType;
  bool? isActive = false;
  AddressModel({
    this.id,
    this.userId,
    this.title,
    this.fullName,
    this.phoneNumber,
    this.taxNumber,
    this.country,
    this.level1,
    this.level2,
    this.level3,
    this.level4,
    this.zipPostalCode,
    this.fullAddress,
    this.apartment,
    this.lng,
    this.lat,
    this.isCompany,
    this.addressType,
    this.isActive,
  });

  AddressModel copyWith({
    int? id,
    String? userId,
    String? title,
    String? fullName,
    String? phoneNumber,
    String? taxNumber,
    int? country,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
    String? zipPostalCode,
    String? fullAddress,
    String? apartment,
    double? lng,
    double? lat,
    bool? isCompany,
    AddressType? addressType,
    bool? isActive,
  }) {
    return AddressModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      taxNumber: taxNumber ?? this.taxNumber,
      country: country ?? this.country,
      level1: level1 ?? this.level1,
      level2: level2 ?? this.level2,
      level3: level3 ?? this.level3,
      level4: level4 ?? this.level4,
      zipPostalCode: zipPostalCode ?? this.zipPostalCode,
      fullAddress: fullAddress ?? this.fullAddress,
      apartment: apartment ?? this.apartment,
      lng: lng ?? this.lng,
      lat: lat ?? this.lat,
      isCompany: isCompany ?? this.isCompany,
      addressType: addressType ?? this.addressType,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'taxNumber': taxNumber,
      'country': country,
      'level1': level1,
      'level2': level2,
      'level3': level3,
      'level4': level4,
      'zipPostalCode': zipPostalCode,
      'fullAddress': fullAddress,
      'apartment': apartment,
      'lng': lng,
      'lat': lat,
      'isCompany': isCompany,
      'addressType': addressType?.index,
      'isActive': isActive,
    };
  }

  factory AddressModel.fromMap(Map<String, dynamic> map) {
    return AddressModel(
      id: map['id']?.toInt(),
      userId: map['userId'],
      title: map['title'],
      fullName: map['fullName'],
      phoneNumber: map['phoneNumber'],
      taxNumber: map['taxNumber'],
      country: map['country']?.toInt(),
      level1: map['level1'],
      level2: map['level2'],
      level3: map['level3'],
      level4: map['level4'],
      zipPostalCode: map['zipPostalCode'],
      fullAddress: map['fullAddress'],
      apartment: map['apartment'],
      lng: map['lng']?.toDouble(),
      lat: map['lat']?.toDouble(),
      isCompany: map['isCompany'],
      addressType: map['addressType'] != null ? (map['addressType'] as int).parseAddressType : null,
      isActive: map['isActive'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory AddressModel.fromJson(String source) => AddressModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'AddressModel(id: $id, userId: $userId, title: $title, fullName: $fullName, phoneNumber: $phoneNumber, taxNumber: $taxNumber, country: $country, level1: $level1, level2: $level2, level3: $level3, level4: $level4, zipPostalCode: $zipPostalCode, fullAddress: $fullAddress, apartment: $apartment, lng: $lng, lat: $lat, isCompany: $isCompany, addressType: $addressType, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AddressModel &&
        other.id == id &&
        other.userId == userId &&
        other.title == title &&
        other.fullName == fullName &&
        other.phoneNumber == phoneNumber &&
        other.taxNumber == taxNumber &&
        other.country == country &&
        other.level1 == level1 &&
        other.level2 == level2 &&
        other.level3 == level3 &&
        other.level4 == level4 &&
        other.zipPostalCode == zipPostalCode &&
        other.fullAddress == fullAddress &&
        other.apartment == apartment &&
        other.lng == lng &&
        other.lat == lat &&
        other.isCompany == isCompany &&
        other.addressType == addressType &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        title.hashCode ^
        fullName.hashCode ^
        phoneNumber.hashCode ^
        taxNumber.hashCode ^
        country.hashCode ^
        level1.hashCode ^
        level2.hashCode ^
        level3.hashCode ^
        level4.hashCode ^
        zipPostalCode.hashCode ^
        fullAddress.hashCode ^
        apartment.hashCode ^
        lng.hashCode ^
        lat.hashCode ^
        isCompany.hashCode ^
        addressType.hashCode ^
        isActive.hashCode;
  }
}
