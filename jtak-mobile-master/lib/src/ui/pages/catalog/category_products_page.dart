import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:jtek_app/src/config/themes/colors.dart';
import 'package:jtek_app/src/core/controllers/catalog/category_products_provider.dart';
import 'package:jtek_app/src/core/models/catalog/product_model.dart';
import 'package:jtek_app/src/ui/widgets/catalog/category_widgets.dart';
import 'package:jtek_app/src/ui/widgets/catalog/product_widgets.dart';
import 'package:provider/provider.dart';

////////////////{ Ref : https://medium.com/flutter-community/create-shop-list-with-flutter-d13d3c20d68b } ////////////////

class Shop extends StatefulWidget {
  @override
  ShopView createState() => ShopView();
}

////////////////{ ShopView File  } ////////////////
class ShopView extends ShopViewModel {
  @override
  void initState() {
    log('########################## ShopView initState');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    provider = Provider.of<CategoryProductsProvider>(context, listen: false);
    return buildChangeBody();
  }

  ChangeNotifierProvider<TabBarChange> buildChangeBody() {
    return ChangeNotifierProvider.value(
      value: tabBarNotifier,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          buildListViewHeader,
          Expanded(child: buildListViewShop),
        ],
      ),
    );
  }

  ListView get buildListViewShop {
    return ListView.builder(
      controller: scrollController,
      itemCount: shopListAndSpaceAreaLength,
      itemBuilder: (context, index) {
        log(index.toString());
        if (index == shopListLastIndex) {
          return emptyWidget;
        } else {
          return ShopCard(
            model: provider.dataList[index],
            index: index,
            onHeight: (val) {
              fillListPositionValues(val);
            },
          );
        }
      },
    );
  }

  int get shopListAndSpaceAreaLength => provider.dataList.length;

  int get shopListLastIndex => provider.dataList.length;

  SizedBox get emptyWidget => SizedBox(height: oneItemHeight * 2);

  Widget get buildListViewHeader {
    return Consumer<TabBarChange>(
      builder: (context, value, child) => Container(
        height: 40,
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kAccentColor, width: 3))),
        child: ListView.builder(
          itemCount: provider.dataList.length,
          controller: headerScrollController,
          padding: const EdgeInsets.only(top: 10),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) => buildPaddingHeaderCard(index),
        ),
      ),
    );
  }

  Widget buildPaddingHeaderCard(int index) {
    return CategoryHeaderItem(
      provider.dataList[index].category,
      isActive: index == provider.selectedCategoryIndex,
      onTap: () {
        setState(() {
          provider.selectedCategoryIndex = index;
        });
        headerListChangePosition(index);
      },
    );
  }
}

////////////////{ ShopViewModel } ////////////////

abstract class ShopViewModel extends State<Shop> {
  ScrollController scrollController = ScrollController();
  int currentCategoryIndex = 0;
  ScrollController headerScrollController = ScrollController();
  late CategoryProductsProvider provider;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(() async {
      if (!provider.productScrollControllerAnimate) {
        CategoryProductsProvider provider = Provider.of<CategoryProductsProvider>(context, listen: false);
        final index = provider.dataList.indexWhere((element) => element.position >= scrollController.offset);
        tabBarNotifier.changeIndex(index);

        await headerScrollController.animateTo(index * (MediaQuery.of(context).size.width * 0.3),
            duration: const Duration(milliseconds: 750), curve: Curves.easeIn);
        log('provider.selectedCategoryIndex : $index');
        setState(() {
          provider.selectedCategoryIndex = index;
        });
      }
    });
  }

  void headerListChangePosition(int index) async {
    provider.productScrollControllerAnimate = true;
    await scrollController.animateTo(provider.dataList[index].position, duration: const Duration(milliseconds: 700), curve: Curves.easeInOut);
    provider.productScrollControllerAnimate = false;
  }

  double oneItemHeight = 0;

  void fillListPositionValues(double val) {
    if (oneItemHeight == 0) {
      oneItemHeight = val;
      provider.dataList.asMap().forEach((key, value) {
        if (key == 0) {
          provider.dataList[key].position = 0;
        } else {
          provider.dataList[key].position = getShopListPosition(val, key);
        }
      });
    }
  }

  double getShopListPosition(double val, int index) =>
      val * (provider.dataList[index].products.length / CategoryProductsProvider.gridColumnValue) + provider.dataList[index - 1].position;

  @override
  void dispose() {
    headerScrollController.dispose();
    scrollController.dispose();
    super.dispose();
  }
}

////////////////{ TabBarChange file } ////////////////

class TabBarChange extends ChangeNotifier {
  int index = 0;

  void changeIndex(int val) {
    index = val;
    notifyListeners();
  }
}

TabBarChange tabBarNotifier = TabBarChange();

////////////////{ ShopCard File } ////////////////

class ShopCard extends StatelessWidget {
  final ShopModel model;
  final int index;
  final Function(double val) onHeight;

  const ShopCard({Key? key, required this.model, required this.index, required this.onHeight}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      onHeight((context.size!.height) / (model.products.length / CategoryProductsProvider.gridColumnValue));
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: CategoryProductsProvider.headerCategoryHieght,
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kAccentColor, width: 3))),
          child: Align(alignment: AlignmentDirectional.centerStart, child: CategoryHeaderItem(model.category, isActive: true)),
        ),
        buildGridViewProducts(model.products),
      ],
    );
  }

  GridView buildGridViewProducts(List<ProductModel> products) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        childAspectRatio: 3 / 4,
        crossAxisCount: CategoryProductsProvider.gridColumnValue,
      ),
      itemBuilder: (context, index) {
        return ProductMiniSingleItem(item: products[index]);
      },
    );
  }
}
