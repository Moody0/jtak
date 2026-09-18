import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_jtak_delivery/src/core/models/order_model.dart';
import 'package:app_jtak_delivery/src/core/models/merchant_order_details.dart';
import 'package:app_jtak_delivery/src/utils/utilities/map_helper.dart';
import 'package:app_jtak_delivery/src/utils/utilities/global_var.dart';
import 'package:app_jtak_delivery/src/ui/pages/order/order_widgets.dart';

Widget _buildTestApp({required Widget body, Locale locale = const Locale('ar')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: SingleChildScrollView(
        child: body,
      ),
    ),
  );
}

void main() {
  setUp(() {
    MapHelper.resetForTesting();
  });

  tearDown(() {
    MapHelper.resetForTesting();
  });

  group('MapHelper - Coordinate & Address Validation', () {
    test('1. Validates standard geographic GPS coordinates within ranges', () {
      expect(MapHelper.isValidCoordinate(33.5138, 36.2765), isTrue);
      expect(MapHelper.isValidCoordinate(-33.8688, 151.2093), isTrue);
      expect(MapHelper.isValidCoordinate(90.0, 180.0), isTrue);
      expect(MapHelper.isValidCoordinate(-90.0, -180.0), isTrue);
    });

    test('2. Rejects Null Island (0,0), nulls, NaNs, infinities, and out-of-bounds coordinates', () {
      expect(MapHelper.isValidCoordinate(0.0, 0.0), isFalse);
      expect(MapHelper.isValidCoordinate(null, 36.2765), isFalse);
      expect(MapHelper.isValidCoordinate(33.5138, null), isFalse);
      expect(MapHelper.isValidCoordinate(null, null), isFalse);
      expect(MapHelper.isValidCoordinate(double.nan, 36.2765), isFalse);
      expect(MapHelper.isValidCoordinate(33.5138, double.infinity), isFalse);
      expect(MapHelper.isValidCoordinate(90.001, 36.0), isFalse);
      expect(MapHelper.isValidCoordinate(-90.001, 36.0), isFalse);
      expect(MapHelper.isValidCoordinate(33.0, 180.001), isFalse);
      expect(MapHelper.isValidCoordinate(33.0, -180.001), isFalse);
    });

    test('3. Validates and trims address fallback strings', () {
      expect(MapHelper.isValidAddress('Damascus, Mezzeh East'), isTrue);
      expect(MapHelper.isValidAddress('   '), isFalse);
      expect(MapHelper.isValidAddress(null), isFalse);
      expect(MapHelper.isValidAddress('null'), isFalse);
      expect(MapHelper.isValidAddress('العنوان غير محدد'), isFalse);
    });
  });

  group('MapHelper - URL & URI Generation', () {
    test('4. Builds direct Google Maps directions URL for valid coordinates', () {
      final url = MapHelper.buildDirectionsUrl(
        lat: 33.5138,
        lng: 36.2765,
        address: 'Damascus, Old City',
      );
      expect(url, equals('https://www.google.com/maps/dir/?api=1&destination=33.5138,36.2765'));
    });

    test('5. Falls back to encoded address URL when coordinates are missing/zero', () {
      final urlZero = MapHelper.buildDirectionsUrl(
        lat: 0.0,
        lng: 0.0,
        address: 'Damascus, Mezzeh Autostrade',
      );
      expect(urlZero, equals('https://www.google.com/maps/dir/?api=1&destination=Damascus%2C%20Mezzeh%20Autostrade'));

      final urlNull = MapHelper.buildDirectionsUrl(
        lat: null,
        lng: null,
        address: 'دمشق - المزة فيلات غربية',
      );
      expect(urlNull, contains('https://www.google.com/maps/dir/?api=1&destination='));
      expect(urlNull, contains(Uri.encodeComponent('دمشق - المزة فيلات غربية')));
    });

    test('6. Returns null when neither coordinates nor address are available', () {
      expect(MapHelper.buildDirectionsUrl(lat: null, lng: null, address: null), isNull);
      expect(MapHelper.buildDirectionsUrl(lat: 0.0, lng: 0.0, address: ''), isNull);
      expect(MapHelper.buildDirectionsUrl(lat: null, lng: null, address: 'العنوان غير محدد'), isNull);
    });

    test('7. Builds geo: intent URI with optional label encoding', () {
      final geoNoLabel = MapHelper.buildGeoUri(lat: 33.5138, lng: 36.2765);
      expect(geoNoLabel, equals('geo:33.5138,36.2765?q=33.5138,36.2765'));

      final geoWithLabel = MapHelper.buildGeoUri(
        lat: 33.5138,
        lng: 36.2765,
        label: 'مطعم الشام',
      );
      expect(geoWithLabel, contains('geo:33.5138,36.2765?q=33.5138,36.2765('));
      expect(geoWithLabel, contains(Uri.encodeComponent('مطعم الشام')));
    });
  });

  group('MapHelper - Multi-tier Navigation Launcher & Debouncing', () {
    test('8. Multi-tier launcher attempts external app first, then geo intent, then web browser fallback', () async {
      final List<String> launchedUris = [];
      final List<LaunchMode> launchedModes = [];

      MapHelper.testLauncher = (Uri uri, LaunchMode mode) async {
        launchedUris.add(uri.toString());
        launchedModes.add(mode);
        // Simulate external app launch failure on first tier, success on geo tier
        if (uri.scheme == 'https' && mode == LaunchMode.externalApplication) {
          return false;
        }
        if (uri.scheme == 'geo') {
          return true;
        }
        return false;
      };

      final success = await MapHelper.launchMapDirections(
        lat: 33.5138,
        lng: 36.2765,
        label: 'Store Destination',
        isMerchant: true,
      );

      expect(success, isTrue);
      expect(launchedUris.length, equals(2));
      expect(launchedUris[0], equals('https://www.google.com/maps/dir/?api=1&destination=33.5138,36.2765'));
      expect(launchedModes[0], equals(LaunchMode.externalApplication));
      expect(launchedUris[1], contains('geo:33.5138,36.2765'));
    });

    test('9. Debounces rapid subsequent taps within debounce window', () async {
      int launchCallCount = 0;
      MapHelper.testLauncher = (Uri uri, LaunchMode mode) async {
        launchCallCount++;
        return true;
      };

      // Tap 1
      final res1 = await MapHelper.launchMapDirections(
        lat: 33.5138,
        lng: 36.2765,
        isMerchant: true,
      );
      expect(res1, isTrue);
      expect(launchCallCount, equals(1));

      // Tap 2 immediately (within 1000ms)
      final res2 = await MapHelper.launchMapDirections(
        lat: 33.5138,
        lng: 36.2765,
        isMerchant: true,
      );
      expect(res2, isFalse);
      expect(launchCallCount, equals(1)); // Should NOT trigger second launch
    });
  });

  group('Widget Tests - Store Map & Customer Map Buttons', () {
    testWidgets('10. Store Map button navigates strictly to merchant coordinates with proper debouncing',
        (WidgetTester tester) async {
      final merchant = MerchentOrderDetailsModel(
        merchantId: 12,
        merchantTitle: 'سوبرماركت النور',
        merchantAddress: 'دمشق - المزة',
        merchantPhone: '0933111222',
        lat: 33.5138,
        lng: 36.2765,
      );

      Uri? lastLaunchedUri;
      LaunchMode? lastMode;
      MapHelper.testLauncher = (Uri uri, LaunchMode mode) async {
        lastLaunchedUri = uri;
        lastMode = mode;
        return true;
      };

      await tester.pumpWidget(
        _buildTestApp(
          body: MerchentOrderDetailsCard(
            item: merchant,
            orderId: 100,
          ),
        ),
      );

      final storeMapButtonFinder = find.widgetWithText(OutlinedButton, 'خريطة المتجر');
      expect(storeMapButtonFinder, findsOneWidget);

      await tester.tap(storeMapButtonFinder);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(lastLaunchedUri, isNotNull);
      expect(lastLaunchedUri.toString(),
          equals('https://www.google.com/maps/dir/?api=1&destination=33.5138,36.2765'));
      expect(lastMode, equals(LaunchMode.externalApplication));
    });

    testWidgets('11. Customer Map button navigates strictly to customer delivery coordinates and NOT store',
        (WidgetTester tester) async {
      final order = OrderModel(
        id: 200,
        user: 'أحمد علي',
        address: 'دمشق - المالكي',
        phonenumber: '0988776655',
        lat: 33.5012,
        lng: 36.2514, // Customer coordinates
      );

      Uri? lastLaunchedUri;
      MapHelper.testLauncher = (Uri uri, LaunchMode mode) async {
        lastLaunchedUri = uri;
        return true;
      };

      await tester.pumpWidget(
        _buildTestApp(
          body: CustomerOrderDetailsCard(
            order: order,
          ),
        ),
      );

      final customerMapButtonFinder = find.widgetWithText(OutlinedButton, 'خريطة العميل');
      expect(customerMapButtonFinder, findsOneWidget);

      await tester.tap(customerMapButtonFinder);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(lastLaunchedUri, isNotNull);
      expect(lastLaunchedUri.toString(),
          equals('https://www.google.com/maps/dir/?api=1&destination=33.5012,36.2514'));
    });

    testWidgets('12. Missing store coordinates displays explicit Arabic SnackBar message',
        (WidgetTester tester) async {
      final merchant = MerchentOrderDetailsModel(
        merchantId: 15,
        merchantTitle: 'متجر بلا عنوان',
        merchantAddress: null,
        lat: null,
        lng: null,
      );

      await tester.pumpWidget(
        _buildTestApp(
          body: MerchentOrderDetailsCard(
            item: merchant,
            orderId: 101,
          ),
        ),
      );

      final storeMapButtonFinder = find.widgetWithText(OutlinedButton, 'خريطة المتجر');
      expect(storeMapButtonFinder, findsOneWidget);

      await tester.tap(storeMapButtonFinder);
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 100)); // Render SnackBar

      expect(find.text('موقع المتجر غير متوفر حالياً'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('13. Missing customer coordinates displays explicit Arabic SnackBar message',
        (WidgetTester tester) async {
      final order = OrderModel(
        id: 202,
        user: 'عميل بلا عنوان',
        address: null,
        lat: null,
        lng: null,
      );

      await tester.pumpWidget(
        _buildTestApp(
          body: CustomerOrderDetailsCard(
            order: order,
          ),
        ),
      );

      final customerMapButtonFinder = find.widgetWithText(OutlinedButton, 'خريطة العميل');
      expect(customerMapButtonFinder, findsOneWidget);

      await tester.tap(customerMapButtonFinder);
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 100)); // Render SnackBar

      expect(find.text('موقع العميل غير متوفر حالياً'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('14. Multi-merchant orders maintain distinct store coordinates for each merchant card',
        (WidgetTester tester) async {
      final store1 = MerchentOrderDetailsModel(
        merchantId: 1,
        merchantTitle: 'مطعم الشام',
        lat: 33.5111,
        lng: 36.2711,
      );
      final store2 = MerchentOrderDetailsModel(
        merchantId: 2,
        merchantTitle: 'حلويات النعيم',
        lat: 33.5222,
        lng: 36.2822,
      );

      final List<String> destinations = [];
      MapHelper.testLauncher = (Uri uri, LaunchMode mode) async {
        destinations.add(uri.toString());
        return true;
      };

      await tester.pumpWidget(
        _buildTestApp(
          body: Column(
            children: [
              MerchentOrderDetailsCard(item: store1, orderId: 300),
              MerchentOrderDetailsCard(item: store2, orderId: 300),
            ],
          ),
        ),
      );

      final mapButtons = find.widgetWithText(OutlinedButton, 'خريطة المتجر');
      expect(mapButtons, findsNWidgets(2));

      // Tap Store 1
      await tester.tap(mapButtons.at(0));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(destinations.length, equals(1));
      expect(destinations[0], equals('https://www.google.com/maps/dir/?api=1&destination=33.5111,36.2711'));

      // Reset debouncer for next tap in test
      MapHelper.resetForTesting();
      MapHelper.testLauncher = (Uri uri, LaunchMode mode) async {
        destinations.add(uri.toString());
        return true;
      };

      // Tap Store 2
      await tester.tap(mapButtons.at(1));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(destinations.length, equals(2));
      expect(destinations[1], equals('https://www.google.com/maps/dir/?api=1&destination=33.5222,36.2822'));
    });
  });

  group('Model Deserialization & Snapshot Isolation', () {
    test('15. OrderModel and MerchentOrderDetailsModel correctly parse coordinates across casing and types', () {
      final orderJson = {
        'id': 501,
        'user': 'طارق',
        'lat': '33.5140',
        'lng': 36.2770,
        'orderDetails': [
          {
            'merchantId': 88,
            'merchantTitle': 'صيدلية الأمل',
            'Lat': 33.5200,
            'Lng': '36.2800',
          }
        ]
      };

      final order = OrderModel.fromMap(orderJson);
      expect(order.lat, equals(33.5140));
      expect(order.lng, equals(36.2770));

      final merchant = order.orderDetails!.first;
      expect(merchant.lat, equals(33.5200));
      expect(merchant.lng, equals(36.2800));

      // Validate that GlobalVar methods properly resolve both URLs
      final customerUrl = GlobalVar.getCustomerNavigationUrl(
        lat: order.lat,
        lng: order.lng,
        address: order.address,
      );
      expect(customerUrl, equals('https://www.google.com/maps/dir/?api=1&destination=33.514,36.277'));

      final merchantUrl = GlobalVar.getMerchantNavigationUrl(
        lat: merchant.lat,
        lng: merchant.lng,
        address: merchant.merchantAddress,
      );
      expect(merchantUrl, equals('https://www.google.com/maps/dir/?api=1&destination=33.52,36.28'));
    });
  });
}
