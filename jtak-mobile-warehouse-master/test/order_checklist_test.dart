import 'package:app_jtak_warehouse/src/core/controllers/order_provider.dart';
import 'package:app_jtak_warehouse/src/core/models/order_details_model.dart';
import 'package:app_jtak_warehouse/src/core/models/order_model.dart';
import 'package:app_jtak_warehouse/src/core/services/locator.dart';
import 'package:app_jtak_warehouse/src/utils/providers/sol_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSolApi extends Fake implements SolApi {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    if (!locator.isRegistered<SolApi>()) {
      locator.registerSingleton<SolApi>(FakeSolApi());
    }
  });

  tearDown(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  test('toggleItemChecklist toggles picked state and does not double-toggle', () async {
    final provider = OrderProvider();
    final item1 = OrderDetailsModel(id: 101, productTitle: 'Item 1', isPicked: false);
    final item2 = OrderDetailsModel(id: 102, productTitle: 'Item 2', isPicked: false);
    final order = OrderModel(id: 50, orderDetails: [item1, item2]);

    provider.dataList = [order];
    provider.order = order; // Same reference test to prevent double toggle regression

    expect(item1.isPicked, false);
    expect(provider.isItemPicked(50, 101), false);

    // First toggle -> picked
    provider.toggleItemChecklist(50, 101);
    expect(item1.isPicked, true);
    expect(provider.isItemPicked(50, 101), true);

    // Second toggle -> unpicked
    provider.toggleItemChecklist(50, 101);
    expect(item1.isPicked, false);
    expect(provider.isItemPicked(50, 101), false);
  });

  test('checklist persists to SharedPreferences and restores across instances', () async {
    final provider1 = OrderProvider();
    final item1 = OrderDetailsModel(id: 201, productTitle: 'Item 1', isPicked: false);
    final order1 = OrderModel(id: 60, orderDetails: [item1]);
    provider1.dataList = [order1];

    provider1.toggleItemChecklist(60, 201);
    expect(item1.isPicked, true);

    // Allow async SharedPreferences to write
    await Future.delayed(const Duration(milliseconds: 50));

    // Verify written to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('merchant_picked_items_60');
    expect(saved, isNotNull);
    expect(saved, contains('201'));

    // Create a new provider instance simulating app restart or page refresh
    final provider2 = OrderProvider();
    await Future.delayed(const Duration(milliseconds: 50));

    expect(provider2.isItemPicked(60, 201), true);
  });
}
