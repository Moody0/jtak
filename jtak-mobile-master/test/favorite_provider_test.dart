import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jtek_app/src/core/controllers/catalog/favorite_product_provider.dart';
import 'package:jtek_app/src/core/services/locator.dart';
import 'package:jtek_app/src/utils/providers/sol_api.dart';
import 'package:jtek_app/src/core/services/authentication_service.dart';
import 'package:jtek_app/src/core/controllers/app/home_navigation_provider.dart';
import 'package:jtek_app/src/ui/widgets/catalog/meal_card_widget.dart';
import 'package:jtek_app/src/ui/widgets/catalog/restaurant_card_widget.dart';
import 'package:jtek_app/src/ui/pages/catalog/market_page.dart';
import 'package:jtek_app/src/ui/pages/catalog/favorite_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    if (!locator.isRegistered<SolApi>()) {
      locator.registerLazySingleton<SolApi>(() => SolApi());
    }
    if (!locator.isRegistered<AuthenticationService>()) {
      locator.registerLazySingleton<AuthenticationService>(() => AuthenticationService());
    }
  });

  test('Adding non-mock items gets added to favoriteMeals and totalFavoritesCount', () async {
    final provider = FavoriteProductProvider();
    expect(provider.favoriteMeals.length, 0);
    expect(provider.totalFavoritesCount, 0);

    // 1. Add a MealItemData with a custom non-mock ID (e.g. 8888)
    const meal = MealItemData(
      id: 8888,
      title: 'سندويش كباب حلبي خاص',
      price: '45,000 ل.س',
      coverUrl: 'https://example.com/cover.webp',
      merchantLogoUrl: '',
      merchantName: 'مطعم حلب الشهباء',
      eta: '20-30 دقيقة',
      distance: '3.0 كم',
      numericPrice: 45000.0,
    );

    provider.toggleMealFavorite(meal.id, meal);

    expect(provider.isMealFavorite(8888), isTrue);
    expect(provider.favoriteMeals.length, 1);
    expect(provider.favoriteMeals.first.id, 8888);
    expect(provider.favoriteMeals.first.title, 'سندويش كباب حلبي خاص');
    expect(provider.favoriteMeals.first.restaurantName, 'مطعم حلب الشهباء');
    expect(provider.totalFavoritesCount, 1);

    // 2. Add a MarketProductItem with non-mock ID (e.g. 9999)
    const marketProduct = MarketProductItem(
      id: 9999,
      title: 'شاي سيلاني فاخر 500غ',
      price: '35,000 ل.س',
      priceValue: 35000,
      imageUrl: 'https://example.com/tea.webp',
      category: 'مشروبات ساخنة',
    );

    provider.toggleMealFavorite(marketProduct.id, marketProduct);

    expect(provider.isMealFavorite(9999), isTrue);
    expect(provider.favoriteMeals.length, 2);
    expect(provider.totalFavoritesCount, 2);

    // 3. Add a non-mock restaurant (e.g. 7777)
    const rest = RestaurantItemData(
      id: 7777,
      name: 'شاورما على كيفك',
      coverUrl: 'https://example.com/shawarma.webp',
      logoUrl: '',
      category: 'شاورما ومشاوي',
      rating: 4.9,
      ratingCount: 150,
      eta: '15-25 دقيقة',
      distance: '1.5 كم',
      deliveryFee: '5,000 ل.س',
      isVerified: true,
      isOpen: true,
    );

    provider.toggleRestaurantFavorite(rest.id, rest);

    expect(provider.isRestaurantFavorite(7777), isTrue);
    expect(provider.favoriteRestaurants.length, 1);
    expect(provider.favoriteRestaurants.first.name, 'شاورما على كيفك');
    expect(provider.totalFavoritesCount, 3);

    // 4. Toggle off meal 8888
    provider.toggleMealFavorite(8888);
    expect(provider.isMealFavorite(8888), isFalse);
    expect(provider.favoriteMeals.length, 1);
    expect(provider.totalFavoritesCount, 2);

    // 5. Toggle off restaurant 7777
    provider.toggleRestaurantFavorite(7777);
    expect(provider.isRestaurantFavorite(7777), isFalse);
    expect(provider.favoriteRestaurants.length, 0);
    expect(provider.totalFavoritesCount, 1);
  });

  testWidgets('FavoritePage renders tabs labeled المطاعم and الأصناف', (tester) async {
    final provider = FavoriteProductProvider();
    final navProvider = HomeNavigationProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<FavoriteProductProvider>.value(value: provider),
          ChangeNotifierProvider<HomeNavigationProvider>.value(value: navProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: FavoritePage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('المطاعم'), findsOneWidget);
    expect(find.textContaining('الأصناف'), findsOneWidget);
    expect(find.textContaining('الأطباق'), findsNothing);
  });
}
