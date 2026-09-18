import 'package:flutter_test/flutter_test.dart';
import 'package:jtek_app/src/core/controllers/catalog/categories_provider.dart';
import 'package:jtek_app/src/core/models/catalog/category_model.dart';
import 'package:jtek_app/src/core/models/catalog/home_category_tile.dart';
import 'package:jtek_app/src/utils/utilities/global_var.dart';

import 'package:jtek_app/src/core/services/locator.dart';
import 'package:jtek_app/src/utils/providers/sol_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    if (!locator.isRegistered<SolApi>()) {
      locator.registerLazySingleton<SolApi>(() => SolApi());
    }
  });

  group('BUG A & B — Image URL versioned cache invalidation', () {
    test('getImageUrl appends version token to image URL for instant invalidation', () {
      final token = '2026_9_18_abc123.jpg';
      final url = GlobalVar.getImageUrl(token);
      expect(url, contains('?w=300&h=200&crop=true&v=2026_9_18_abc123.jpg'));
    });

    test('getImageUrl handles webp with direct download URL and version parameter', () {
      final token = '2026_9_18_abc123.webp';
      final url = GlobalVar.getImageUrl(token);
      expect(url, contains('/Download/2026_9_18_abc123.webp?v=2026_9_18_abc123.webp'));
    });

    test('getDownloadUrl appends version token', () {
      final token = '2026_9_18_cat_icon.jpg';
      final url = GlobalVar.getDownloadUrl(token);
      expect(url, contains('/Download/2026_9_18_cat_icon.jpg?v=2026_9_18_cat_icon.jpg'));
    });
  });

  group('BUG C — Home category section settings synchronization', () {
    test('Home sections fallback returns canonical 4 services when no custom tiles set', () {
      final provider = CategoriesProvider();
      expect(provider.homeSections.length, 4);
      expect(provider.homeSections[0].title, 'البقالة');
      expect(provider.homeSections[1].title, 'المطاعم');
      expect(provider.homeSections[2].title, 'قهوة ومشروبات');
      expect(provider.homeSections[3].title, 'صيدليات');
    });

    test('setHomeCategoryTiles respects enabled=false flag and hides section', () {
      final provider = CategoriesProvider();
      final tiles = [
        const HomeCategoryTile(
          id: 'tile-1',
          title: 'حلويات',
          linkType: HomeCategoryLinkType.productCategory,
          productCategoryId: 15,
          order: 1,
        ),
      ];

      provider.setHomeCategoryTiles(tiles, enabled: false, maxItems: 8);
      expect(provider.homeCategoriesEnabled, isFalse);
    });

    test('setHomeCategoryTiles slices tiles by maxItems when configured', () {
      final provider = CategoriesProvider();
      final tiles = List.generate(
        10,
        (i) => HomeCategoryTile(
          id: 'tile-$i',
          title: 'فئة $i',
          linkType: HomeCategoryLinkType.productCategory,
          productCategoryId: 100 + i,
          order: i,
        ),
      );

      provider.setHomeCategoryTiles(tiles, enabled: true, maxItems: 4);
      expect(provider.homeCategoriesEnabled, isTrue);
      expect(provider.homeCategoriesMaxItems, 4);
      expect(provider.homeCategoryTiles.length, 4);
      expect(provider.homeCategoryTiles.first.title, 'فئة 0');
      expect(provider.homeCategoryTiles.last.title, 'فئة 3');
    });

    test('setHomeCategoryTiles preserves all tiles when maxItems=0 (unlimited)', () {
      final provider = CategoriesProvider();
      final tiles = List.generate(
        6,
        (i) => HomeCategoryTile(
          id: 'tile-$i',
          title: 'فئة $i',
          linkType: HomeCategoryLinkType.productCategory,
          productCategoryId: 200 + i,
          order: i,
        ),
      );

      provider.setHomeCategoryTiles(tiles, enabled: true, maxItems: 0);
      expect(provider.homeCategoriesEnabled, isTrue);
      expect(provider.homeCategoryTiles.length, 6);
    });
  });
}
