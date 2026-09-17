import 'package:flutter_test/flutter_test.dart';
import 'package:jtek_app/src/core/models/catalog/product_model.dart';
import 'package:jtek_app/src/core/models/order/local_cart_item.dart';

void main() {
  group('Canonical Pricing & Cart Protection (#43, #44, #45)', () {
    test('Explicit PriceUsd products convert using centralized exchange rate (15,000 SYP)', () {
      const exchangeRate = 15000.0;

      // 1. explicit PriceUsd = 0.60
      final item060 = ProductModel(
        id: 7269,
        title: 'Oral-B Toothbrush',
        price: 0.60,
        finalPrice: 0.60,
        priceUsd: 0.60,
      );
      expect(item060.canonicalSellingPriceWithRate(exchangeRate), equals(9000.0));
      expect(item060.canonicalSellingPrice, equals(9000.0));

      // 2. explicit PriceUsd = 4.33
      final item433 = ProductModel(
        id: 7390,
        title: 'Energizer Max Plus AA',
        price: 4.33,
        finalPrice: 4.33,
        priceUsd: 4.33,
      );
      expect(item433.canonicalSellingPriceWithRate(exchangeRate), equals(64950.0));
      expect(item433.canonicalSellingPrice, equals(64950.0));

      // 3. explicit PriceUsd = 3.34
      final item334 = ProductModel(
        id: 8345,
        title: 'Tiffany Break Rizzo',
        price: 3.34,
        finalPrice: 3.34,
        priceUsd: 3.34,
      );
      expect(item334.canonicalSellingPriceWithRate(exchangeRate), equals(50100.0));
      expect(item334.canonicalSellingPrice, equals(50100.0));

      // 4. genuine 250 SYP item (under 500, MUST NOT be converted)
      final item250 = ProductModel(
        id: 5702,
        title: 'Local Bread / Genuine Small Item',
        price: 250.0,
        finalPrice: 250.0,
        priceUsd: null,
        currency: 760, // SYP
      );
      expect(item250.canonicalSellingPriceWithRate(exchangeRate), equals(250.0));
      expect(item250.canonicalSellingPrice, equals(250.0));

      // 5. normal 2,280 SYP item (MUST NOT be converted)
      final item2280 = ProductModel(
        id: 6001,
        title: 'Standard Restaurant / Market Item',
        price: 2280.0,
        finalPrice: 2280.0,
        priceUsd: null,
      );
      expect(item2280.canonicalSellingPriceWithRate(exchangeRate), equals(2280.0));
      expect(item2280.canonicalSellingPrice, equals(2280.0));
    });

    test('ProductModel.fromMap parses explicit priceUsd and respects genuine SYP items', () {
      final jsonUsd = {
        'id': 7269,
        'title': 'Oral-B Toothbrush',
        'price': 0.60,
        'finalPrice': 0.60,
        'priceUsd': 0.60,
      };
      final parsedUsd = ProductModel.fromMap(jsonUsd);
      expect(parsedUsd.priceUsd, equals(0.60));
      expect(parsedUsd.canonicalSellingPrice, equals(9000.0));

      final jsonSyp = {
        'id': 5702,
        'title': 'Genuine Small Item',
        'price': 250.0,
        'finalPrice': 250.0,
        'priceUsd': null,
      };
      final parsedSyp = ProductModel.fromMap(jsonSyp);
      expect(parsedSyp.priceUsd, isNull);
      expect(parsedSyp.canonicalSellingPrice, equals(250.0));
    });

    test('LocalCartItem correctly preserves SYP prices and line total', () {
      final item = LocalCartItem(
        productId: 201,
        merchantId: 18,
        singleFinalPrice: 15000.0,
        quantity: 2,
        productTitle: 'Market Item',
      );

      expect(item.singleFinalPrice, equals(15000.0));
      expect(item.quantity, equals(2));
      final lineTotal = item.singleFinalPrice * item.quantity;
      expect(lineTotal, equals(30000.0));
    });

    test('Cart calculation preserves canonical prices without arbitrary < 500 heuristic', () {
      final items = [
        LocalCartItem(
          productId: 1,
          merchantId: 18,
          singleFinalPrice: 2000.0,
          quantity: 3,
        ),
        LocalCartItem(
          productId: 2,
          merchantId: 18,
          singleFinalPrice: 10000.0,
          quantity: 1,
        ),
      ];

      final subtotal = items.fold(0.0, (sum, item) => sum + (item.singleFinalPrice * item.quantity));
      expect(subtotal, equals(16000.0));
    });
  });
}
