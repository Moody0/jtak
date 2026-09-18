import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jtek_app/src/core/controllers/user/address_provider.dart';
import 'package:jtek_app/src/core/controllers/app_parameters_provider.dart';
import 'package:jtek_app/src/core/models/user/address_model.dart';
import 'package:jtek_app/src/core/services/authentication_service.dart';
import 'package:jtek_app/src/core/services/locator.dart';
import 'package:jtek_app/src/utils/custom_widgets/messages.dart';
import 'package:jtek_app/src/utils/providers/sol_api.dart';

class FakeSolApi extends SolApi {
  bool shouldFailDelete = false;
  bool shouldFailGet = false;
  List<Map<String, dynamic>> remoteAddresses = [];
  String? lastDeletedPath;

  @override
  Future<dynamic> getRequest(String subUrl, {Map<String, String>? headers, String? apiPrefex}) async {
    if (shouldFailGet) throw Exception('Network error on get');
    if (subUrl == '/Address/Mine') {
      return remoteAddresses;
    }
    return [];
  }

  @override
  Future<dynamic> deleteRequest(String subUrl, {Map<String, String>? headers, String? apiPrefex}) async {
    lastDeletedPath = subUrl;
    if (shouldFailDelete) {
      throw Exception('500 Internal Server Error: Failed to delete address');
    }
    final idStr = subUrl.split('/').last;
    final id = int.tryParse(idStr);
    remoteAddresses.removeWhere((a) => a['id'] == id);
    return {'success': true};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSolApi fakeApi;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeApi = FakeSolApi();
    fakeApi.accessToken = 'valid_test_jwt_token_customer';

    if (locator.isRegistered<SolApi>()) {
      locator.unregister<SolApi>();
    }
    locator.registerSingleton<SolApi>(fakeApi);

    if (!locator.isRegistered<AuthenticationService>()) {
      locator.registerLazySingleton<AuthenticationService>(() => AuthenticationService());
    }
  });

  group('Address Delete & Confirmation Dialog Tests', () {
    testWidgets('CustomConfirmationDialog pops true on confirm', (tester) async {
      bool yesCalled = false;
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    builder: (_) => CustomConfirmationDialog(
                      title: 'حذف العنوان',
                      message: 'هل أنت متأكد؟',
                      yesText: 'تأكيد الحذف',
                      cancelText: 'تراجع',
                      yesBTNCallBack: () {
                        yesCalled = true;
                      },
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('حذف العنوان'), findsOneWidget);
      expect(find.text('تأكيد الحذف'), findsOneWidget);

      await tester.tap(find.text('تأكيد الحذف'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(yesCalled, isTrue);
      expect(result, isTrue);
    });

    testWidgets('CustomConfirmationDialog pops false on cancel', (tester) async {
      bool yesCalled = false;
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    builder: (_) => CustomConfirmationDialog(
                      title: 'حذف العنوان',
                      message: 'هل أنت متأكد؟',
                      yesText: 'تأكيد الحذف',
                      cancelText: 'تراجع',
                      yesBTNCallBack: () {
                        yesCalled = true;
                      },
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('حذف العنوان'), findsOneWidget);
      expect(find.text('تراجع'), findsOneWidget);

      await tester.tap(find.text('تراجع'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(yesCalled, isFalse);
      expect(result, isFalse);
    });
  });

  group('AddressProvider Deletion & Rollback Verification Suite', () {
    test('1. Successful address deletion removes address from list and calls API', () async {
      final provider = AddressProvider();
      final addr1 = AddressModel(id: 101, title: 'المنزل', fullAddress: 'دمشق - المزة', isActive: true);
      final addr2 = AddressModel(id: 102, title: 'العمل', fullAddress: 'دمشق - الشعلان', isActive: false);
      fakeApi.remoteAddresses = [addr1.toMap(), addr2.toMap()];
      provider.dataList = [addr1, addr2];

      final success = await provider.delete(102);

      expect(success, isTrue);
      expect(fakeApi.lastDeletedPath, '/Address/102');
      expect(provider.dataList.any((a) => a.id == 102), isFalse);
      expect(provider.lastDeleteError, isNull);
    });

    test('2. Backend API failure triggers rollback and restores address in list', () async {
      final provider = AddressProvider();
      final addr1 = AddressModel(id: 201, title: 'المنزل', fullAddress: 'دمشق - المالكي', isActive: true);
      final addr2 = AddressModel(id: 202, title: 'المتجر', fullAddress: 'دمشق - الصالحية', isActive: false);
      provider.dataList = [addr1, addr2];

      fakeApi.shouldFailDelete = true;
      final success = await provider.delete(202);

      expect(success, isFalse);
      expect(provider.dataList.length, 2);
      expect(provider.dataList.any((a) => a.id == 202), isTrue);
      expect(provider.lastDeleteError, isNotNull);
    });

    test('3. Address deletion failure preserves exact original index in dataList', () async {
      final provider = AddressProvider();
      final addr1 = AddressModel(id: 301, title: 'موقع 1');
      final addr2 = AddressModel(id: 302, title: 'موقع 2 (وسط)');
      final addr3 = AddressModel(id: 303, title: 'موقع 3');
      provider.dataList = [addr1, addr2, addr3];

      fakeApi.shouldFailDelete = true;
      // Delete middle item at index 1
      final success = await provider.delete(302);

      expect(success, isFalse);
      expect(provider.dataList.length, 3);
      expect(provider.dataList[0].id, 301);
      expect(provider.dataList[1].id, 302);
      expect(provider.dataList[2].id, 303);
    });

    test('4. Address deletion failure preserves isActive and default state of restored address', () async {
      final provider = AddressProvider();
      final activeAddr = AddressModel(id: 401, title: 'الرئيسي النشط', isActive: true, fullAddress: 'أبو رمانة');
      final otherAddr = AddressModel(id: 402, title: 'عنوان ثانوي', isActive: false);
      provider.dataList = [activeAddr, otherAddr];

      fakeApi.shouldFailDelete = true;
      final success = await provider.delete(401);

      expect(success, isFalse);
      final restored = provider.dataList.firstWhere((a) => a.id == 401);
      expect(restored.isActive, isTrue);
      expect(restored.fullAddress, 'أبو رمانة');
      expect(provider.getActiveAddress()?.id, 401);
    });

    test('5. Address deletion failure sets lastDeleteError, globalMessage, and notifies listeners', () async {
      final provider = AddressProvider();
      final addr = AddressModel(id: 501, title: 'المستودع');
      provider.dataList = [addr];

      int notificationCount = 0;
      provider.addListener(() {
        notificationCount++;
      });

      fakeApi.shouldFailDelete = true;
      final success = await provider.delete(501);

      expect(success, isFalse);
      expect(provider.lastDeleteError, contains('تعذر حذف العنوان'));
      expect(provider.globalMessage, provider.lastDeleteError);
      // Notified at least twice: optimistic removal + rollback on error
      expect(notificationCount, greaterThanOrEqualTo(2));
    });

    test('6. Address deletion of non-existent ID gracefully returns false without corrupting list', () async {
      final provider = AddressProvider();
      final addr1 = AddressModel(id: 601, title: 'موقع قائم');
      provider.dataList = [addr1];

      final success = await provider.delete(99999);

      expect(success, isFalse);
      expect(provider.dataList.length, 1);
      expect(provider.dataList.first.id, 601);
      expect(provider.lastDeleteError, 'العنوان غير موجود');
    });
  });
}
