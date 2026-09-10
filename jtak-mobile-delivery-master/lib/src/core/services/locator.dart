import 'package:app_jtak_delivery/src/core/controllers/app_parameters_provider.dart';
import 'package:app_jtak_delivery/src/core/controllers/order_provider.dart';
import 'package:app_jtak_delivery/src/core/services/authentication_service.dart';
import 'package:app_jtak_delivery/src/utils/providers/sol_api.dart';
import 'package:get_it/get_it.dart';

import '../controllers/app/app_state_manager.dart';

GetIt locator = GetIt.instance;

void setupLocator() {
  locator.registerSingleton(AppStateManager());
  locator.registerLazySingleton(() => AuthenticationService());
  locator.registerLazySingleton(() => SolApi());
  locator.registerLazySingleton(() => AppParametersProvider());
  locator.registerLazySingleton(() => OrderProvider());
}
