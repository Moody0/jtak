import 'dart:developer';

import 'package:app_jtak_warehouse/src/config/themes/colors.dart';
import 'package:app_jtak_warehouse/src/core/controllers/products_provider.dart';
import 'package:app_jtak_warehouse/src/core/models/product_model.dart';
import 'package:app_jtak_warehouse/src/ui/widgets/price_widgets.dart';
import 'package:app_jtak_warehouse/src/ui/widgets/product_widgets.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/button.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/dotted_separater.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/messages.dart';
import 'package:app_jtak_warehouse/src/utils/utilities/global_var.dart';
import 'package:flutter/material.dart';
import '../../../config/themes/app_theme.dart';
import 'package:provider/provider.dart';
import '../../../../main_imports.dart';

class SearchPage extends StatefulWidget {
  static const String routeName = '/SearchPage';
  const SearchPage();
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late ProductsProvider provider;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadData());
  }

  Future _loadData() async {
    try {
      await Provider.of<ProductsProvider>(context, listen: false).loadData();
    } catch (err) {
      showDialog(context: context, builder: (context) => CustomDialog(message: err.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    log('^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Searchpage.build');
    provider = Provider.of<ProductsProvider>(context);
    return Scaffold(
      body: FullScreenLoading(
        inAsyncCall: provider.isBusy,
        child: Column(
          children: [
            const SearchTextField(),
            _dataList(),
            _bottomSection(),
          ],
        ),
      ),
    );
  }

  Widget _dataList() {
    return Expanded(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView.builder(
          itemBuilder: (context, index) {
            return ProductSingleItem(provider.productList[index]);
          },
          itemCount: provider.productList.length,
        ),
      ),
    );
    // return Expanded(
    //   child: InfiniteListview(
    //     modelProvider: provider,
    //     loadDataFun: provider.loadData,
    //     listItemWidget: (item) => ProductSingleItem(item),
    //   ),
    // );
  }

  Widget _bottomSection() {
    return ValueListenableBuilder<Map<int, double>>(
      valueListenable: provider.newPricesMap,
      builder: (context, Map<int, double> newPricesMap, child) {
        if (newPricesMap.isNotEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 8),
            child: ButtonWidget(
              text: '${str.formAndAction.save} ( ${newPricesMap.length}  تعديلات)',
              width: double.infinity,
              onPressed: () {
                updateConfirmation();
              },
            ),
          );
        }
        return const SizedBox();
      },
    );
  }

  void updateConfirmation() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: AppTheme.standardPadding,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...provider.newPricesMap.value.keys.map((e) {
                  ProductModel product = provider.dataList.firstWhere((element) => element.productId == e);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(product.product ?? '', style: context.textTheme.bodyText1),
                        Spacer(),
                        PriceTextWidget.small(
                          price: product.finalPrice,
                          currencyIntegerStyle: AppTheme.currencyIntegerStyleSmall.copyWith(color: Colors.grey),
                        ),
                        context.addWidth(16),
                        Icon(Icons.arrow_forward_rounded, size: 15),
                        context.addWidth(16),
                        PriceTextWidget.small(price: provider.newPricesMap.value[e]),
                      ],
                    ),
                  );
                }).toList(),
                ButtonWidget(
                  text: '${str.formAndAction.save} ( ${provider.newPricesMap.value.length}  تعديلات)',
                  width: double.infinity,
                  onPressed: () async {
                    await Provider.of<ProductsProvider>(context, listen: false).updateProductPrices();
                    Navigator.pop(context);
                    context.showSnakBar('تم حفظ الاسعار بنجاح');
                  },
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

class SearchTextField extends StatefulWidget {
  const SearchTextField();
  @override
  State<SearchTextField> createState() => _SearchTextFieldState();
}

class _SearchTextFieldState extends State<SearchTextField> {
  TextEditingController controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    log('%%%%%%%%%%%%%%%%% SearchTextField');
    ProductsProvider provider = Provider.of<ProductsProvider>(context, listen: false);
    controller.text = provider.search ?? '';
    return Material(
      color: Colors.transparent,
      child: TextFormField(
        controller: controller,
        decoration: AppTheme.getTextFieldDecoration(
          hint: 'ابحث عن منتج',
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ).copyWith(
          prefixIcon: Icon(Icons.search, color: kAccentColor),
          suffixIcon: InkWell(
            borderRadius: BorderRadius.circular(180),
            child: const Icon(Icons.close),
            onTap: () async {
              if (provider.search != null || controller.text.isNotEmpty) {
                controller.clear();
                provider.setSearch(null);
              }
            },
          ),
        ),
        onChanged: (searchValue) async {
          provider.setSearch(searchValue);
        },
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
