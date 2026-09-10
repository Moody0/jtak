import 'package:app_jtak_warehouse/src/core/controllers/product_details_provider.dart';
import 'package:app_jtak_warehouse/src/core/models/product_model.dart';
import 'package:app_jtak_warehouse/src/ui/widgets/price_widgets.dart';
import 'package:app_jtak_warehouse/src/ui/widgets/rating_bar.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import '../../../config/constants/constants.dart';
import '../../../config/themes/app_theme.dart';
import '../../../utils/custom_widgets/base_view.dart';
import '../../../utils/custom_widgets/dotted_separater.dart';
import '../../../utils/custom_widgets/image_slider_page.dart';
import 'dart:math' as math;
import '../../../utils/custom_widgets/image_widgets.dart';
import '../../../utils/custom_widgets/messages.dart';
import '../../../utils/utilities/global_var.dart';
import '../../../../main_imports.dart';

class ProductDetailsPage extends StatefulWidget {
  static const String routeName = '/ProductDetailsPage';

  final ProductModel product;
  const ProductDetailsPage(this.product);

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  late ProductDetailsProvider provider;
  @override
  Widget build(BuildContext context) {
    return BaseView<ProductDetailsProvider>(
      modelProvider: ProductDetailsProvider(widget.product),
      onModelReady: (modelProvider) => modelProvider.loadProductDetails(),
      builder: (context, modelProvider) {
        provider = modelProvider;
        return Scaffold(
          appBar: _appBar(context),
          body: SafeArea(
            child: FullScreenLoading(
              inAsyncCall: provider.isBusy,
              child: _pageBody(),
            ),
          ),
        );
      },
    );
  }

  Widget _pageBody() {
    if (provider.isProductEmpty()) {
      if (!provider.isBusy) {
        return ErrorCustomWidget(str.app.productNotAvailable, showErrorWord: false);
      } else {
        return const SizedBox();
      }
    }
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverList(
          delegate: SliverChildListDelegate(
            [
              _slider(context),
              context.addHeight(16),
              _prices(context),
              _title(context),
              const Divider(),
              _description(context),
              const Divider(),
              _rateWidget(),
              Container(height: 60),
            ],
          ),
        ),
      ],
    );
  }

  AppBar _appBar(BuildContext context) {
    return AppBar(
      title: Text(str.app.productDetails),
    );
  }

  Widget _description(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: HtmlWidget(
        provider.product.product ?? '',
      ),
    );
  }

  Widget _prices(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DiscountWidget(price: provider.product.price),
          PriceTextWidget.large(price: provider.product.finalPrice),
        ],
      ),
    );
  }

  Widget _rateWidget() {
    return Column(
      children: [
        Row(
          children: [
            RatingBarWidget(rate: provider.product.price ?? 0),
            context.addWidth(5),
            Text('(${provider.product.productId})'),
            const Spacer(),
            InkWell(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(str.main.seeAll, style: AppTheme.linkStyle),
              ),
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _title(BuildContext context) {
    return Text(
      provider.product.product ?? '',
      style: context.textTheme.headline3,
      textAlign: TextAlign.center,
    );
  }

  Widget _slider(BuildContext context) {
    double imageWidth = math.min(context.width, 500);
    double imageHeight = imageWidth * (4 / 3);
    if (GlobalVar.checkListNotEmpty(provider.product.productPhotos!.split(','))) {
      return CarouselSlider(
        options: CarouselOptions(
          autoPlay: true,
          viewportFraction: 0.7,
          enlargeStrategy: CenterPageEnlargeStrategy.height,
        ),
        items: provider.product.productPhotos!.split(',').map((e) {
          return ImageView(
            e,
            height: imageHeight,
            width: imageWidth,
            imageHeight: 800,
            imageWidth: 600,
            tapped: true,
            onTap: () => context.navigateName(ImageSliderPage.routeName, data: [provider.product.productPhotos!.split(','), e]),
          );
        }).toList(),
      );
    }
    return Image.asset(kNoImage, height: 200);
  }
}
