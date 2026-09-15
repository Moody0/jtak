import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:jtek_app/src/config/constants/app_constant.dart';
import 'package:jtek_app/src/core/controllers/app_notification_provider.dart';
import 'package:jtek_app/src/core/controllers/app_parameters_provider.dart';
import 'package:jtek_app/src/core/controllers/catalog/favorite_product_provider.dart';
import 'package:jtek_app/src/core/controllers/order/cart_provider.dart';
import 'package:jtek_app/src/core/controllers/order/order_provider.dart';
import 'package:jtek_app/src/core/controllers/user/address_provider.dart';
import 'package:jtek_app/src/core/models/phone_number_model.dart';
import 'package:jtek_app/src/core/models/user/user_model.dart';
import 'package:provider/provider.dart';

import '../../../utils/providers/sol_api.dart';

import '../../services/locator.dart';
import '../app/base_provider.dart';
import '../../services/authentication_service.dart';

class UserProvider extends BaseProvider {
  final SolApi _api = locator<SolApi>();
  String apiPrefex = '${SolApi.apiVersionPrefex}/Authorization';

  AuthenticationService authService = locator<AuthenticationService>();
  String? fullName, email, oldPassword, newPassword;
  PhoneNumberModel? phoneNumber;
  String? lastVerificationCode;

  void loadUserDataProfile() {
    fullName = authService.user?.fullName;
    email = authService.user?.email;
    phoneNumber = PhoneNumberModel(
      isoCode: authService.user?.countryPhoneCode ?? kCountriesCode[kCountryPhoneCodeDefualt],
      dialCode: authService.user?.countryPhoneCode ?? kCountryPhoneCodeDefualt,
      phoneNumber: authService.user?.phoneNumber,
    );
  }

  Future<void> login(String email, String password) async {
    await loadBaseData(
      loadBody: () async {
        await authService.login(email, password);
      },
    );
  }

  Future<void> loginByPhone(String phoneNumber, String code) async {
    await loadBaseData(
      loadBody: () async {
        await authService.loginByPhone(phoneNumber, code);
        try {
          // Refresh user's saved addresses without creating any new or duplicate entries
          await locator<AddressProvider>().loadData();
        } catch (e) {
          debugPrint('Address load after login: $e');
        }
      },
    );
  }

  Future<void> registerOrSignInByPhoneNumber(String phoneNumber) async {
    await loadBaseData(
      loadBody: () async {
        Map<String, String> body = {"phoneNumber": phoneNumber};
        var res = await _api.postRequest('/Account/RegisterOrSignInByPhoneNumber', body, apiPrefex: apiPrefex);
        log('registerOrSignInByPhoneNumber : $res');
        if (res != null) {
          lastVerificationCode = res.toString().replaceAll('"', '').trim();
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

  Future<void> update() async {
    await loadBaseData(
      loadBody: () async {
        final phone = (phoneNumber?.phoneNumber != null && phoneNumber!.phoneNumber!.isNotEmpty)
            ? phoneNumber!.phoneNumber!
            : (authService.user?.phoneNumber ?? '');
        final dial = (phoneNumber?.dialCode != null && phoneNumber!.dialCode!.isNotEmpty)
            ? phoneNumber!.dialCode!
            : (authService.user?.countryPhoneCode ?? '+963');
        final cleanEmail = (email != null && email!.isNotEmpty)
            ? email!
            : (authService.user?.email ?? 'user@jtak.app');

        try {
          Map body = {
            "fullName": fullName ?? '',
            "email": cleanEmail,
            "phoneNumber": phone,
            "countryPhoneCode": dial,
          };
          await _api.postRequest('/Account/UpdateUser', body, apiPrefex: apiPrefex);
        } catch (e) {
          debugPrint('UpdateUser error: $e');
        }

        if (authService.user != null) {
          UserModel user = authService.user!;
          user.fullName = fullName;
          user.email = cleanEmail;
          if (phone.isNotEmpty) user.phoneNumber = phone;
          authService.user = user;
        } else {
          authService.user = UserModel(
            fullName: fullName,
            email: cleanEmail,
            phoneNumber: phone,
            countryPhoneCode: dial,
          );
        }
        await authService.saveUserData(authService.user);
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

  Future logOut(BuildContext context) async {
    locator<AuthenticationService>().logOut();
    locator<AppParametersProvider>().resetData();
    locator<AppNotificationProvider>().resetData();
    locator<CartProvider>().resetData();
    Provider.of<FavoriteProductProvider>(context, listen: false).resetData();
    Provider.of<OrderProvider>(context, listen: false).resetData();
  }
}
