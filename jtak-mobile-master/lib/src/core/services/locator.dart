import 'package:get_it/get_it.dart';
import 'package:jtek_app/src/core/controllers/app_parameters_provider.dart';
import 'package:jtek_app/src/core/controllers/user/address_provider.dart';
import '../controllers/app_notification_provider.dart';
import '../controllers/catalog/categories_provider.dart';
import '../controllers/catalog/markets_provider.dart';
import '../controllers/order/cart_provider.dart';
import 'authentication_service.dart';
import '../../utils/providers/sol_api.dart';
import '../controllers/app/app_state_manager.dart';

GetIt locator = GetIt.instance;

void setupLocator() {
  locator.registerSingleton(AppStateManager());
  locator.registerLazySingleton(() => AuthenticationService());
  locator.registerLazySingleton(() => SolApi());
  locator.registerLazySingleton(() => AppParametersProvider());
  locator.registerLazySingleton(() => AddressProvider());
  locator.registerLazySingleton(() => CartProvider());
  locator.registerLazySingleton(() => AppNotificationProvider());
  locator.registerLazySingleton(() => MarketsProvider());
  locator.registerLazySingleton(() => CategoriesProvider());
}
