import 'package:app_jtak_delivery/src/core/controllers/app/base_provider.dart';

import '../services/locator.dart';
// import '../../utils/providers/sol_api.dart';
import '../services/authentication_service.dart';

class InitialDataProvider extends BaseProvider {
  // final SolApi _api = locator<SolApi>();

  Future<void> getInitData() async {
    // const String url = "/api/v1/account";
    try {
      await locator<AuthenticationService>().loadUserData();
    } catch (error) {
      rethrow;
    }
  }
}
