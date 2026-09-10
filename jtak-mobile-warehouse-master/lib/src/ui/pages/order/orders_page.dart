import 'dart:async';
import 'package:app_jtak_warehouse/src/config/themes/colors.dart';
import 'package:app_jtak_warehouse/src/core/controllers/order_provider.dart';
import 'package:app_jtak_warehouse/src/ui/pages/order/order_widgets.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/dotted_separater.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/infinite_listview.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OrdersPage extends StatefulWidget {
  static const String routeName = '/OrdersPage';
  const OrdersPage();
  @override
  _OrdersPageState createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late OrderProvider provider;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    loadinitData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final model = Provider.of<OrderProvider>(context, listen: false);
      if (!model.isBusy) model.refreshData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void loadinitData() async {
    OrderProvider provider = Provider.of<OrderProvider>(context, listen: false);
    provider.refreshData();
  }

  @override
  Widget build(BuildContext context) {
    provider = Provider.of<OrderProvider>(context);
    return Scaffold(
      backgroundColor: kGreyBackground,
      body: SafeArea(
        child: FullScreenLoading(
          inAsyncCall: provider.isBusy,
          child: _pageBody(context, provider),
        ),
      ),
    );
  }

  Widget _pageBody(BuildContext context, OrderProvider provider) {
    return InfiniteListview(
      modelProvider: provider,
      loadDataFun: provider.loadPagedData,
      listItemWidget: (item) => OrderSingleItem(item),
    );
  }
}
