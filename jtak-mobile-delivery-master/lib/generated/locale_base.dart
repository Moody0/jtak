import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class LocaleBase {
  late Map<String, dynamic> _data;
  late String _path;
  Future<void> load(String path) async {
    _path = path;
    final strJson = await rootBundle.loadString(path);
    _data = jsonDecode(strJson);
    initAll();
  }
  
  Map<String, String> getData(String group) {
    return Map<String, String>.from(_data[group]);
  }

  String getPath() => _path;

  late Localeapp _app;
  Localeapp get app => _app;
  late LocaleformAndAction _formAndAction;
  LocaleformAndAction get formAndAction => _formAndAction;
  late Localemain _main;
  Localemain get main => _main;
  late Localemsg _msg;
  Localemsg get msg => _msg;

  void initAll() {
    _app = Localeapp(Map<String, String>.from(_data['app']));
    _formAndAction = LocaleformAndAction(Map<String, String>.from(_data['formAndAction']));
    _main = Localemain(Map<String, String>.from(_data['main']));
    _msg = Localemsg(Map<String, String>.from(_data['msg']));
  }
}

class Localeapp {
  late final Map<String, String> _data;
  Localeapp(this._data);

  String getByKey(String key) {
    return _data[key]!;
  }

  String get previousOrders => _data["previousOrders"]!;
  String get productDetails => _data["productDetails"]!;
  String get similarProduct => _data["similarProduct"]!;
  String get addToCart => _data["addToCart"]!;
  String get shoppingCart => _data["shoppingCart"]!;
  String get checkOut => _data["checkOut"]!;
  String get total => _data["total"]!;
  String get orders => _data["orders"]!;
  String get myOrders => _data["myOrders"]!;
  String get myPreviousOrders => _data["myPreviousOrders"]!;
  String get orderNumber => _data["orderNumber"]!;
  String get orderDate => _data["orderDate"]!;
  String get orderStatus => _data["orderStatus"]!;
  String get productNotAvailable => _data["productNotAvailable"]!;
  String get itemCount => _data["itemCount"]!;
  String get cartSendSuccessfully => _data["cartSendSuccessfully"]!;
  String get paymentPolicy => _data["paymentPolicy"]!;
  String get orderDetails => _data["orderDetails"]!;
  String get address => _data["address"]!;
  String get addAddress => _data["addAddress"]!;
  String get taxNumber => _data["taxNumber"]!;
  String get zipPostalCode => _data["zipPostalCode"]!;
  String get fullAddress => _data["fullAddress"]!;
  String get addressTitle => _data["addressTitle"]!;
  String get apartment => _data["apartment"]!;
  String get addressType => _data["addressType"]!;
  String get company => _data["company"]!;
  String get addressTypeHome => _data["addressTypeHome"]!;
  String get addressTypeWork => _data["addressTypeWork"]!;
  String get shippingAddress => _data["shippingAddress"]!;
  String get billingAddress => _data["billingAddress"]!;
  String get favoriteProducts => _data["favoriteProducts"]!;
  String get productReviews => _data["productReviews"]!;
  String get productReview => _data["productReview"]!;
  String get addReviewTextMsg => _data["addReviewTextMsg"]!;
  String get payOnDelivery => _data["payOnDelivery"]!;
  String get creditCardPayment => _data["creditCardPayment"]!;
  String get paymentMethod => _data["paymentMethod"]!;
  String get orderStatusPending => _data["orderStatusPending"]!;
  String get orderStatusSuccess => _data["orderStatusSuccess"]!;
  String get orderDetailsStatusPending => _data["orderDetailsStatusPending"]!;
  String get orderDetailsStatusMerchantAccepted => _data["orderDetailsStatusMerchantAccepted"]!;
  String get orderDetailsStatusShipping => _data["orderDetailsStatusShipping"]!;
  String get orderDetailsStatusDelivered => _data["orderDetailsStatusDelivered"]!;
  String get orderDetailsStatusMerchantRejected => _data["orderDetailsStatusMerchantRejected"]!;
  String get orderDetailsStatusCustomerPending => _data["orderDetailsStatusCustomerPending"]!;
  String get orderDetailsStatusCustomerCanceled => _data["orderDetailsStatusCustomerCanceled"]!;
  String get accept => _data["accept"]!;
  String get privecyAndUsage => _data["privecyAndUsage"]!;
}

class LocaleformAndAction {
  late final Map<String, String> _data;
  LocaleformAndAction(this._data);

  String getByKey(String key) {
    return _data[key]!;
  }

  String get logIn => _data["logIn"]!;
  String get signup => _data["signup"]!;
  String get username => _data["username"]!;
  String get email => _data["email"]!;
  String get password => _data["password"]!;
  String get phone => _data["phone"]!;
  String get logout => _data["logout"]!;
  String get changePassword => _data["changePassword"]!;
  String get save => _data["save"]!;
  String get oldPassword => _data["oldPassword"]!;
  String get newPassword => _data["newPassword"]!;
  String get update => _data["update"]!;
  String get title => _data["title"]!;
  String get theMessage => _data["theMessage"]!;
  String get send => _data["send"]!;
  String get name => _data["name"]!;
  String get skip => _data["skip"]!;
  String get registerMsg => _data["registerMsg"]!;
  String get orLoginBy => _data["orLoginBy"]!;
  String get googleLogin => _data["googleLogin"]!;
  String get facebookLogin => _data["facebookLogin"]!;
  String get alreadyHaveAnAccount => _data["alreadyHaveAnAccount"]!;
  String get fullName => _data["fullName"]!;
  String get confirmPassword => _data["confirmPassword"]!;
  String get forgetPassword => _data["forgetPassword"]!;
  String get resetPassword => _data["resetPassword"]!;
  String get emailOrPhone => _data["emailOrPhone"]!;
  String get code => _data["code"]!;
  String get confirmEmail => _data["confirmEmail"]!;
  String get confirmEmailSuccessMsg => _data["confirmEmailSuccessMsg"]!;
  String get resendCode => _data["resendCode"]!;
  String get appleLogin => _data["appleLogin"]!;
  String get loginUsing => _data["loginUsing"]!;
  String get address => _data["address"]!;
  String get activationCode => _data["activationCode"]!;
  String get enterCodeSended => _data["enterCodeSended"]!;
}

class Localemain {
  late final Map<String, String> _data;
  Localemain(this._data);

  String getByKey(String key) {
    return _data[key]!;
  }

  String get lang => _data["lang"]!;
  String get setting => _data["setting"]!;
  String get changeLanguage => _data["changeLanguage"]!;
  String get faqs => _data["faqs"]!;
  String get howToUse => _data["howToUse"]!;
  String get english => _data["english"]!;
  String get arabic => _data["arabic"]!;
  String get home => _data["home"]!;
  String get privacyPolicy => _data["privacyPolicy"]!;
  String get termOfUse => _data["termOfUse"]!;
  String get search => _data["search"]!;
  String get more => _data["more"]!;
  String get less => _data["less"]!;
  String get contactUs => _data["contactUs"]!;
  String get image => _data["image"]!;
  String get report => _data["report"]!;
  String get block => _data["block"]!;
  String get clear => _data["clear"]!;
  String get delete => _data["delete"]!;
  String get clearChat => _data["clearChat"]!;
  String get enterMsg => _data["enterMsg"]!;
  String get chats => _data["chats"]!;
  String get cancel => _data["cancel"]!;
  String get retry => _data["retry"]!;
  String get appName => _data["appName"]!;
  String get camera => _data["camera"]!;
  String get gallery => _data["gallery"]!;
  String get addCaption => _data["addCaption"]!;
  String get welcom => _data["welcom"]!;
  String get active => _data["active"]!;
  String get myAccount => _data["myAccount"]!;
  String get all => _data["all"]!;
  String get images => _data["images"]!;
  String get next => _data["next"]!;
  String get ok => _data["ok"]!;
  String get seeAll => _data["seeAll"]!;
  String get map => _data["map"]!;
  String get edit => _data["edit"]!;
  String get yes => _data["yes"]!;
  String get no => _data["no"]!;
  String get later => _data["later"]!;
  String get unBLock => _data["unBLock"]!;
  String get add => _data["add"]!;
  String get category => _data["category"]!;
  String get about => _data["about"]!;
  String get termsAndConditions => _data["termsAndConditions"]!;
  String get showMore => _data["showMore"]!;
  String get showLess => _data["showLess"]!;
  String get chooseLocation => _data["chooseLocation"]!;
  String get close => _data["close"]!;
  String get countries => _data["countries"]!;
  String get cities => _data["cities"]!;
  String get users => _data["users"]!;
  String get categories => _data["categories"]!;
  String get follow => _data["follow"]!;
  String get favorite => _data["favorite"]!;
  String get myFriends => _data["myFriends"]!;
  String get unFollow => _data["unFollow"]!;
  String get followers => _data["followers"]!;
  String get following => _data["following"]!;
  String get notification => _data["notification"]!;
  String get profile => _data["profile"]!;
  String get account => _data["account"]!;
  String get personalAccount => _data["personalAccount"]!;
  String get thePersonalAccount => _data["thePersonalAccount"]!;
  String get address => _data["address"]!;
  String get personalInfo => _data["personalInfo"]!;
  String get description => _data["description"]!;
}

class Localemsg {
  late final Map<String, String> _data;
  Localemsg(this._data);

  String getByKey(String key) {
    return _data[key]!;
  }

  String get errorOccurred => _data["errorOccurred"]!;
  String get shareMsg => _data["shareMsg"]!;
  String get noInternet => _data["noInternet"]!;
  String get updateSucceeded => _data["updateSucceeded"]!;
  String get sendingFailed => _data["sendingFailed"]!;
  String get sendingDone => _data["sendingDone"]!;
  String get sentSuccesfully => _data["sentSuccesfully"]!;
  String get wrongUsernameOrPassword => _data["wrongUsernameOrPassword"]!;
  String get errConnectionServer => _data["errConnectionServer"]!;
  String get errorPageRouting => _data["errorPageRouting"]!;
  String get loginError => _data["loginError"]!;
  String get invalidUsername => _data["invalidUsername"]!;
  String get loginFaild => _data["loginFaild"]!;
  String get loginLater => _data["loginLater"]!;
  String get invalidEmail => _data["invalidEmail"]!;
  String get passwordShort => _data["passwordShort"]!;
  String get invalidPhone => _data["invalidPhone"]!;
  String get invalidTitle => _data["invalidTitle"]!;
  String get invalidName => _data["invalidName"]!;
  String get loginFirst => _data["loginFirst"]!;
  String get confirmPasswordIncorrect => _data["confirmPasswordIncorrect"]!;
  String get logininToContinue => _data["logininToContinue"]!;
  String get createAccuont => _data["createAccuont"]!;
  String get fillField => _data["fillField"]!;
  String get pleaseAddImage => _data["pleaseAddImage"]!;
  String get fillFieldNumber => _data["fillFieldNumber"]!;
  String get fillFieldInt => _data["fillFieldInt"]!;
  String get logoutConfirm => _data["logoutConfirm"]!;
  String get exitConfirmation => _data["exitConfirmation"]!;
  String get imageNotSaved => _data["imageNotSaved"]!;
  String get noMessagesAvailable => _data["noMessagesAvailable"]!;
  String get deleteConfermation => _data["deleteConfermation"]!;
  String get noDataAvailable => _data["noDataAvailable"]!;
  String get saveSucceeded => _data["saveSucceeded"]!;
  String get errorDateFormat => _data["errorDateFormat"]!;
  String get noNotificationsAvailable => _data["noNotificationsAvailable"]!;
  String get enterEmail => _data["enterEmail"]!;
  String get enterPhone => _data["enterPhone"]!;
  String get activationCodeSendToEmail => _data["activationCodeSendToEmail"]!;
  String get resetPasswordSucess => _data["resetPasswordSucess"]!;
  String get activationCodeSendTophone => _data["activationCodeSendTophone"]!;
  String get resendSmsCodeSucceeded => _data["resendSmsCodeSucceeded"]!;
  String get confirmPhoneMsg => _data["confirmPhoneMsg"]!;
  String get confirmationSucceeded => _data["confirmationSucceeded"]!;
  String get smsSendTo => _data["smsSendTo"]!;
  String get emailNotConfirmedMsg => _data["emailNotConfirmedMsg"]!;
  String get activationLinkSendToEmail => _data["activationLinkSendToEmail"]!;
  String get searchFaild => _data["searchFaild"]!;
  String get pleaseAddFullName => _data["pleaseAddFullName"]!;
  String get pleaseChooseCategory => _data["pleaseChooseCategory"]!;
  String get loading => _data["loading"]!;
  String get deleteSuccessfully => _data["deleteSuccessfully"]!;
  String get invalidPhoneNumber => _data["invalidPhoneNumber"]!;
  String get smsCodeSend => _data["smsCodeSend"]!;
  String get locationServiceDisabled => _data["locationServiceDisabled"]!;
  String get locationPermissionsDenied => _data["locationPermissionsDenied"]!;
  String get pleaseEnableLocationService => _data["pleaseEnableLocationService"]!;
}

