import 'dart:convert';

class UserModel {
  String? id;
  String? email;
  bool? emailConfirmed;
  String? phoneNumber;
  String? firstName;
  String? lastName;
  String? fullName;
  int? gender;
  bool? isActive;
  bool? hasPassword;
  String? profilePhoto;
  String? topics;
  int? role;
  String? createdDate;
  String? birthday;
  String? lang;
  String? countryPhoneCode;
  String? userTopicId;

  UserModel({
    this.id,
    this.email,
    this.emailConfirmed,
    this.phoneNumber,
    this.firstName,
    this.lastName,
    this.fullName,
    this.gender,
    this.isActive,
    this.hasPassword,
    this.profilePhoto,
    this.topics,
    this.role,
    this.createdDate,
    this.birthday,
    this.lang,
    this.countryPhoneCode,
    this.userTopicId,
  });

  UserModel copyWith({
    String? id,
    String? email,
    bool? emailConfirmed,
    String? phoneNumber,
    String? firstName,
    String? lastName,
    String? fullName,
    int? gender,
    bool? isActive,
    bool? hasPassword,
    String? profilePhoto,
    String? topics,
    int? role,
    String? createdDate,
    String? birthday,
    String? lang,
    String? countryPhoneCode,
    String? userTopicId,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      emailConfirmed: emailConfirmed ?? this.emailConfirmed,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      fullName: fullName ?? this.fullName,
      gender: gender ?? this.gender,
      isActive: isActive ?? this.isActive,
      hasPassword: hasPassword ?? this.hasPassword,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      topics: topics ?? this.topics,
      role: role ?? this.role,
      createdDate: createdDate ?? this.createdDate,
      birthday: birthday ?? this.birthday,
      lang: lang ?? this.lang,
      countryPhoneCode: countryPhoneCode ?? this.countryPhoneCode,
      userTopicId: userTopicId ?? this.userTopicId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'emailConfirmed': emailConfirmed,
      'phoneNumber': phoneNumber,
      'firstName': firstName,
      'lastName': lastName,
      'fullName': fullName,
      'gender': gender,
      'isActive': isActive,
      'hasPassword': hasPassword,
      'profilePhoto': profilePhoto,
      'topics': topics,
      'role': role,
      'createdDate': createdDate,
      'birthday': birthday,
      'lang': lang,
      'countryPhoneCode': countryPhoneCode,
      'userTopicId': userTopicId,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      email: map['email'],
      emailConfirmed: map['emailConfirmed'],
      phoneNumber: map['phoneNumber'],
      firstName: map['firstName'],
      lastName: map['lastName'],
      fullName: map['fullName'],
      gender: map['gender']?.toInt(),
      isActive: map['isActive'],
      hasPassword: map['hasPassword'],
      profilePhoto: map['profilePhoto'],
      topics: map['topics'],
      // role: map['role']?.toInt(),
      createdDate: map['createdDate'],
      birthday: map['birthday'],
      lang: map['lang'],
      countryPhoneCode: map['countryPhoneCode'],
      userTopicId: map['userTopicId'],
    );
  }

  String toJson() => json.encode(toMap());

  factory UserModel.fromJson(String source) => UserModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, emailConfirmed: $emailConfirmed, phoneNumber: $phoneNumber, firstName: $firstName, lastName: $lastName, fullName: $fullName, gender: $gender, isActive: $isActive, hasPassword: $hasPassword, profilePhoto: $profilePhoto, topics: $topics, role: $role, createdDate: $createdDate, birthday: $birthday, lang: $lang, countryPhoneCode: $countryPhoneCode, userTopicId: $userTopicId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserModel &&
        other.id == id &&
        other.email == email &&
        other.emailConfirmed == emailConfirmed &&
        other.phoneNumber == phoneNumber &&
        other.firstName == firstName &&
        other.lastName == lastName &&
        other.fullName == fullName &&
        other.gender == gender &&
        other.isActive == isActive &&
        other.hasPassword == hasPassword &&
        other.profilePhoto == profilePhoto &&
        other.topics == topics &&
        other.role == role &&
        other.createdDate == createdDate &&
        other.birthday == birthday &&
        other.lang == lang &&
        other.countryPhoneCode == countryPhoneCode &&
        other.userTopicId == userTopicId;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        email.hashCode ^
        emailConfirmed.hashCode ^
        phoneNumber.hashCode ^
        firstName.hashCode ^
        lastName.hashCode ^
        fullName.hashCode ^
        gender.hashCode ^
        isActive.hashCode ^
        hasPassword.hashCode ^
        profilePhoto.hashCode ^
        topics.hashCode ^
        role.hashCode ^
        createdDate.hashCode ^
        birthday.hashCode ^
        lang.hashCode ^
        countryPhoneCode.hashCode ^
        userTopicId.hashCode;
  }
}
