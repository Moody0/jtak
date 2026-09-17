import 'package:flutter_test/flutter_test.dart';
import 'package:jtek_app/src/core/controllers/catalog/markets_provider.dart';
import 'package:jtek_app/src/ui/widgets/big_stores_section.dart';

void main() {
  group('Canonical Merchant Image Resolution & Invalidation', () {
    test('MarketStoreModel parses live uploaded image token to full image URL', () {
      final json = {
        'id': 12,
        'title': 'جيتك ماركت - JTAK Market',
        'shortDescription': 'سوبرماركت • 15-20 دقيقة',
        'photo': '2026_9_17_4917a0b38c244c9b9cb12818a7c50.jpg',
        'active': true,
        'merchantKind': 1,
      };

      final model = MarketStoreModel.fromJson(json);

      expect(model.id, equals(12));
      expect(model.logoUrl, isNotNull);
      expect(model.logoUrl!.contains('2026_9_17_4917a0b38c244c9b9cb12818a7c50.jpg'), isTrue);
      expect(model.logoUrl!.startsWith('https://api.jtak.app'), isTrue);
      // assetPath must NOT override the live photo
      expect(model.assetPath, isNull);
    });

    test('Updating merchant photo produces a new deterministic URL and invalidates stale cache key', () {
      final jsonV1 = {
        'id': 12,
        'title': 'جيتك ماركت',
        'photo': '2026_9_17_v1_image.jpg',
      };
      final jsonV2 = {
        'id': 12,
        'title': 'جيتك ماركت',
        'photo': '2026_9_17_v2_new_upload.jpg',
      };

      final modelV1 = MarketStoreModel.fromJson(jsonV1);
      final modelV2 = MarketStoreModel.fromJson(jsonV2);

      expect(modelV1.logoUrl, isNot(equals(modelV2.logoUrl)));
      expect(modelV2.logoUrl!.contains('2026_9_17_v2_new_upload.jpg'), isTrue);
    });

    test('RestaurantStoreModel prioritizes live photo over hardcoded name matching', () {
      final json = {
        'id': 8,
        'title': 'شاورما أنس الدمشقية',
        'photo': '2026_9_17_anas_custom_cover.jpg,2026_9_17_anas_custom_logo.jpg',
        'active': true,
        'merchantKind': 0,
      };

      final model = RestaurantStoreModel.fromJson(json);

      expect(model.coverUrl.contains('2026_9_17_anas_custom_cover.jpg'), isTrue);
      expect(model.logoUrl.contains('2026_9_17_anas_custom_logo.jpg'), isTrue);
      expect(model.coverUrl.startsWith('https://api.jtak.app'), isTrue);
      expect(model.logoUrl.startsWith('https://api.jtak.app'), isTrue);
    });

    test('RestaurantStoreModel single photo populates both cover and logo URLs', () {
      final json = {
        'id': 6,
        'title': 'مشاوي وكباب بوابة دمشق',
        'photo': '2026_9_17_damascus_single.jpg',
        'active': true,
        'merchantKind': 0,
      };

      final model = RestaurantStoreModel.fromJson(json);

      expect(model.coverUrl.contains('2026_9_17_damascus_single.jpg'), isTrue);
      expect(model.logoUrl.contains('2026_9_17_damascus_single.jpg'), isTrue);
    });

    test('BigStoreData converts MarketStoreModel and preserves canonical logoUrl', () {
      final market = MarketStoreModel.fromJson({
        'id': 12,
        'title': 'جيتك ماركت',
        'photo': '2026_9_17_flagship_market.jpg',
        'shortDescription': 'توصيل فوري • 15 دقيقة',
      });

      final bigStore = BigStoreData.fromModel(market);

      expect(bigStore.id, equals(12));
      expect(bigStore.logoUrl, isNotNull);
      expect(bigStore.logoUrl!.contains('2026_9_17_flagship_market.jpg'), isTrue);
    });

    test('toRestaurantData on MarketStoreModel propagates canonical network logoUrl', () {
      final market = MarketStoreModel.fromJson({
        'id': 12,
        'title': 'جيتك ماركت',
        'photo': '2026_9_17_flagship_market.jpg',
        'shortDescription': 'توصيل فوري • 15 دقيقة',
      });

      final restData = market.toRestaurantData();

      expect(restData.id, equals(12));
      expect(restData.coverUrl.contains('2026_9_17_flagship_market.jpg'), isTrue);
      expect(restData.logoUrl.contains('2026_9_17_flagship_market.jpg'), isTrue);
    });
  });
}
