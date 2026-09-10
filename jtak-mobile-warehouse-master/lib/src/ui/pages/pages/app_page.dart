import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import '../../../core/controllers/app_pages_provider.dart';
import '../../../utils/custom_widgets/base_view.dart';
import '../../../utils/custom_widgets/dotted_separater.dart';
import '../../../utils/custom_widgets/messages.dart';
import '../../../utils/utilities/global_var.dart';

class AppPage extends StatelessWidget {
  final String pageType;
  final String pageTitle;
  const AppPage({required this.pageType, required this.pageTitle});
  @override
  Widget build(BuildContext context) {
    return BaseView<AppPagesProvider>(
      modelProvider: AppPagesProvider(pageType: pageType),
      onModelReady: (modelProvider) {
        modelProvider.title = pageTitle;
        modelProvider.loadData();
      },
      builder: (context, modelProvider) {
        return Scaffold(
          appBar: AppBar(
            title: Text(modelProvider.title ?? ''),
          ),
          body: FullScreenLoading(
            inAsyncCall: modelProvider.isBusy,
            child: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: !GlobalVar.checkString(modelProvider.body) && !modelProvider.isBusy
                      ? ErrorCustomWidget(str.msg.noDataAvailable)
                      : HtmlWidget(
                          modelProvider.body ?? '',
                          textStyle: const TextStyle(fontSize: 14),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
