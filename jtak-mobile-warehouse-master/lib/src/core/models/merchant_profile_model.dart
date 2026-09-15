/// ---------------------------------------------------------------------------
/// Merchant Profile Model (Full Store Identity & Operations Config)
/// ---------------------------------------------------------------------------

class MerchantProfileModel {
  final int id;
  final String title;
  final String shortDescription;
  final String description;
  final String logo;
  final String coverBanner;
  final String phone1;
  final String phone2;
  final String address;
  final int shippingCoverageInMeters;
  final double lat;
  final double lng;
  final bool active;
  final int merchantKind;

  MerchantProfileModel({
    this.id = 0,
    this.title = '',
    this.shortDescription = '',
    this.description = '',
    this.logo = '',
    this.coverBanner = '',
    this.phone1 = '',
    this.phone2 = '',
    this.address = '',
    this.shippingCoverageInMeters = 5000,
    this.lat = 0.0,
    this.lng = 0.0,
    this.active = true,
    this.merchantKind = 0,
  });

  factory MerchantProfileModel.fromJson(Map<String, dynamic> json) {
    return MerchantProfileModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? '',
      shortDescription: json['shortDescription']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      logo: json['logo']?.toString() ?? '',
      coverBanner: json['coverBanner']?.toString() ?? '',
      phone1: json['phone1']?.toString() ?? '',
      phone2: json['phone2']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      shippingCoverageInMeters: json['shippingCoverageInMeters'] is int
          ? json['shippingCoverageInMeters']
          : int.tryParse(json['shippingCoverageInMeters']?.toString() ?? '5000') ?? 5000,
      lat: (json['lat'] is num) ? (json['lat'] as num).toDouble() : double.tryParse(json['lat']?.toString() ?? '0.0') ?? 0.0,
      lng: (json['lng'] is num) ? (json['lng'] as num).toDouble() : double.tryParse(json['lng']?.toString() ?? '0.0') ?? 0.0,
      active: json['active'] is bool ? json['active'] : true,
      merchantKind: json['merchantKind'] is int
          ? json['merchantKind']
          : int.tryParse(json['merchantKind']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'shortDescription': shortDescription,
      'description': description,
      'logo': logo,
      'coverBanner': coverBanner,
      'phone1': phone1,
      'phone2': phone2,
      'address': address,
      'shippingCoverageInMeters': shippingCoverageInMeters,
      'lat': lat,
      'lng': lng,
      'active': active,
      'merchantKind': merchantKind,
    };
  }

  MerchantProfileModel copyWith({
    int? id,
    String? title,
    String? shortDescription,
    String? description,
    String? logo,
    String? coverBanner,
    String? phone1,
    String? phone2,
    String? address,
    int? shippingCoverageInMeters,
    double? lat,
    double? lng,
    bool? active,
    int? merchantKind,
  }) {
    return MerchantProfileModel(
      id: id ?? this.id,
      title: title ?? this.title,
      shortDescription: shortDescription ?? this.shortDescription,
      description: description ?? this.description,
      logo: logo ?? this.logo,
      coverBanner: coverBanner ?? this.coverBanner,
      phone1: phone1 ?? this.phone1,
      phone2: phone2 ?? this.phone2,
      address: address ?? this.address,
      shippingCoverageInMeters: shippingCoverageInMeters ?? this.shippingCoverageInMeters,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      active: active ?? this.active,
      merchantKind: merchantKind ?? this.merchantKind,
    );
  }
}
