import 'package:app_jtak_delivery/src/ui/widgets/app_widgets.dart';
import 'package:flutter/material.dart';

import '../../config/themes/app_theme.dart';
import '../../core/enums/viewstate.dart';
import '../../core/controllers/app/base_provider.dart';
import '../utilities/global_var.dart';
import 'loading.dart';
import 'messages.dart';

class InfiniteListview<T> extends StatelessWidget {
  final BaseProvider modelProvider;
  final Future Function() loadDataFun;
  final Function(dynamic item) listItemWidget;
  final EdgeInsets padding;
  final Widget? emptyWidget;
  const InfiniteListview({
    Key? key,
    required this.modelProvider,
    required this.loadDataFun,
    required this.listItemWidget,
    this.padding = const EdgeInsets.all(4),
    this.emptyWidget,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () {
        modelProvider.page = 0;
        return loadDataFun();
      },
      child: ListView.builder(
        padding: padding,
        itemCount: modelProvider.dataList.length + 1,
        itemBuilder: (ctx, index) {
          // load more items
          if (index == modelProvider.dataList.length - modelProvider.nextPageThreshold && modelProvider.isMoreAvailable && !modelProvider.isBusy) {
            loadDataFun();
          }
          // handel bottom in list
          if (index == modelProvider.dataList.length) {
            if (modelProvider.state == ViewState.busy) {
              return const LoadingWidget();
            } else if (modelProvider.dataList.isEmpty) {
              return emptyWidget ?? const NoDataAvailableWidget();
            } else {
              return const SizedBox();
            }
          }
          // show list item
          return listItemWidget(modelProvider.dataList[index]);
        },
      ),
    );
  }
}

class InfiniteSliverList<T> extends StatelessWidget {
  final BaseProvider modelProvider;
  final Future Function() loadDataFun;
  final Function(dynamic item) listItemWidget;
  final EdgeInsets padding;
  const InfiniteSliverList({
    Key? key,
    required this.modelProvider,
    required this.loadDataFun,
    required this.listItemWidget,
    this.padding = AppTheme.standardPadding,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, index) {
            // load more items
            if (index == modelProvider.dataList.length - modelProvider.nextPageThreshold && modelProvider.isMoreAvailable && !modelProvider.isBusy) {
              loadDataFun();
            }
            // handel bottom in list
            if (index == modelProvider.dataList.length) {
              if (modelProvider.state == ViewState.busy) {
                return const LoadingWidget();
              } else if (modelProvider.dataList.isEmpty) {
                return ErrorCustomWidget(str.msg.noDataAvailable, showErrorWord: false);
              } else {
                return const SizedBox();
              }
            }
            // show list item
            return listItemWidget(modelProvider.dataList[index]);
          },
          childCount: modelProvider.dataList.length + 1,
        ),
      ),
    );
  }
}
