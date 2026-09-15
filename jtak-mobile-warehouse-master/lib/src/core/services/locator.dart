import 'package:app_jtak_warehouse/src/core/controllers/app_parameters_provider.dart';
import 'package:app_jtak_warehouse/src/core/controllers/order_provider.dart';
import 'package:app_jtak_warehouse/src/core/controllers/products_provider.dart';
import 'package:app_jtak_warehouse/src/core/services/authentication_service.dart';
import 'package:app_jtak_warehouse/src/utils/providers/sol_api.dart';
import 'package:get_it/get_it.dart';

import '../controllers/app/app_state_manager.dart';
import '../controllers/app/merchant_state_provider.dart';
import '../controllers/merchant_profile_provider.dart';
import 'upload_service.dart';

GetIt locator = GetIt.instance;

void setupLocator() {
  locator.registerSingleton(AppStateManager());
  locator.registerLazySingleton(() => MerchantStateProvider());
  locator.registerLazySingleton(() => MerchantProfileProvider());
  locator.registerLazySingleton(() => UploadService());
  locator.registerLazySingleton(() => AuthenticationService());
  locator.registerLazySingleton(() => SolApi());
  locator.registerLazySingleton(() => AppParametersProvider());
  locator.registerLazySingleton(() => ProductsProvider());
  locator.registerLazySingleton(() => OrderProvider());
}
