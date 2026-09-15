import 'package:jtek_app/src/config/constants/app_constant.dart';
import 'package:jtek_app/src/core/controllers/app_parameters_provider.dart';
import 'package:jtek_app/src/core/models/phone_number_model.dart';
import 'package:jtek_app/src/core/models/user/address_model.dart';

import '../../services/locator.dart';
import '../../services/authentication_service.dart';

class CartInfo {
  String? name, address;
  PhoneNumberModel? phoneNumber;
  double? lat, lng;

  Future initData() async {
    AuthenticationService authService = locator<AuthenticationService>();
    if (authService.user == null) {
      await authService.getAuthorizationData();
    }
    AddressModel mainAddress =
        locator<AppParametersProvider>().mainAddressService.mainAddress;

    address =
        (mainAddress.fullAddress != null && mainAddress.fullAddress!.isNotEmpty)
            ? mainAddress.fullAddress
            : mainAddress.title;
    lat = mainAddress.lat;
    lng = mainAddress.lng;

    final userPhone = authService.user?.phoneNumber ?? '';
    final userDialCode =
        authService.user?.countryPhoneCode ?? kCountryPhoneCodeDefualt;

    name = authService.user?.fullName ?? 'عميل جيتك';
    if (userPhone.isNotEmpty) {
      phoneNumber = PhoneNumberModel(
        isoCode: kCountriesCode[userDialCode] ?? 'SY',
        dialCode: userDialCode,
        phoneNumber: userPhone,
      );
    } else {
      phoneNumber = null;
    }
  }
}
