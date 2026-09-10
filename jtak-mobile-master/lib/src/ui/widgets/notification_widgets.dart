import 'package:flutter/material.dart';
import '../../core/models/app_notification_model.dart';
import '../../utils/utilities/global_var.dart';

class AppNotificationsSingleItem extends StatelessWidget {
  final AppNotificationModel item;
  const AppNotificationsSingleItem(this.item);
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(item.title ?? ''),
        subtitle: Text(item.text ?? ''),
        trailing: Text(GlobalVar.dateForamt(item.createdDate) ?? ''),
      ),
    );
  }
}
