import 'package:app_jtak_warehouse/src/config/themes/colors.dart';
import 'package:app_jtak_warehouse/src/core/controllers/transactions_provider.dart';
import 'package:app_jtak_warehouse/src/ui/pages/transaction/bills_page.dart';
import 'package:app_jtak_warehouse/src/ui/pages/transaction/payment_page.dart';
import 'package:app_jtak_warehouse/src/ui/widgets/price_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../main_imports.dart';

class TransactionPage extends StatefulWidget {
  @override
  _TransactionPageState createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  late TransactionsProvider provider;

  @override
  void initState() {
    Future.microtask(() => Provider.of<TransactionsProvider>(context, listen: false).loadBalances());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    provider = Provider.of<TransactionsProvider>(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _balancesSection(),
              _tabsSection(),
              _tabViewSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabViewSection() {
    return Expanded(
        child: TabBarView(children: [
      PaymentPage(),
      BillsPage(),
    ]));
  }

  Widget _tabsSection() {
    return Container(
      color: kPrimaryColor,
      child: TabBar(
        indicatorColor: kAccentColor,
        tabs: [
          Tab(child: _tabItem('الدفعات', Icons.money)),
          Tab(child: _tabItem('الفواتير', Icons.restore_outlined)),
        ],
      ),
    );
  }

  Widget _tabItem(String title, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white),
        context.addWidth(8),
        Text(title, style: context.textTheme.bodyText1?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _balancesSection() {
    return Row(
      children: [
        _singleBalanceWidget('الرصيد المستحق', provider.balances.amount ?? 0.0),
        // Container(height: 60, color: Colors.grey.shade300, width: 1),
        // _singleBalanceWidget('الرصيد المعلق', provider.balances.pendingAmount ?? 0.0),
      ],
    );
  }

  _singleBalanceWidget(String text, double balance) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: context.textTheme.bodyText1?.copyWith(color: kPrimaryColor)),
            context.addHeight(8),
            PriceTextWidget.small(price: balance),
          ],
        ),
      ),
    );
  }
}
