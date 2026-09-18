import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jtek_app/src/core/controllers/order/cart_provider.dart';
import 'package:jtek_app/src/core/controllers/app_parameters_provider.dart';
import 'package:jtek_app/src/core/controllers/user/address_provider.dart';
import 'package:jtek_app/src/core/models/catalog/product_model.dart';
import 'package:jtek_app/src/core/models/user/address_model.dart';
import 'package:jtek_app/src/core/services/locator.dart';
import 'package:jtek_app/src/utils/providers/sol_api.dart';
import 'package:jtek_app/src/core/controllers/catalog/markets_provider.dart';
import 'package:jtek_app/src/core/services/authentication_service.dart';
import 'package:jtek_app/src/core/services/main_address_service.dart';
import 'package:jtek_app/src/core/services/firebase_notification_services.dart';
import 'package:jtek_app/src/core/services/local_notification_service.dart';
import 'package:jtek_app/src/core/controllers/app/base_provider.dart';
import 'package:jtek_app/src/ui/pages/cart/add_to_cart_widget.dart';

/// Test mock of [AppParametersProvider] that provides real [MainAddressService]
/// without instantiating [LocalNotificationService], keeping production code untouched.
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    if (locator.isRegistered<AppParametersProvider>()) {
      locator.unregister<AppParametersProvider>();
    }
    locator.registerLazySingleton<AppParametersProvider>(() => TestAppParametersProvider());

    if (!locator.isRegistered<SolApi>()) {
      locator.registerLazySingleton(() => AuthenticationService());
      locator.registerLazySingleton(() => SolApi());
      locator.registerLazySingleton(() => AddressProvider());
      locator.registerLazySingleton(() => CartProvider());
      locator.registerLazySingleton(() => MarketsProvider());
    }
    cartProvider = locator<CartProvider>();
    await cartProvider.clearCart();

    // Ensure mock address is available so add-to-cart doesn't prompt for address selection
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

  group('Manual-QA Bug #46: Functional Cart Behavior & Integrity', () {
    test('1. Add from search -> quantity 1', () async {
      final product = ProductModel(
        id: 7269,
        merchantId: 10,
        title: 'Oral-B Toothbrush',
        price: 0.60,
        finalPrice: 0.60,
        priceUsd: 0.60,
      );

      expect(cartProvider.localCartItems.length, 0);
      expect(cartProvider.getProductQuantity(product.id, product.merchantId), 0);

      await cartProvider.addToCart(
        product.id!,
        product.merchantId!,
        product.canonicalSellingPrice,
        quantity: 1,
        title: product.title,
      );

      expect(cartProvider.localCartItems.length, 1);
      final item = cartProvider.findItme(product.id!, product.merchantId!);
      expect(item, isNotNull);
      expect(item!.quantity, 1);
      expect(item.productId, 7269);
      expect(item.merchantId, 10);
    });

    test('2. Increment from search -> quantity 2 (no duplicate lines)', () async {
      final product = ProductModel(
        id: 7390,
        merchantId: 10,
        title: 'Energizer Max Plus AA',
        price: 4.33,
        finalPrice: 4.33,
        priceUsd: 4.33,
      );

      // Initial add
      await cartProvider.addToCart(
        product.id!,
        product.merchantId!,
        product.canonicalSellingPrice,
        quantity: 1,
        title: product.title,
      );
      expect(cartProvider.localCartItems.length, 1);
      expect(cartProvider.findItme(product.id!, product.merchantId!)!.quantity, 1);

      // Second add / increment
      await cartProvider.addToCart(
        product.id!,
        product.merchantId!,
        product.canonicalSellingPrice,
        quantity: 1,
        title: product.title,
      );

      // Must remain 1 line item, with quantity = 2
      expect(cartProvider.localCartItems.length, 1, reason: 'Must not create duplicate cart lines');
      expect(cartProvider.findItme(product.id!, product.merchantId!)!.quantity, 2);
    });

    test('3. Decrement from search -> quantity 1', () async {
      final product = ProductModel(
        id: 8345,
        merchantId: 10,
        title: 'Tiffany Break Rizzo',
        price: 3.34,
        finalPrice: 3.34,
        priceUsd: 3.34,
      );

      // Start with quantity 2
      await cartProvider.addToCart(
        product.id!,
        product.merchantId!,
        product.canonicalSellingPrice,
        quantity: 2,
        title: product.title,
      );
      expect(cartProvider.findItme(product.id!, product.merchantId!)!.quantity, 2);

      // Decrement to 1
      await cartProvider.setToCart(
        product.id!,
        product.merchantId!,
        product.canonicalSellingPrice,
        1,
        title: product.title,
      );

      expect(cartProvider.localCartItems.length, 1);
      expect(cartProvider.findItme(product.id!, product.merchantId!)!.quantity, 1);
    });

    test('4. Decrement to zero -> cleanly removes item from cart', () async {
      final product = ProductModel(
        id: 5702,
        merchantId: 10,
        title: 'Genuine Bread',
        price: 250.0,
        finalPrice: 250.0,
      );

      await cartProvider.addToCart(
        product.id!,
        product.merchantId!,
        product.canonicalSellingPrice,
        quantity: 1,
        title: product.title,
      );
      expect(cartProvider.localCartItems.length, 1);

      // Remove / decrement to zero
      await cartProvider.removeFromCart(product.id!, product.merchantId!);

      expect(cartProvider.localCartItems.length, 0);
      expect(cartProvider.findItme(product.id!, product.merchantId!), isNull);
      expect(cartProvider.totalQuantity, 0);
      expect(cartProvider.totalUnits, 0);
    });

    test('5. Cart badge and total units reflect search actions immediately', () async {
      final productA = ProductModel(id: 101, merchantId: 10, title: 'Item A', price: 1000.0, finalPrice: 1000.0);
      final productB = ProductModel(id: 102, merchantId: 10, title: 'Item B', price: 2000.0, finalPrice: 2000.0);

      expect(cartProvider.totalQuantity, 0);
      expect(cartProvider.totalUnits, 0);

      // Add Product A
      await cartProvider.addToCart(productA.id!, productA.merchantId!, productA.canonicalSellingPrice, quantity: 1);
      expect(cartProvider.totalQuantity, 1);
      expect(cartProvider.totalUnits, 1);

      // Increment Product A to 2
      await cartProvider.addToCart(productA.id!, productA.merchantId!, productA.canonicalSellingPrice, quantity: 1);
      expect(cartProvider.totalQuantity, 1); // 1 distinct item line
      expect(cartProvider.totalUnits, 2);    // 2 total units

      // Add Product B
      await cartProvider.addToCart(productB.id!, productB.merchantId!, productB.canonicalSellingPrice, quantity: 1);
      expect(cartProvider.totalQuantity, 2); // 2 distinct item lines
      expect(cartProvider.totalUnits, 3);    // 3 total units

      // Decrement Product A back to 1
      await cartProvider.setToCart(productA.id!, productA.merchantId!, productA.canonicalSellingPrice, 1);
      expect(cartProvider.totalQuantity, 2);
      expect(cartProvider.totalUnits, 2);

      // Remove Product A
      await cartProvider.removeFromCart(productA.id!, productA.merchantId!);
      expect(cartProvider.totalQuantity, 1);
      expect(cartProvider.totalUnits, 1);
    });

    test('6. Strict Merchant Cart Identity: Same productId=100 under Merchant A=10 and Merchant B=20 maintains complete isolation', () async {
      final productA = ProductModel(
        id: 100,
        merchantId: 10,
        title: 'Product 100 (Merchant A)',
        price: 1000.0,
        finalPrice: 1000.0,
      );
      final productB = ProductModel(
        id: 100,
        merchantId: 20,
        title: 'Product 100 (Merchant B)',
        price: 1200.0,
        finalPrice: 1200.0,
      );

      // 1. Initial state: cart is empty
      expect(cartProvider.localCartItems.length, 0);
      expect(cartProvider.getProductQuantity(100, 10), 0);
      expect(cartProvider.getProductQuantity(100, 20), 0);

      // 2. Add product from Merchant A -> exactly 1 cart line: (100, 10) qty 1
      await cartProvider.addToCart(
        productA.id!,
        productA.merchantId!,
        productA.canonicalSellingPrice,
        quantity: 1,
        title: productA.title,
      );
      expect(cartProvider.localCartItems.length, 1);
      expect(cartProvider.findItme(100, 10)?.quantity, 1);
      expect(cartProvider.findItme(100, 20), isNull);
      expect(cartProvider.getSubtotalForMerchant(10), 1000.0);
      expect(cartProvider.getSubtotalForMerchant(20), 0.0);

      // 3. Add same product from Merchant B -> exactly 2 distinct cart lines: (100, 10) and (100, 20)
      await cartProvider.addToCart(
        productB.id!,
        productB.merchantId!,
        productB.canonicalSellingPrice,
        quantity: 1,
        title: productB.title,
      );
      expect(cartProvider.localCartItems.length, 2, reason: 'Must create 2 distinct lines for different merchants');
      expect(cartProvider.findItme(100, 10)?.quantity, 1);
      expect(cartProvider.findItme(100, 20)?.quantity, 1);
      expect(cartProvider.findItme(100, 10)?.singleFinalPrice, 1000.0);
      expect(cartProvider.findItme(100, 20)?.singleFinalPrice, 1200.0);
      expect(cartProvider.getSubtotalForMerchant(10), 1000.0);
      expect(cartProvider.getSubtotalForMerchant(20), 1200.0);
      expect(cartProvider.isMultiMerchant, isTrue);

      // 4. Increment Merchant B to 3 units -> Merchant A remains 1 unit
      await cartProvider.addToCart(
        productB.id!,
        productB.merchantId!,
        productB.canonicalSellingPrice,
        quantity: 2,
        title: productB.title,
      );
      expect(cartProvider.localCartItems.length, 2);
      expect(cartProvider.findItme(100, 10)?.quantity, 1, reason: 'Merchant A must not be modified when Merchant B increments');
      expect(cartProvider.findItme(100, 20)?.quantity, 3);
      expect(cartProvider.getSubtotalForMerchant(10), 1000.0);
      expect(cartProvider.getSubtotalForMerchant(20), 3600.0);

      // 5. Decrement Merchant B to 2 units -> Merchant A remains 1 unit
      await cartProvider.setToCart(
        productB.id!,
        productB.merchantId!,
        productB.canonicalSellingPrice,
        2,
        title: productB.title,
      );
      expect(cartProvider.localCartItems.length, 2);
      expect(cartProvider.findItme(100, 10)?.quantity, 1, reason: 'Merchant A must not be modified when Merchant B decrements');
      expect(cartProvider.findItme(100, 20)?.quantity, 2);
      expect(cartProvider.getSubtotalForMerchant(10), 1000.0);
      expect(cartProvider.getSubtotalForMerchant(20), 2400.0);

      // 6. Remove Merchant B completely -> Merchant A remains intact with 1 unit
      await cartProvider.removeFromCart(100, 20);
      expect(cartProvider.localCartItems.length, 1);
      expect(cartProvider.findItme(100, 10)?.quantity, 1, reason: 'Merchant A must remain untouched when Merchant B is removed');
      expect(cartProvider.findItme(100, 20), isNull);
      expect(cartProvider.getSubtotalForMerchant(10), 1000.0);
      expect(cartProvider.getSubtotalForMerchant(20), 0.0);
    });

    test('7. Independent state between multiple different products (Product A does not alter Product B)', () async {
      final productA = ProductModel(id: 501, merchantId: 10, title: 'Coffee', price: 5000.0, finalPrice: 5000.0);
      final productB = ProductModel(id: 502, merchantId: 10, title: 'Tea', price: 3000.0, finalPrice: 3000.0);

      // Add Product A
      await cartProvider.addToCart(productA.id!, productA.merchantId!, productA.canonicalSellingPrice, quantity: 1);
      expect(cartProvider.findItme(productA.id!, productA.merchantId!)?.quantity, 1);
      expect(cartProvider.findItme(productB.id!, productB.merchantId!), isNull);

      // Add Product B
      await cartProvider.addToCart(productB.id!, productB.merchantId!, productB.canonicalSellingPrice, quantity: 3);
      expect(cartProvider.findItme(productA.id!, productA.merchantId!)?.quantity, 1);
      expect(cartProvider.findItme(productB.id!, productB.merchantId!)?.quantity, 3);

      // Decrement Product B
      await cartProvider.setToCart(productB.id!, productB.merchantId!, productB.canonicalSellingPrice, 2);
      expect(cartProvider.findItme(productA.id!, productA.merchantId!)?.quantity, 1, reason: 'Product A must remain unchanged');
      expect(cartProvider.findItme(productB.id!, productB.merchantId!)?.quantity, 2);

      // Remove Product B
      await cartProvider.removeFromCart(productB.id!, productB.merchantId!);
      expect(cartProvider.findItme(productA.id!, productA.merchantId!)?.quantity, 1, reason: 'Product A must remain unaffected after Product B removal');
      expect(cartProvider.findItme(productB.id!, productB.merchantId!), isNull);
    });

    test('8. USD-priced items added maintain canonical converted SYP price after quantity changes', () async {
      // 0.60 USD @ 15,000 rate -> 9,000 SYP
      final productUsd = ProductModel(
        id: 7269,
        merchantId: 10,
        title: 'Oral-B Toothbrush',
        price: 0.60,
        finalPrice: 0.60,
        priceUsd: 0.60,
      );

      expect(productUsd.canonicalSellingPrice, equals(9000.0));

      // Add 1 unit
      await cartProvider.addToCart(
        productUsd.id!,
        productUsd.merchantId!,
        productUsd.canonicalSellingPrice,
        quantity: 1,
        title: productUsd.title,
      );

      var item = cartProvider.findItme(productUsd.id!, productUsd.merchantId!);
      expect(item, isNotNull);
      expect(item!.singleFinalPrice, equals(9000.0));
      expect(item.quantity, equals(1));
      expect(cartProvider.subtotal, equals(9000.0));

      // Increment to 3 units
      await cartProvider.addToCart(
        productUsd.id!,
        productUsd.merchantId!,
        productUsd.canonicalSellingPrice,
        quantity: 2,
        title: productUsd.title,
      );

      item = cartProvider.findItme(productUsd.id!, productUsd.merchantId!);
      expect(item, isNotNull);
      expect(item!.singleFinalPrice, equals(9000.0));
      expect(item.quantity, equals(3));
      // Total = 3 * 9,000 = 27,000 SYP
      expect(cartProvider.subtotal, equals(27000.0));

      // Decrement to 2 units
      await cartProvider.setToCart(
        productUsd.id!,
        productUsd.merchantId!,
        productUsd.canonicalSellingPrice,
        2,
        title: productUsd.title,
      );

      item = cartProvider.findItme(productUsd.id!, productUsd.merchantId!);
      expect(item, isNotNull);
      expect(item!.singleFinalPrice, equals(9000.0));
      expect(item.quantity, equals(2));
      // Total = 2 * 9,000 = 18,000 SYP
      expect(cartProvider.subtotal, equals(18000.0));
    });

    test('9. Genuine SYP product (250 SYP) maintains 250 SYP price without heuristic corruption', () async {
      final bread = ProductModel(
        id: 5702,
        merchantId: 10,
        title: 'Khobz (Bread)',
        price: 250.0,
        finalPrice: 250.0,
      );

      expect(bread.canonicalSellingPrice, equals(250.0));

      await cartProvider.addToCart(
        bread.id!,
        bread.merchantId!,
        bread.canonicalSellingPrice,
        quantity: 4,
        title: bread.title,
      );

      final item = cartProvider.findItme(bread.id!, bread.merchantId!);
      expect(item, isNotNull);
      expect(item!.singleFinalPrice, equals(250.0));
      expect(item.quantity, equals(4));
      // Subtotal = 4 * 250 = 1000 SYP
      expect(cartProvider.subtotal, equals(1000.0));
    });

    test('10. Dynamic Exchange Rate Runtime Source: Rate=16,000 dynamically converts PriceUsd=4.33 to 69,280 SYP', () async {
      final marketsProv = locator<MarketsProvider>();
      final originalRate = marketsProv.exchangeRate;

      try {
        // Energizer battery: PriceUsd = 4.33
        final productUsd = ProductModel(
          id: 7390,
          merchantId: 10,
          title: 'Energizer Max Plus AA',
          price: 4.33,
          finalPrice: 4.33,
          priceUsd: 4.33,
        );

        // At default/baseline rate 15,000: 4.33 * 15,000 = 64,950 SYP
        marketsProv.exchangeRate = 15000.0;
        expect(productUsd.canonicalSellingPrice, equals(64950.0));

        // When admin updates exchange rate to 16,000: 4.33 * 16,000 = 69,280 SYP
        marketsProv.exchangeRate = 16000.0;
        expect(productUsd.canonicalSellingPrice, equals(69280.0));
        expect(productUsd.canonicalSellingPriceWithRate(16000.0), equals(69280.0));

        // Adding to cart uses dynamic live rate
        await cartProvider.addToCart(
          productUsd.id!,
          productUsd.merchantId!,
          productUsd.canonicalSellingPrice,
          quantity: 1,
          title: productUsd.title,
        );

        final item = cartProvider.findItme(productUsd.id!, productUsd.merchantId!);
        expect(item, isNotNull);
        expect(item!.singleFinalPrice, equals(69280.0));
        expect(cartProvider.subtotal, equals(69280.0));
      } finally {
        marketsProv.exchangeRate = originalRate;
      }
    });
  });

  group('Manual-QA Bug #46: AddToCartButton Stepper Widget UI Verification', () {
    testWidgets('First tap adds 1 unit and reveals quantity stepper [-] 1 [+]; tap + increments to 2; tap - decrements to 1; tap - removes cleanly', (tester) async {
      final product = ProductModel(
        id: 9901,
        merchantId: 10,
        title: 'Fresh Milk',
        price: 12000.0,
        finalPrice: 12000.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<CartProvider>.value(
            value: cartProvider,
            child: Scaffold(
              body: Center(
                child: AddToCartButton.circular(product),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Initially, not in cart: should show initial add button, NO stepper, and NO 'X' icon
      expect(find.byKey(const ValueKey('initial_add_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('quantity_stepper')), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);

      // Tap '+' to add to cart
      await tester.tap(find.byKey(const ValueKey('circular_add_tap_target')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Now item is in cart with quantity = 1:
      // Stepper MUST be displayed with [-] 1 [+]
      expect(find.byKey(const ValueKey('quantity_stepper')), findsOneWidget);
      expect(find.byKey(const ValueKey('stepper_decrement_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('stepper_increment_btn')), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      // Ensure NO 'X' icon is shown!
      expect(find.byIcon(Icons.close), findsNothing);

      // Verify CartProvider has 1 item with quantity 1
      expect(cartProvider.findItme(product.id!, product.merchantId!)?.quantity, 1);

      // Tap '+' on the stepper to increment
      await tester.tap(find.byKey(const ValueKey('stepper_increment_btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Stepper should now show quantity '2'
      expect(find.text('2'), findsOneWidget);
      expect(cartProvider.findItme(product.id!, product.merchantId!)?.quantity, 2);
      expect(cartProvider.localCartItems.length, 1, reason: 'Increment must not create duplicate cart line');

      // Tap '-' on the stepper to decrement
      await tester.tap(find.byKey(const ValueKey('stepper_decrement_btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Stepper should now show quantity '1'
      expect(find.text('1'), findsOneWidget);
      expect(cartProvider.findItme(product.id!, product.merchantId!)?.quantity, 1);

      // Tap '-' again when quantity is 1 -> item cleanly removed
      await tester.tap(find.byKey(const ValueKey('stepper_decrement_btn')));
      await tester.pumpAndSettle();

      // Stepper disappears, initial add button restored
      expect(find.byKey(const ValueKey('quantity_stepper')), findsNothing);
      expect(find.byKey(const ValueKey('initial_add_btn')), findsOneWidget);
      expect(cartProvider.findItme(product.id!, product.merchantId!), isNull);
      expect(cartProvider.localCartItems.length, 0);
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('Independent widget state: Product A and Product B steppers are completely isolated', (tester) async {
      final productA = ProductModel(
        id: 9902,
        merchantId: 10,
        title: 'Juice Orange',
        price: 8000.0,
        finalPrice: 8000.0,
      );

      final productB = ProductModel(
        id: 9903,
        merchantId: 10,
        title: 'Juice Apple',
        price: 8500.0,
        finalPrice: 8500.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<CartProvider>.value(
            value: cartProvider,
            child: Scaffold(
              body: Column(
                children: [
                  AddToCartButton.circular(productA, key: const ValueKey('btn_A')),
                  AddToCartButton.circular(productB, key: const ValueKey('btn_B')),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Both start as initial add buttons
      expect(find.byKey(const ValueKey('quantity_stepper')), findsNothing);

      // Tap Product A add button
      final btnAFinder = find.descendant(
        of: find.byKey(const ValueKey('btn_A')),
        matching: find.byKey(const ValueKey('circular_add_tap_target')),
      );
      await tester.tap(btnAFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Product A is stepper with 1; Product B remains initial add button
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('btn_A')),
          matching: find.byKey(const ValueKey('quantity_stepper')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('btn_B')),
          matching: find.byKey(const ValueKey('quantity_stepper')),
        ),
        findsNothing,
      );

      // Tap Product B add button
      final btnBFinder = find.descendant(
        of: find.byKey(const ValueKey('btn_B')),
        matching: find.byKey(const ValueKey('circular_add_tap_target')),
      );
      await tester.tap(btnBFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Both are steppers with quantity 1
      expect(cartProvider.findItme(productA.id!, productA.merchantId!)?.quantity, 1);
      expect(cartProvider.findItme(productB.id!, productB.merchantId!)?.quantity, 1);

      // Increment Product A to 2
      final btnAInc = find.descendant(
        of: find.byKey(const ValueKey('btn_A')),
        matching: find.byKey(const ValueKey('stepper_increment_btn')),
      );
      await tester.tap(btnAInc);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(cartProvider.findItme(productA.id!, productA.merchantId!)?.quantity, 2);
      expect(cartProvider.findItme(productB.id!, productB.merchantId!)?.quantity, 1);
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('Multi-merchant UI isolation: Same productId=100 under Merchant A=10 and Merchant B=20 has strictly independent steppers', (tester) async {
      final productA = ProductModel(
        id: 100,
        merchantId: 10,
        title: 'Product 100 (Merchant 10)',
        price: 1000.0,
        finalPrice: 1000.0,
      );

      final productB = ProductModel(
        id: 100,
        merchantId: 20,
        title: 'Product 100 (Merchant 20)',
        price: 1200.0,
        finalPrice: 1200.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<CartProvider>.value(
            value: cartProvider,
            child: Scaffold(
              body: Column(
                children: [
                  AddToCartButton.circular(productA, key: const ValueKey('btn_m10')),
                  AddToCartButton.circular(productB, key: const ValueKey('btn_m20')),
                ],
              ),
            ),
          ),
        ),
      );

      // Pre-seed cart with Product A (Merchant 10) with qty = 2
      await cartProvider.addToCart(
        productA.id!,
        productA.merchantId!,
        productA.canonicalSellingPrice,
        quantity: 2,
        title: productA.title,
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Product A (Merchant 10) has stepper with '2'
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('btn_m10')),
          matching: find.byKey(const ValueKey('quantity_stepper')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('btn_m10')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );

      // Product B (Merchant 20) with same productId MUST NOT match Merchant 10's item!
      // It MUST show the initial '+' button, and NOT a stepper!
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('btn_m20')),
          matching: find.byKey(const ValueKey('initial_add_btn')),
        ),
        findsOneWidget,
        reason: 'Merchant B must show initial add button even when same productId is in cart for Merchant A',
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('btn_m20')),
          matching: find.byKey(const ValueKey('quantity_stepper')),
        ),
        findsNothing,
      );

      // Increment Product A via stepper
      final btnM10Inc = find.descendant(
        of: find.byKey(const ValueKey('btn_m10')),
        matching: find.byKey(const ValueKey('stepper_increment_btn')),
      );
      await tester.tap(btnM10Inc);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(cartProvider.findItme(100, 10)?.quantity, 3);
      expect(cartProvider.findItme(100, 20), isNull);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('btn_m10')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('btn_m20')),
          matching: find.byKey(const ValueKey('initial_add_btn')),
        ),
        findsOneWidget,
      );

      // Now add Product B (Merchant 20) with qty = 1 directly to cart
      await cartProvider.addToCart(
        productB.id!,
        productB.merchantId!,
        productB.canonicalSellingPrice,
        quantity: 1,
        title: productB.title,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Now both show their respective independent steppers
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('btn_m10')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('btn_m20')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );

      // Decrement Product B (Merchant 20) to 0 via stepper -> removes it
      final btnM20Dec = find.descendant(
        of: find.byKey(const ValueKey('btn_m20')),
        matching: find.byKey(const ValueKey('stepper_decrement_btn')),
      );
      await tester.tap(btnM20Dec);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(cartProvider.findItme(100, 20), isNull);
      expect(cartProvider.findItme(100, 10)?.quantity, 3);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('btn_m20')),
          matching: find.byKey(const ValueKey('initial_add_btn')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('btn_m10')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 600));
    });
  });
}
