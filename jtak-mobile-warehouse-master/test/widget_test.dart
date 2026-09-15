import 'package:app_jtak_warehouse/src/core/controllers/app/merchant_state_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('MerchantStateProvider initial values and tab switching', () {
    final provider = MerchantStateProvider();
    expect(provider.currentIndex, 0);
    expect(provider.isStoreOpen, true);
    expect(provider.isSoundAlertEnabled, true);

    provider.setIndex(3);
    expect(provider.currentIndex, 3);

    provider.updatePendingOrdersCount(5);
    expect(provider.pendingOrdersCount, 5);
  });
}
