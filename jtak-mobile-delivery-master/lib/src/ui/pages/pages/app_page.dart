import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/app_pages_provider.dart';
import '../../../utils/custom_widgets/base_view.dart';
import '../../../utils/custom_widgets/loading.dart';
import '../../../utils/custom_widgets/messages.dart';
import '../../../utils/utilities/global_var.dart';

class AppPage extends StatelessWidget {
  final String pageType;
  final String pageTitle;
  const AppPage({required this.pageType, required this.pageTitle, Key? key}) : super(key: key);

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
          backgroundColor: kPageBackground,
          appBar: AppBar(
            title: Text(
              modelProvider.title ?? pageTitle,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            centerTitle: true,
          ),
          body: FullScreenLoading(
            inAsyncCall: modelProvider.isBusy,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: kCardBorderColor, width: 1.1),
                  ),
                  child: !GlobalVar.checkString(modelProvider.body) && !modelProvider.isBusy
                      ? ErrorCustomWidget(str.msg.noDataAvailable)
                      : HtmlWidget(
                          modelProvider.body ?? '',
                          textStyle: const TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: kCharcoalDark,
                            fontFamily: 'IBMPlexSansArabic',
                          ),
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
