import '../services/locator.dart';
import 'app/base_provider.dart';
import '../../utils/providers/sol_api.dart';

class AppPagesProvider extends BaseProvider {
  final SolApi _api = locator<SolApi>();
  String? title, subTitle, body;
  final String pageType;
  AppPagesProvider({required this.pageType});

  Future loadData() async {
    await loadBaseData(loadBody: () async {
      var res = await _api.getRequest('/Pages/$pageType', apiPrefex: SolApi.apiVersionPrefex + '/Customer');
      _parsePageObject(res);
    });
  }

  void _parsePageObject(Map<String, dynamic> map) {
    if (map.containsKey('title')) {
      title = map['title'];
    }
    if (map.containsKey('subTitle')) {
      subTitle = map['subTitle'];
    }
    if (map.containsKey('body')) {
      body = map['body'];
    }
  }
}
