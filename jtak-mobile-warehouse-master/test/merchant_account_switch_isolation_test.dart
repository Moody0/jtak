import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_jtak_warehouse/src/core/controllers/merchant_profile_provider.dart';
import 'package:app_jtak_warehouse/src/core/controllers/app/merchant_state_provider.dart';
import 'package:app_jtak_warehouse/src/core/controllers/order_provider.dart';
import 'package:app_jtak_warehouse/src/core/controllers/payment_provider.dart';
import 'package:app_jtak_warehouse/src/core/controllers/products_provider.dart';
import 'package:app_jtak_warehouse/src/core/controllers/user_provider.dart';
import 'package:app_jtak_warehouse/src/core/controllers/app_parameters_provider.dart';
import 'package:app_jtak_warehouse/src/core/controllers/app/app_state_manager.dart';
import 'package:app_jtak_warehouse/src/core/models/order_model.dart';
import 'package:app_jtak_warehouse/src/core/services/authentication_service.dart';
import 'package:app_jtak_warehouse/src/core/services/locator.dart';
import 'package:app_jtak_warehouse/src/utils/providers/sol_api.dart';

class FakeMerchantSolApi extends SolApi {
  String currentUser = 'AccountA';

  @override
  Future<dynamic> postRequest(String subUrl, dynamic body,
      {Map<String, String>? headers, String? apiPrefex}) async {
    if (subUrl == '/connect/token') {
      return {
        'access_token': 'jwt_token_for_$currentUser',
        'token_type': 'Bearer',
        'expires_in': '2030-01-01T00:00:00Z',
        'refresh_token': 'refresh_$currentUser',
      };
    }
    return null;
  }

  @override
  Future<dynamic> getRequest(String subUrl,
      {Map<String, String>? headers, String? apiPrefex}) async {
    if (subUrl == '/connect/userinfo') {
      if (currentUser == 'AccountA') {
        return {
          'id': 101,
          'fullName': 'Owner Account A',
          'phoneNumber': '+963911111111',
          'email': 'a@merchant.com',
          'role': 2,
        };
      } else {
        return {
          'id': 202,
          'fullName': 'Owner Account B',
          'phoneNumber': '+963922222222',
          'email': 'b@merchant.com',
          'role': 2,
        };
      }
    }
    if (subUrl == '/Merchant/Profile') {
      if (currentUser == 'AccountA') {
        return {
          'id': 10,
          'title': 'Store Account A',
          'shortDescription': 'Best Store A',
          'description': 'Full Desc A',
          'phone1': '+963911111111',
          'phone2': '',
          'address': 'Damascus Street A',
          'shippingCoverageInMeters': 5000,
          'active': true,
        };
      } else {
        return {
          'id': 20,
          'title': 'Store Account B',
          'shortDescription': 'Best Store B',
          'description': 'Full Desc B',
          'phone1': '+963922222222',
          'phone2': '',
          'address': 'Damascus Street B',
          'shippingCoverageInMeters': 8000,
          'active': false,
        };
      }
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeMerchantSolApi fakeApi;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'merchant_prep_deadline_1': '2026-09-18T12:00:00Z',
      'merchant_picked_items_1': ['101', '102'],
    });

    if (!locator.isRegistered<AppStateManager>()) {
      locator.registerSingleton<AppStateManager>(AppStateManager());
    }

    fakeApi = FakeMerchantSolApi();

    if (locator.isRegistered<SolApi>()) {
      locator.unregister<SolApi>();
    }
    locator.registerSingleton<SolApi>(fakeApi);

    if (!locator.isRegistered<MerchantProfileProvider>()) {
      locator.registerLazySingleton(() => MerchantProfileProvider());
    }
    if (!locator.isRegistered<MerchantStateProvider>()) {
      locator.registerLazySingleton(() => MerchantStateProvider());
    }
    if (!locator.isRegistered<OrderProvider>()) {
      locator.registerLazySingleton(() => OrderProvider());
    }
    if (!locator.isRegistered<PaymentProvider>()) {
      locator.registerLazySingleton(() => PaymentProvider());
    }
    if (!locator.isRegistered<ProductsProvider>()) {
      locator.registerLazySingleton(() => ProductsProvider());
    }
    if (!locator.isRegistered<UserProvider>()) {
      locator.registerLazySingleton(() => UserProvider());
    }
    if (!locator.isRegistered<AppParametersProvider>()) {
      locator.registerLazySingleton(() => AppParametersProvider());
    }
    if (!locator.isRegistered<AuthenticationService>()) {
      locator.registerLazySingleton(() => AuthenticationService());
    }
  });

  group('Merchant Account Switch & Complete Isolation Suite (A -> B -> A)', () {
    test('Login Account A -> Logout -> Login Account B -> Zero Data Leak', () async {
      final authService = locator<AuthenticationService>();
      final profileProv = locator<MerchantProfileProvider>();
      final orderProv = locator<OrderProvider>();
      final userProv = locator<UserProvider>();

      // -------------------------------------------------------------
      // 1. Log in to Account A
      // -------------------------------------------------------------
      fakeApi.currentUser = 'AccountA';
      await authService.login('+963911111111', 'passwordA');

      expect(authService.user?.fullName, equals('Owner Account A'));
      expect(authService.user?.phoneNumber, equals('+963911111111'));
      expect(profileProv.profile?.title, equals('Store Account A'));
      expect(profileProv.profile?.phone1, equals('+963911111111'));
      expect(profileProv.profile?.id, equals(10));

      // Populate orders for A
      orderProv.dataList = [
        OrderModel(id: 1, description: 'Order 1'),
      ];
      expect(orderProv.dataList.length, equals(1));

      // -------------------------------------------------------------
      // 2. Log out from Account A
      // -------------------------------------------------------------
      await authService.logOut();

      // Verify all user-scoped state is completely cleared
      expect(authService.user, isNull);
      expect(authService.getAccessToken, isEmpty);
      expect(profileProv.profile, isNull);
      expect(orderProv.dataList, isEmpty);
      expect(orderProv.order, isNull);
      expect(userProv.fullName, isNull);

      final prefsAfterLogout = await SharedPreferences.getInstance();
      expect(prefsAfterLogout.containsKey('authorizationKey'), isFalse);
      expect(prefsAfterLogout.containsKey('merchant_prep_deadline_1'), isFalse);
      expect(prefsAfterLogout.containsKey('merchant_picked_items_1'), isFalse);

      // -------------------------------------------------------------
      // 3. Log in to Account B
      // -------------------------------------------------------------
      fakeApi.currentUser = 'AccountB';
      await authService.login('+963922222222', 'passwordB');

      // Verify immediate Account B state with zero leakage from A
      expect(authService.user?.fullName, equals('Owner Account B'));
      expect(authService.user?.phoneNumber, equals('+963922222222'));
      expect(profileProv.profile?.title, equals('Store Account B'));
      expect(profileProv.profile?.phone1, equals('+963922222222'));
      expect(profileProv.profile?.id, equals(20));
      expect(orderProv.dataList, isEmpty); // Old orders from A are NOT present

      // -------------------------------------------------------------
      // 4. Log out from Account B and switch back to Account A
      // -------------------------------------------------------------
      await authService.logOut();
      expect(profileProv.profile, isNull);

      fakeApi.currentUser = 'AccountA';
      await authService.login('+963911111111', 'passwordA');

      expect(authService.user?.fullName, equals('Owner Account A'));
      expect(profileProv.profile?.title, equals('Store Account A'));
      expect(profileProv.profile?.id, equals(10));
    });
  });
}
