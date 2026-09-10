import 'package:flutter/material.dart';
import '../../core/controllers/app_notification_provider.dart';
import '../widgets/notification_widgets.dart';
import '../../utils/custom_widgets/base_view.dart';
import '../../utils/custom_widgets/infinite_listview.dart';
import '../../utils/utilities/global_var.dart';

class AppNotificationsPage extends StatelessWidget {
  static const String routeName = '/AppNotificationsPage';
  @override
  Widget build(BuildContext context) {
    return BaseView<AppNotificationProvider>(
      modelProvider: AppNotificationProvider(),
      onModelReady: (modelProvider) => modelProvider.loadData(),
      builder: (context, modelProvider) {
        return Scaffold(
          appBar: AppBar(
            title: Text(str.main.notifications),
          ),
          body: SafeArea(
            child: InfiniteListview(
              modelProvider: modelProvider,
              loadDataFun: modelProvider.loadData,
              listItemWidget: (item) => AppNotificationsSingleItem(item),
            ),
          ),
        );
      },
    );
  }
}
