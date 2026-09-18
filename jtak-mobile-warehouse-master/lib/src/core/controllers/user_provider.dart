import 'package:flutter/foundation.dart' show debugPrint;
import 'package:app_jtak_warehouse/src/config/constants/app_constant.dart';
import 'package:app_jtak_warehouse/src/core/controllers/app/base_provider.dart';
import 'package:app_jtak_warehouse/src/core/models/phone_number_model.dart';
import 'package:app_jtak_warehouse/src/utils/providers/custom_exception.dart';
import 'package:app_jtak_warehouse/src/utils/providers/sol_api.dart';

import '../services/locator.dart';
import '../services/authentication_service.dart';

class UserProvider extends BaseProvider {
  final SolApi _api = locator<SolApi>();
  AuthenticationService authService = locator<AuthenticationService>();
  String apiPrefex = SolApi.apiVersionPrefex + '/Authorization';
  String? fullName, email, oldPassword, newPassword;
  PhoneNumberModel? phoneNumber;
  String? lastVerificationCode;

  /// Clear all cached profile form state on account switch or logout
  void reset() {
    fullName = null;
    email = null;
    oldPassword = null;
    newPassword = null;
    phoneNumber = null;
    lastVerificationCode = null;
    notifyListeners();
  }

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
        try {
          // Attempt gated merchant login first
          var res = await _api.postRequest('/Account/MerchantSignInByPhoneNumber', body, apiPrefex: apiPrefex);
          debugPrint('merchantSignInByPhoneNumber : $res');
          if (res != null) {
            lastVerificationCode = res.toString().replaceAll('"', '').trim();
          }
        } on NotFoundException {
          // Fallback if backend does not have the new MerchantSignInByPhoneNumber deployed yet
          var res = await _api.postRequest('/Account/RegisterOrSignInByPhoneNumber', body, apiPrefex: apiPrefex);
          debugPrint('registerOrSignInByPhoneNumber (legacy fallback) : $res');
          if (res != null) {
            lastVerificationCode = res.toString().replaceAll('"', '').trim();
          }
        }
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
