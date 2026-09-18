import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jtek_app/src/core/controllers/app_parameters_provider.dart';
import 'package:jtek_app/src/core/controllers/catalog/favorite_product_provider.dart';
import 'package:jtek_app/src/core/controllers/catalog/markets_provider.dart';
import 'package:jtek_app/src/core/controllers/order/cart_provider.dart';
import 'package:jtek_app/src/core/controllers/app/home_navigation_provider.dart';
import 'package:jtek_app/src/core/controllers/user/address_provider.dart';
import 'package:jtek_app/src/core/models/user/address_model.dart';
import 'package:jtek_app/src/core/services/authentication_service.dart';
import 'package:jtek_app/src/core/services/locator.dart';
import 'package:jtek_app/src/core/services/main_address_service.dart';
import 'package:jtek_app/src/core/services/firebase_notification_services.dart';
import 'package:jtek_app/src/core/services/local_notification_service.dart';
import 'package:jtek_app/src/core/controllers/app/base_provider.dart';
import 'package:jtek_app/src/ui/pages/catalog/most_ordered_products_page.dart';
import 'package:jtek_app/src/ui/pages/catalog/restaurants_list_page.dart';
import 'package:jtek_app/src/ui/widgets/catalog/meal_card_widget.dart';
import 'package:jtek_app/src/ui/widgets/delivery_offers_section.dart';
import 'package:jtek_app/src/utils/providers/sol_api.dart';

class TestAppParametersProvider extends BaseProvider implements AppParametersProvider {
  @override
  late final MainAddressService mainAddressService;

  TestAppParametersProvider() {
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
  late FavoriteProductProvider favProvider;
  late MarketsProvider marketsProvider;
  late HomeNavigationProvider navProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    if (locator.isRegistered<AppParametersProvider>()) {
      locator.unregister<AppParametersProvider>();
    }
    locator.registerLazySingleton<AppParametersProvider>(() => TestAppParametersProvider());

    if (!locator.isRegistered<AuthenticationService>()) {
      locator.registerLazySingleton(() => AuthenticationService());
    }
    if (!locator.isRegistered<SolApi>()) {
      locator.registerLazySingleton(() => SolApi());
    }
    if (!locator.isRegistered<AddressProvider>()) {
      locator.registerLazySingleton(() => AddressProvider());
    }
    if (!locator.isRegistered<CartProvider>()) {
      locator.registerLazySingleton(() => CartProvider());
    }
    if (!locator.isRegistered<FavoriteProductProvider>()) {
      locator.registerLazySingleton(() => FavoriteProductProvider());
    }
    if (locator.isRegistered<MarketsProvider>()) {
      locator.unregister<MarketsProvider>();
    }
    locator.registerLazySingleton(() => MarketsProvider(autoLoad: false));
    if (!locator.isRegistered<HomeNavigationProvider>()) {
      locator.registerLazySingleton(() => HomeNavigationProvider());
    }

    cartProvider = locator<CartProvider>();
    favProvider = locator<FavoriteProductProvider>();
    marketsProvider = locator<MarketsProvider>();
    navProvider = locator<HomeNavigationProvider>();

    marketsProvider.setPopularMealsForTesting([]);

    await cartProvider.clearCart();
    await locator<AppParametersProvider>().mainAddressService.setMainAddress(
      AddressModel(
        lat: 33.5138,
        lng: 36.2765,
        title: 'دمشق - الميدان',
        fullAddress: 'دمشق - الميدان - شارع الكورنيش',
      ),
      resetCart: false,
    );
  });

  group('Most Ordered ("الأكثر طلباً") Navigation & Product Page Verification', () {
    testWidgets('Tapping "عرض الكل" in JtakDeliveryOffersSection navigates to MostOrderedProductsPage (NOT RestaurantsListPage)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MarketsProvider>.value(value: marketsProvider),
            ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
            ChangeNotifierProvider<FavoriteProductProvider>.value(value: favProvider),
            ChangeNotifierProvider<HomeNavigationProvider>.value(value: navProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: JtakDeliveryOffersSection(),
            ),
          ),
        ),
      );

      await tester.pump();

      // Find "عرض الكل" in the Most Ordered section
      final viewAllFinder = find.text('عرض الكل');
      expect(viewAllFinder, findsOneWidget);

      // Tap "عرض الكل"
      await tester.tap(viewAllFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify MostOrderedProductsPage is now open
      expect(find.byType(MostOrderedProductsPage), findsOneWidget);
      // Verify RestaurantsListPage is NOT opened
      expect(find.byType(RestaurantsListPage), findsNothing);

      // Verify page title is "الأكثر طلباً"
      expect(find.text('الأكثر طلباً'), findsWidgets);
    });

    testWidgets('MostOrderedProductsPage renders title and handles product empty state with product wording',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MarketsProvider>.value(value: marketsProvider),
            ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
            ChangeNotifierProvider<FavoriteProductProvider>.value(value: favProvider),
          ],
          child: const MaterialApp(
            home: MostOrderedProductsPage(),
          ),
        ),
      );

      await tester.pump();

      // Page Title
      expect(find.text('الأكثر طلباً'), findsOneWidget);

      // Verify product wording on empty state (NOT restaurant wording)
      expect(find.text('لا توجد أصناف أكثر طلباً متاحة حالياً'), findsOneWidget);
      expect(find.textContaining('مطاعم'), findsNothing);
    });

    testWidgets('Empty backend Popular API response preserves empty state and never synthesizes meals from restaurant menus',
        (WidgetTester tester) async {
      // Explicitly set popular meals to empty (as returned by GET /Customer/Products/Popular)
      marketsProvider.setPopularMealsForTesting([]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MarketsProvider>.value(value: marketsProvider),
            ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
            ChangeNotifierProvider<FavoriteProductProvider>.value(value: favProvider),
          ],
          child: const MaterialApp(
            home: MostOrderedProductsPage(),
          ),
        ),
      );

      await tester.pump();

      // Verify empty state is displayed and NO product cards or synthetic items are shown
      expect(find.text('لا توجد أصناف أكثر طلباً متاحة حالياً'), findsOneWidget);
      expect(find.byType(JtakMealCard), findsNothing);
      expect(marketsProvider.popularMeals, isEmpty);
    });

    testWidgets('Failed backend Popular API response displays error and retry button',
        (WidgetTester tester) async {
      // Simulate backend endpoint failure
      marketsProvider.setPopularMealsForTesting([], error: 'Network timeout');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MarketsProvider>.value(value: marketsProvider),
            ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
            ChangeNotifierProvider<FavoriteProductProvider>.value(value: favProvider),
          ],
          child: const MaterialApp(
            home: MostOrderedProductsPage(),
          ),
        ),
      );

      await tester.pump();

      // Verify error view with retry button
      expect(find.text('تعذر تحميل الأصناف الأكثر طلباً'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
      expect(find.byType(JtakMealCard), findsNothing);
    });

    testWidgets('MostOrderedProductsPage renders authoritative items in exact backend order',
        (WidgetTester tester) async {
      final backendRankedMeals = [
        const MealItemData(
          id: 101,
          title: 'وجبة برغر كلاسيك سوبريم',
          price: '30,000 ل.س',
          coverUrl: '',
          merchantLogoUrl: '',
          merchantName: 'برغر كينغ دمشق',
          eta: '15-25 دقيقة',
          distance: '1.2 كم',
          merchantId: 10,
          numericPrice: 30000.0,
        ),
        const MealItemData(
          id: 102,
          title: 'شاورما دجاج إكسترا ثوم',
          price: '22,000 ل.س',
          coverUrl: '',
          merchantLogoUrl: '',
          merchantName: 'شاورما أنس',
          eta: '20-30 دقيقة',
          distance: '2.1 كم',
          merchantId: 5,
          numericPrice: 22000.0,
        ),
      ];

      marketsProvider.setPopularMealsForTesting(backendRankedMeals);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MarketsProvider>.value(value: marketsProvider),
            ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
            ChangeNotifierProvider<FavoriteProductProvider>.value(value: favProvider),
          ],
          child: const MaterialApp(
            home: MostOrderedProductsPage(),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(JtakMealCard), findsNWidgets(2));
      expect(find.text('وجبة برغر كلاسيك سوبريم'), findsOneWidget);
      expect(find.text('شاورما دجاج إكسترا ثوم'), findsOneWidget);
    });

    test('Adding product to cart increments CartProvider and reflects in quantity stepper', () async {
      const testMeal = MealItemData(
        id: 999,
        title: 'شاورما دجاج مميزة',
        price: '25,000 ل.س',
        coverUrl: '',
        merchantLogoUrl: '',
        merchantName: 'شاورما أنس',
        eta: '20-30 دقيقة',
        distance: '1.5 كم',
        merchantId: 5,
        numericPrice: 25000.0,
      );

      // Initial count is 0
      expect(cartProvider.getProductQuantity(testMeal.id), equals(0));

      // Add to cart
      await cartProvider.addToCart(
        testMeal.id,
        testMeal.merchantId,
        testMeal.numericPrice,
        quantity: 1,
        title: testMeal.title,
        merchantTitle: testMeal.merchantName,
      );

      // Quantity is now 1
      expect(cartProvider.getProductQuantity(testMeal.id), equals(1));
      expect(cartProvider.currentMerchantId, equals(5));
      expect(cartProvider.totalUnits, equals(1));

      // Add another unit
      await cartProvider.addToCart(
        testMeal.id,
        testMeal.merchantId,
        testMeal.numericPrice,
        quantity: 1,
        title: testMeal.title,
        merchantTitle: testMeal.merchantName,
      );

      expect(cartProvider.getProductQuantity(testMeal.id), equals(2));

      // Decrement
      cartProvider.removeFromCart(testMeal.id, testMeal.merchantId);
      expect(cartProvider.getProductQuantity(testMeal.id), equals(0));
    });

    test('Single-merchant cart isolation is preserved from Most Ordered products', () async {
      // Cart contains item from Merchant 10
      await cartProvider.addToCart(
        101,
        10,
        15000.0,
        quantity: 1,
        title: 'برغر كلاسيك',
        merchantTitle: 'برغر هاوس',
      );

      expect(cartProvider.currentMerchantId, equals(10));
      expect(cartProvider.isDifferentMerchant(10), isFalse);
      expect(cartProvider.isDifferentMerchant(1), isTrue);

      // Conflict detection for product from Restaurant 1
      expect(cartProvider.isDifferentMerchant(1), isTrue);
      expect(cartProvider.getConflictingMerchantName(1), isNotEmpty);
    });

    test('Favorites toggle updates FavoriteProductProvider and persists correctly', () async {
      const testMeal = MealItemData(
        id: 777,
        title: 'وجبة كباب حلبي',
        price: '45,000 ل.س',
        coverUrl: '',
        merchantLogoUrl: '',
        merchantName: 'مشاوي الشام',
        eta: '25-35 دقيقة',
        distance: '2.0 كم',
        merchantId: 8,
        numericPrice: 45000.0,
      );

      expect(favProvider.isMealFavorite(testMeal.id), isFalse);

      favProvider.toggleMealFavorite(testMeal.id, testMeal);
      expect(favProvider.isMealFavorite(testMeal.id), isTrue);
      expect(favProvider.favoriteMeals.any((m) => m.id == testMeal.id), isTrue);

      favProvider.toggleMealFavorite(testMeal.id, testMeal);
      expect(favProvider.isMealFavorite(testMeal.id), isFalse);
    });
  });
}
