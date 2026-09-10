/// [PhoneNumberModel] contains detailed information about a phone number
class PhoneNumberModel {
  /// Either formatted or unformatted String of the phone number
  final String? phoneNumber;

  /// The Country [dialCode] of the phone number
  final String? dialCode;

  /// Country [isoCode] of the phone number
  final String? isoCode;

  /// [_hash] is used to compare instances of [PhoneNumberModel] object.
  final int _hash;

  /// Returns an integer generated after the object was initialised.
  /// Used to compare different instances of [PhoneNumberModel]
  int get hash => _hash;

  PhoneNumberModel({
    this.phoneNumber,
    this.dialCode,
    this.isoCode,
  }) : _hash = phoneNumber.hashCode ^ dialCode.hashCode ^ isoCode.hashCode;

  @override
  String toString() {
    return phoneNumber!;
  }

  /// Returns a String of [phoneNumber] without [dialCode]
  String parseNumber() {
    return phoneNumber!.replaceAll("$dialCode", '');
  }

  Map<String, dynamic> toMap() {
    return {
      'phoneNumber': phoneNumber,
      'dialCode': dialCode,
      'isoCode': isoCode,
    };
  }

  factory PhoneNumberModel.fromMap(Map<String, dynamic> map) {
    return PhoneNumberModel(
      phoneNumber: map['phoneNumber'],
      dialCode: map['dialCode'],
      isoCode: map['isoCode'],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PhoneNumberModel && other.phoneNumber == phoneNumber && other.dialCode == dialCode && other.isoCode == isoCode;
  }

  @override
  int get hashCode {
    return _hash;
  }
}
