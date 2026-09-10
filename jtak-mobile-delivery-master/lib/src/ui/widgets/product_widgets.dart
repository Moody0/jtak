import 'package:app_jtak_delivery/src/config/themes/colors.dart';
import 'package:app_jtak_delivery/src/core/models/product_model.dart';
import 'package:app_jtak_delivery/src/ui/widgets/price_widgets.dart';
import 'package:app_jtak_delivery/src/utils/custom_widgets/image_widgets.dart';
import 'package:flutter/material.dart';
import '../../../../main_imports.dart';

class ProductSingleItem extends StatelessWidget {
  final ProductModel item;
  const ProductSingleItem(this.item);
  @override
  Widget build(BuildContext context) {
    double cardHeight = 130;
    double imageWidth = cardHeight * (3 / 4);
    return Card(
      elevation: 0,
      child: SizedBox(
        height: cardHeight,
        child: InkWell(
          // onTap: () => context.navigateName(ProductDetailsPage.routeName, data: item),
          child: Stack(
            children: [
              Row(
                children: [
                  ImageView(item.photos?.first, height: cardHeight, width: imageWidth, fit: BoxFit.cover),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Text(
                            item.title ?? '',
                            style: context.textTheme.headline3,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            item.productCategory ?? '',
                            style: context.textTheme.headline6!.copyWith(color: kAccentColor),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              const SizedBox(),
                              DiscountWidget(price: item.discount),
                              PriceTextWidget.small(price: item.finalPrice),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductGridSingleItem extends StatelessWidget {
  final ProductModel item;
  const ProductGridSingleItem(this.item);
  @override
  Widget build(BuildContext context) {
    double cardWidth = context.width / 2.5;
    double imageHeight = cardWidth * (4 / 3);
    return SizedBox(
      width: cardWidth,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.all(8),
        child: InkWell(
          onTap: () {
            // context.navigateName(ProductDetailsPage.routeName, data: item);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ImageView(item.photos?.first, height: imageHeight, width: cardWidth, fit: BoxFit.cover),
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4, top: 8),
                child: Text(
                  item.title ?? '',
                  style: context.textTheme.bodyText1?.copyWith(fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  textScaleFactor: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    PriceTextWidget.small(price: item.finalPrice),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class ProductMiniSingleItem extends StatelessWidget {
  final ProductModel item;
  final double itemHeight;
  const ProductMiniSingleItem({required this.item, required this.itemHeight});
  @override
  Widget build(BuildContext context) {
    double imageHeight = itemHeight * 0.2;
    double imageWidth = imageHeight * (16 / 9);

    return SizedBox(
      height: itemHeight,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.all(8),
        child: InkWell(
          // onTap: () => context.navigateName(ProductDetailsPage.routeName, data: item),
          child: Column(
            children: [
              ImageView(item.photos?.first, height: imageHeight, width: imageWidth, fit: BoxFit.cover),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PriceTextWidget.small(price: item.finalPrice),
                    context.addHeight(4),
                    Text(
                      item.title ?? '',
                      style: context.textTheme.bodyText1?.copyWith(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      textScaleFactor: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
