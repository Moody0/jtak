import '../services/locator.dart';
import '../models/app_notification_model.dart';
import 'app/base_provider.dart';
import '../services/authentication_service.dart';
import '../../utils/providers/sol_api.dart';

class AppNotificationProvider extends BaseProvider<AppNotificationModel> {
  final SolApi _api = locator<SolApi>();
  int count = 0;

  Future loadData() async {
    await loadInfinityData(
      loadData: (page) async {
        List data = await _api.getRequest('/Notifications/$page');
        List<AppNotificationModel> list = [];
        for (var element in data) {
          list.add(AppNotificationModel.fromMap(element));
        }
        return list;
      },
    );
  }

  Future getAppNotificationCount() async {
    if (locator<AuthenticationService>().isLogin()) {
      count = await _api.getRequest('/Notifications/Count');
    }
  }

  Future<void> subscribeTopic(String topic) async {
    await loadBaseData(loadBody: () async {
      await _api.postRequest('/Notifications/Subscribe/$topic/{token}', {});
    });
  }

  Future<void> unsubscribeTopic(String topic) async {
    await _api.postRequest('/Notifications/Unsubscribe/$topic/{token}', {});
  }

  Future resetData() async {
    dataList.clear();
    count = 0;
  }
}
