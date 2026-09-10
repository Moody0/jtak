import 'package:flutter/material.dart';
import 'package:jtek_app/src/config/constants/app_constant.dart';
import 'package:jtek_app/src/ui/pages/cart/add_to_cart_widget.dart';
import '../../../config/themes/colors.dart';
import '../../../core/controllers/catalog/favorite_product_provider.dart';
import '../../../core/models/catalog/product_model.dart';
import '../../pages/catalog/product_detials_page.dart';
import 'price_widgets.dart';
import '../../../utils/custom_widgets/image_widgets.dart';
import 'package:provider/provider.dart';
import '../../../../main_imports.dart';

class ProductSingleItem extends StatelessWidget {
  final ProductModel item;
  const ProductSingleItem(this.item);
  @override
  Widget build(BuildContext context) {
    double cardHeight = 130;
    double imageWidth = cardHeight * (3 / 4);
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(8),
      child: SizedBox(
        height: cardHeight,
        child: InkWell(
          onTap: () => context.navigateName(ProductDetailsPage.routeName, data: item),
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
                        children: [
                          Text(
                            item.title ?? '',
                            style: context.textTheme.headlineSmall,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const SizedBox(),
                              DiscountWidget(price: item.discount),
                              PriceTextWidget.small(price: item.finalPrice),
                              AddToCartButton.circular(item),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              _favoriteWidget(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _favoriteWidget(BuildContext context) {
    return PositionedDirectional(
      end: 0,
      child: Consumer<FavoriteProductProvider>(
        builder: (context, favProvider, child) {
          bool res = favProvider.find(item.id!);
          IconData icon = Icons.bookmark_add_outlined;
          Color color = Colors.grey;
          if (res) {
            icon = Icons.bookmark;
            color = kPrimaryColor;
          }
          return IconButton(
            icon: Icon(icon, color: color),
            onPressed: () {
              if (res) {
                favProvider.delete(item.id!);
              } else {
                favProvider.add(item);
              }
            },
          );
        },
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
        elevation: 2,
        margin: const EdgeInsets.all(8),
        child: InkWell(
          onTap: () {
            context.navigateName(ProductDetailsPage.routeName, data: item);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ImageView(item.photos?.first, height: imageHeight, width: cardWidth, fit: BoxFit.cover),
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4, top: 8),
                child: Text(
                  item.title ?? '',
                  style: context.textTheme.bodyLarge?.copyWith(fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  textScaler: const TextScaler.linear(1),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    PriceTextWidget.small(price: item.finalPrice),
                    AddToCartButton.circular(item),
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
  final double? width;
  const ProductMiniSingleItem({required this.item, this.width});

  static double getAspectRatio(BuildContext context) {
    const double itemCount = 3;
    double margin = (8 * itemCount);
    double itemWidth = context.width / 3 - margin;
    double imageHeight = itemWidth * kAppAspectRatio;
    double itemheight = imageHeight + 80;
    return itemWidth / itemheight;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: LayoutBuilder(
        builder: (context, constraints) {
          double imageWidth = constraints.minWidth;
          double imageHeight = imageWidth * kAppAspectRatio;
          return Stack(
            children: [
              Card(
                elevation: 15,
                margin: const EdgeInsets.all(4),
                child: InkWell(
                  onTap: () => context.navigateName(ProductDetailsPage.routeName, data: item),
                  child: Column(
                    children: [
                      ImageView(
                        item.photos?.first,
                        height: imageHeight,
                        width: imageWidth,
                        crop: true,
                        showLoader: false,
                        alignment: Alignment.topCenter,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            context.addHeight(8),
                            _priceSection(context),
                            context.addHeight(4),
                            _title(context),
                            Text(item.unit ?? '', style: context.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _addTocartBtn(context),
            ],
          );
        },
      ),
    );
  }

  Text _title(BuildContext context) {
    return Text(
      // 'context textTheme displaySmall? copyWith',
      item.title ?? '',
      style: context.textTheme.displaySmall?.copyWith(fontSize: 13),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textScaler: const TextScaler.linear(1),
    );
  }

  Widget _priceSection(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.price != null && item.finalPrice != null && item.price != item.finalPrice)
          Expanded(flex: 1, child: DiscountWidget(price: item.discount)),
        Expanded(flex: 2, child: PriceTextWidget.small(price: item.finalPrice)),
      ],
    );
  }

  Widget _addTocartBtn(BuildContext context) {
    return PositionedDirectional(
      top: 0,
      start: 0,
      child: AddToCartButton.circular(item),
    );
  }
}
