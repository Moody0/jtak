import 'package:app_jtak_warehouse/src/core/controllers/products_provider.dart';
import 'package:app_jtak_warehouse/src/core/services/locator.dart';
import 'package:app_jtak_warehouse/src/utils/providers/sol_api.dart';
import 'package:flutter_test/flutter_test.dart';

class MockSolApiWithData extends Fake implements SolApi {
  final List<Map<String, dynamic>> categoriesData;
  final List<Map<String, dynamic>> productsData;

  MockSolApiWithData({
    required this.categoriesData,
    required this.productsData,
  });

  @override
  Future getRequest(String subUrl,
      {Map<String, String>? headers, String? apiPrefex}) async {
    if (subUrl == '/Products/Categories') {
      return categoriesData;
    }
    if (subUrl == '/Products') {
      return productsData;
    }
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'ProductsProvider categories only contain categories that the restaurant has products in',
      () async {
    // Simulated system categories with unrelated grocery categories (honey, coffee, dairy, etc.)
    final systemCategories = [
      {'id': 1, 'title': 'عسل', 'order': 1},
      {'id': 2, 'title': 'قهوة', 'order': 2},
      {'id': 3, 'title': 'موالح', 'order': 3},
      {'id': 4, 'title': 'ألبان وأجبان', 'order': 4},
      {'id': 10, 'title': 'وجبات', 'order': 5},
    ];

    // Simulated restaurant products ("محطة اللحوم" with burgers and meals)
    final restaurantProducts = [
      {
        'productId': 101,
        'product': 'برجر لحم ودجاج',
        'productCat1': 'برجر لحم ودجاج',
        'productCategoryId': null,
        'merchantPrice': 450,
        'productActive': true,
      },
      {
        'productId': 102,
        'product': 'وجبة كرسبي',
        'productCat1': 'وجبات',
        'productCategoryId': 10,
        'merchantPrice': 550,
        'productActive': true,
      },
      {
        'productId': 103,
        'product': 'وجبة شيش طاووق',
        'productCat1': 'وجبات',
        'productCategoryId': 10,
        'merchantPrice': 450,
        'productActive': true,
      },
    ];

    final mockApi = MockSolApiWithData(
      categoriesData: systemCategories,
      productsData: restaurantProducts,
    );

    if (locator.isRegistered<SolApi>()) {
      locator.unregister<SolApi>();
    }
    locator.registerSingleton<SolApi>(mockApi);

    final provider = ProductsProvider();
    await provider.loadData();

    // 1. Categories should ONLY contain categories the restaurant actually has products in
    final categoryTitles = provider.categories.map((c) => c.title).toList();
    expect(categoryTitles, contains('وجبات'));
    expect(categoryTitles, contains('برجر لحم ودجاج'));

    // Unrelated grocery categories must NOT appear in the restaurant categories
    expect(categoryTitles, isNot(contains('عسل')));
    expect(categoryTitles, isNot(contains('قهوة')));
    expect(categoryTitles, isNot(contains('موالح')));
    expect(categoryTitles, isNot(contains('ألبان وأجبان')));

    // 2. Count for categories
    expect(provider.countForCategory(null), 3); // "الكل" has 3 products
    final mealCat = provider.categories.firstWhere((c) => c.title == 'وجبات');
    expect(provider.countForCategory(mealCat.id), 2);
    final burgerCat =
        provider.categories.firstWhere((c) => c.title == 'برجر لحم ودجاج');
    expect(provider.countForCategory(burgerCat.id), 1);

    // 3. Filtering by category
    provider.setSelectedCategory(mealCat.id);
    expect(provider.productList.length, 2);
    expect(provider.productList.every((p) => p.productCat1 == 'وجبات'), isTrue);

    provider.setSelectedCategory(burgerCat.id);
    expect(provider.productList.length, 1);
    expect(provider.productList.first.product, 'برجر لحم ودجاج');

    // 4. Reset category to "All"
    provider.setSelectedCategory(null);
    expect(provider.productList.length, 3);

    // 5. Selection categories for product creation should only include this restaurant's categories
    final selectionTitles =
        provider.categoriesForSelection.map((c) => c.title).toList();
    expect(selectionTitles, contains('وجبات'));
    expect(selectionTitles, isNot(contains('عسل')));
  });
}
