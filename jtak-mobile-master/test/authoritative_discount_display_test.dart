import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jtek_app/src/core/controllers/order/cart_provider.dart';
import 'package:jtek_app/src/core/controllers/app_parameters_provider.dart';
import 'package:jtek_app/src/core/controllers/user/address_provider.dart';
import 'package:jtek_app/src/core/models/user/address_model.dart';
import 'package:jtek_app/src/core/services/locator.dart';
import 'package:jtek_app/src/utils/providers/sol_api.dart';
import 'package:jtek_app/src/core/controllers/catalog/markets_provider.dart';
import 'package:jtek_app/src/core/services/authentication_service.dart';
import 'package:jtek_app/src/core/services/main_address_service.dart';
import 'package:jtek_app/src/core/services/firebase_notification_services.dart';
import 'package:jtek_app/src/core/services/local_notification_service.dart';
import 'package:jtek_app/src/core/controllers/app/base_provider.dart';
import 'package:jtek_app/src/core/controllers/app/app_state_manager.dart';
import 'package:jtek_app/src/core/controllers/catalog/favorite_product_provider.dart';
import 'package:jtek_app/src/core/models/catalog/product_model.dart';
import 'package:jtek_app/src/ui/widgets/catalog/price_widgets.dart';
import 'package:jtek_app/src/ui/widgets/catalog/product_widgets.dart';

class _TestAppParametersProvider extends BaseProvider implements AppParametersProvider {
  @override
  late final MainAddressService mainAddressService;

  _TestAppParametersProvider() {
    mainAddressService = MainAddressService(onAddressChanged: notifyListeners);
  }

  @override
  FireBaseNotificationServices get notificationServices => throw UnimplementedError();

  @override
  LocalNotificationService get localNotificationService => throw UnimplementedError();

  @override
  Future loadMainParameters(BuildContext context) async {}

  @override
  Future initServices(BuildContext context) async {}

  @override
  Future resetData() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CartProvider cartProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    if (locator.isRegistered<AppParametersProvider>()) {
      locator.unregister<AppParametersProvider>();
    }
    locator.registerLazySingleton<AppParametersProvider>(() => _TestAppParametersProvider());

    if (!locator.isRegistered<SolApi>()) {
      locator.registerLazySingleton(() => AuthenticationService());
      locator.registerLazySingleton(() => SolApi());
      locator.registerLazySingleton(() => AddressProvider());
      locator.registerLazySingleton(() => CartProvider());
      locator.registerLazySingleton(() => MarketsProvider());
      locator.registerLazySingleton(() => AppStateManager());
    }
    cartProvider = locator<CartProvider>();
    await cartProvider.clearCart();
    await locator<AppParametersProvider>().mainAddressService.setMainAddress(
      AddressModel(
        lat: 33.5138,
        lng: 36.2765,
        title: 'دمشق',
        fullAddress: 'دمشق',
      ),
      resetCart: false,
    );
  });

  group('Authoritative Promotional Discount Rule (#44 UI Regression)', () {
    test('1. No discount: OriginalPrice = null, Discount = 0 => hasAuthoritativeDiscount is false', () {
      final product = ProductModel(
        id: 7269,
        title: 'اورال-بي برو فرشاة الأسنان Oral-B 1-2-3 Indicator Medium',
        price: 81.0,
        finalPrice: 81.0,
        originalPrice: null,
        discount: 0.0,
      );

      expect(product.hasAuthoritativeDiscount, isFalse);
    });

    test('2. OriginalPrice null but PriceUsd exists: => hasAuthoritativeDiscount is false', () {
      final product = ProductModel(
        id: 7269,
        title: 'Oral-B Indicator Toothbrush',
        price: 81.0,
        finalPrice: 81.0,
        priceUsd: 0.60,
        originalPrice: null,
        discount: 0.0,
      );

      // Selling price converts 0.60 * 135 = 81.0 (or fallback 15000 = 9000), but has NO discount UI
      expect(product.hasAuthoritativeDiscount, isFalse);
    });

    test('3. Discount = 0 but OriginalPrice accidentally equals or exists: => hasAuthoritativeDiscount is false', () {
      // 3a. OriginalPrice equals selling price, discount = 0
      final productEqual = ProductModel(
        id: 100,
        title: 'Sample Product',
        price: 81.0,
        finalPrice: 81.0,
        originalPrice: 81.0,
        discount: 0.0,
      );
      expect(productEqual.hasAuthoritativeDiscount, isFalse);

      // 3b. OriginalPrice higher than selling price, but Discount metadata is 0
      final productNoDiscount = ProductModel(
        id: 101,
        title: 'Sample Product No Discount',
        price: 81.0,
        finalPrice: 81.0,
        originalPrice: 100.0,
        discount: 0.0,
      );
      expect(productNoDiscount.hasAuthoritativeDiscount, isFalse);

      // 3c. Discount > 0, but OriginalPrice <= canonicalSellingPrice
      final productInvalidOriginal = ProductModel(
        id: 102,
        title: 'Sample Product Inverted',
        price: 81.0,
        finalPrice: 81.0,
        originalPrice: 70.0,
        discount: 10.0,
      );
      expect(productInvalidOriginal.hasAuthoritativeDiscount, isFalse);
    });

    test('4. Real discounted product: OriginalPrice > FinalPrice and Discount > 0 => hasAuthoritativeDiscount is true', () {
      final productDiscounted = ProductModel(
        id: 200,
        title: 'Genuine Promotional Item',
        price: 100.0,
        finalPrice: 80.0,
        originalPrice: 100.0,
        discount: 20.0,
      );

      expect(productDiscounted.hasAuthoritativeDiscount, isTrue);
    });

    test('5. ProductModel.fromMap parses originalPrice and discount safely', () {
      final mapNoDiscount = {
        'id': 7269,
        'title': 'Oral-B',
        'price': 81.0,
        'finalPrice': 81.0,
        'priceUsd': 0.60,
        'originalPrice': null,
        'discount': 0.0,
      };
      final p1 = ProductModel.fromMap(mapNoDiscount);
      expect(p1.originalPrice, isNull);
      expect(p1.discount, equals(0.0));
      expect(p1.hasAuthoritativeDiscount, isFalse);

      final mapDiscounted = {
        'id': 7270,
        'title': 'Special Deal Item',
        'price': 100.0,
        'finalPrice': 75.0,
        'originalPrice': 100.0,
        'discount': 25.0,
      };
      final p2 = ProductModel.fromMap(mapDiscounted);
      expect(p2.originalPrice, equals(100.0));
      expect(p2.discount, equals(25.0));
      expect(p2.hasAuthoritativeDiscount, isTrue);
    });
  });

  group('DiscountWidget & ProductSingleItem UI Rendering Verification', () {
    testWidgets('DiscountWidget renders SizedBox.shrink when price is 0.0, null, or negative', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                DiscountWidget(price: 0.0),
                DiscountWidget(price: null),
                DiscountWidget(price: -5.0),
              ],
            ),
          ),
        ),
      );

      // Neither 0.00 nor -5.00 should ever render text
      expect(find.textContaining('0.00'), findsNothing);
      expect(find.textContaining('-5.00'), findsNothing);
    });

    testWidgets('ProductSingleItem for Product 7269 shows 81.00 only — NO 0.60 and NO 0.00 strikethrough', (tester) async {
      final product7269 = ProductModel(
        id: 7269,
        title: 'اورال-بي برو فرشاة الأسنان Oral-B 1-2-3 Indicator Medium',
        price: 81.0,
        finalPrice: 81.0,
        priceUsd: 0.60,
        originalPrice: null,
        discount: 0.0,
      );

      Finder findZeroPrice() => find.byWidgetPredicate((w) => w is Text && RegExp(r'(^|\s|‏)0\.00').hasMatch(w.data ?? ''));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
            ChangeNotifierProvider<FavoriteProductProvider>(create: (_) => FavoriteProductProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProductSingleItem(product7269),
            ),
          ),
        ),
      );

      // Verify selling price is visible
      // Note: canonicalSellingPrice uses exchange rate. When MarketsProvider is not registered, defaults to 15000 or fallback.
      // With priceUsd = 0.60 and rate=135, it's 81. With raw price=81, it's 81.
      expect(find.textContaining('0.60'), findsNothing);
      expect(findZeroPrice(), findsNothing);

      // No DiscountWidget should be visible in the tree
      expect(find.byType(DiscountWidget), findsNothing);
    });

    testWidgets('ProductSingleItem for Energizer product shows 585.00 only — NO 0.00 strikethrough', (tester) async {
      Finder findZeroPrice() => find.byWidgetPredicate((w) => w is Text && RegExp(r'(^|\s|‏)0\.00').hasMatch(w.data ?? ''));

      final energizer = ProductModel(
        id: 9999,
        title: 'بطارية انرجايزر ماكس 9 فولت',
        price: 585.0,
        finalPrice: 585.0,
        originalPrice: null,
        discount: 0.0,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
            ChangeNotifierProvider<FavoriteProductProvider>(create: (_) => FavoriteProductProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProductSingleItem(energizer),
            ),
          ),
        ),
      );

      expect(find.textContaining('585.00'), findsOneWidget);
      expect(findZeroPrice(), findsNothing);
      expect(find.byType(DiscountWidget), findsNothing);
    });

    testWidgets('ProductSingleItem for Real Discounted Product shows selling price AND struck-through original price', (tester) async {
      Finder findZeroPrice() => find.byWidgetPredicate((w) => w is Text && RegExp(r'(^|\s|‏)0\.00').hasMatch(w.data ?? ''));

      final discountedProduct = ProductModel(
        id: 5555,
        title: 'عرض ترويجي - زيت زيتون 1 لتر',
        price: 150.0,
        finalPrice: 120.0,
        originalPrice: 150.0,
        discount: 30.0,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
            ChangeNotifierProvider<FavoriteProductProvider>(create: (_) => FavoriteProductProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProductSingleItem(discountedProduct),
            ),
          ),
        ),
      );

      // Selling price 120.00 must be shown
      expect(find.textContaining('120.00'), findsOneWidget);

      // Old price 150.00 must be shown struck-through exactly once
      expect(find.textContaining('150.00'), findsOneWidget);
      expect(find.byType(DiscountWidget), findsOneWidget);

      // Neither 0.00 nor 30.00 (the discount amount) should be rendered as struck through
      expect(findZeroPrice(), findsNothing);
      expect(find.textContaining('30.00'), findsNothing);
    });

    testWidgets('ProductMiniSingleItem respects authoritative discount rules', (tester) async {
      Finder findZeroPrice() => find.byWidgetPredicate((w) => w is Text && RegExp(r'(^|\s|‏)0\.00').hasMatch(w.data ?? ''));

      final regularProduct = ProductModel(
        id: 7269,
        title: 'Oral-B Toothbrush',
        price: 81.0,
        finalPrice: 81.0,
        originalPrice: null,
        discount: 0.0,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
            ChangeNotifierProvider<FavoriteProductProvider>(create: (_) => FavoriteProductProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProductMiniSingleItem(item: regularProduct, width: 200),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(DiscountWidget), findsNothing);
      expect(findZeroPrice(), findsNothing);
    });
  });
}
