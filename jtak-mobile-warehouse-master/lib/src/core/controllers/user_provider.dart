import 'package:flutter/foundation.dart' show debugPrint;
import 'package:app_jtak_warehouse/src/config/constants/app_constant.dart';
import 'package:app_jtak_warehouse/src/core/controllers/app/base_provider.dart';
import 'package:app_jtak_warehouse/src/core/models/phone_number_model.dart';
import 'package:app_jtak_warehouse/src/utils/providers/sol_api.dart';

import '../services/locator.dart';
import '../services/authentication_service.dart';

class UserProvider extends BaseProvider {
  final SolApi _api = locator<SolApi>();
  AuthenticationService authService = locator<AuthenticationService>();
  String apiPrefex = SolApi.apiVersionPrefex + '/Authorization';
  String? fullName, email, oldPassword, newPassword;
  PhoneNumberModel? phoneNumber;

  void loadUserDataProfile() async {
    if (authService.user == null) {
      await loadUserData();
    }
    fullName = authService.user?.fullName;
    email = authService.user?.email;
    phoneNumber = PhoneNumberModel(
      isoCode: authService.user?.countryPhoneCode ?? kCountriesCode[kCountryPhoneCodeDefualt],
      dialCode: authService.user?.countryPhoneCode ?? kCountryPhoneCodeDefualt,
      phoneNumber: authService.user?.phoneNumber,
    );
  }

  Future<void> loadUserData() async {
    await loadBaseData(
      loadBody: () async {
        await authService.loadUserData();
      },
    );
  }

  Future<void> loginByPhone(String phoneNumber, String code) async {
    await loadBaseData(
      loadBody: () async {
        await authService.loginByPhone(phoneNumber, code);
      },
    );
  }

  Future<void> registerOrSignInByPhoneNumber(String phoneNumber) async {
    await loadBaseData(
      loadBody: () async {
        Map<String, String> body = {"phoneNumber": phoneNumber};
        var res = await _api.postRequest('/Account/RegisterOrSignInByPhoneNumber', body, apiPrefex: apiPrefex);
        debugPrint('registerOrSignInByPhoneNumber : $res');
      },
    );
  }

  Future resendSmsCode(String phoneNumber) async {
    await loadBaseData(
      loadBody: () async {
        Map<String, String> body = {"phoneNumber": phoneNumber};
        await _api.postRequest('/Account/ResendSmsCode', body, apiPrefex: apiPrefex);
      },
    );
  }

  Future<void> login(String email, String password) async {
    await loadBaseData(
      loadBody: () async {
        await authService.login(email, password);
      },
    );
  }

  Future<void> update() async {
    await loadBaseData(
      loadBody: () async {
        Map body = {
          "fullName": fullName,
          "email": email,
        };
        await _api.postRequest('/Account/UpdateUser', body, apiPrefex: apiPrefex);
        authService.user?.fullName = fullName;
        authService.user?.email = email;
        authService.user?.phoneNumber = phoneNumber!.phoneNumber!;
        authService.user?.countryPhoneCode = phoneNumber!.dialCode;
      },
    );
  }

  Future<void> changePassword() async {
    await loadBaseData(
      loadBody: () async {
        Map body = {
          "oldPassword": oldPassword,
          "newPassword": newPassword,
          "confirmPassword": newPassword,
        };
        await _api.postRequest('/Account/ChangePassword', body, apiPrefex: apiPrefex);
      },
    );
  }

  Future setLang(String lang) async {
    await loadBaseData(
      loadBody: () async {
        Map body = {"lang": lang};
        await _api.postRequest('/Account/SetLang', body, apiPrefex: apiPrefex);
      },
    );
  }
}
