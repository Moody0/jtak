import 'package:flutter/material.dart';

import '../../config/themes/app_theme.dart';
import '../../core/controllers/app/base_provider.dart';
import '../../core/enums/viewstate.dart';
import '../utilities/global_var.dart';
import 'loading.dart';
import 'messages.dart';

class InfiniteListview<T> extends StatelessWidget {
  final BaseProvider modelProvider;
  final Future Function() loadDataFun;
  final Function(dynamic item) listItemWidget;
  final EdgeInsets padding;
  final Widget? emptyDataWidget;
  const InfiniteListview({
    Key? key,
    required this.modelProvider,
    required this.loadDataFun,
    required this.listItemWidget,
    this.emptyDataWidget,
    this.padding = AppTheme.standardPadding,
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
              return emptyDataWidget ?? ErrorCustomWidget(str.msg.noDataAvailable, showErrorWord: false);
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
    return SliverList(
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
    );
  }
}

class InfiniteSliverGrid<T> extends StatelessWidget {
  final BaseProvider modelProvider;
  final Future Function() loadDataFun;
  final Function(dynamic item) listItemWidget;
  final int crossAxisCount;
  final double gridViewAspectRatio;
  final EdgeInsets padding;
  const InfiniteSliverGrid({
    Key? key,
    required this.modelProvider,
    required this.loadDataFun,
    required this.listItemWidget,
    this.crossAxisCount = 3,
    this.gridViewAspectRatio = 1,
    this.padding = AppTheme.standardPadding,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (ctx, index) {
          // load more items
          if (index == modelProvider.dataList.length - modelProvider.nextPageThreshold && modelProvider.isMoreAvailable && !modelProvider.isBusy) {
            loadDataFun();
          }

          // show list item
          return listItemWidget(modelProvider.dataList[index]);
        },
        childCount: modelProvider.dataList.length,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: gridViewAspectRatio,
      ),
    );
  }
}
