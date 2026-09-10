import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/controllers/order_provider.dart';
import '../../../ui/pages/order/order_widgets.dart';
import '../../../utils/custom_widgets/infinite_listview.dart';

class OrdersPage extends StatefulWidget {
  static const String routeName = '/OrdersPage';
  const OrdersPage({Key? key}) : super(key: key);

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
      body: _pageBody(context, provider),
    );
  }

  Widget _pageBody(BuildContext context, OrderProvider provider) {
    return InfiniteListview(
      padding: const EdgeInsets.symmetric(vertical: 8),
      modelProvider: provider,
      loadDataFun: provider.loadPagedData,
      listItemWidget: (item) => OrderSingleItem(item),
    );
  }
}
