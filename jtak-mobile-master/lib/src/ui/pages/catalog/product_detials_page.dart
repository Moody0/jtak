import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:jtek_app/src/config/constants/app_constant.dart';
import 'package:jtek_app/src/config/themes/colors.dart';
import 'package:jtek_app/src/core/models/catalog/product_model.dart';
import 'package:jtek_app/src/ui/pages/cart/add_to_cart_widget.dart';
import '../../../config/constants/constants.dart';
import '../../../config/themes/app_theme.dart';
import '../../../core/controllers/catalog/product_details_provider.dart';
import '../../../core/controllers/order/cart_provider.dart';
import '../cart/cart_page.dart';
import '../../widgets/catalog/price_widgets.dart';
import '../../widgets/catalog/product_widgets.dart';
import '../../widgets/clean_shimmer_skeletons.dart';
import '../../../utils/custom_widgets/badge.dart';
import '../../../utils/custom_widgets/base_view.dart';
import '../../../utils/custom_widgets/dotted_separater.dart';
import '../../../utils/custom_widgets/image_view_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../utils/custom_widgets/image_widgets.dart';
import '../../../utils/custom_widgets/messages.dart';
import '../../../utils/utilities/global_var.dart';
import 'package:provider/provider.dart';
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
      onModelReady: (ProductDetailsProvider provider) => provider.loadsimilarProduct(),
      builder: (context, modelProvider) {
        provider = modelProvider;
        return Scaffold(
          appBar: _appBar(context),
          body: SafeArea(
            child: FullScreenLoading(
              inAsyncCall: provider.isBusy && !provider.isProductEmpty(),
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
        return const ProductDetailsSkeleton();
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
              context.addHeight(16),
              _title(context),
              context.addHeight(16),
              _description(context),
              context.addHeight(24),
              _addToCart(),
              _similarProduct(context),
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
      actions: [
        if (!provider.isProductEmpty()) ...[
          // IconButton(
          //   icon: const Icon(Icons.share),
          //   onPressed: () {
          //     Share.share(provider.shareProduct());
          //   },
          // ),
          Consumer<CartProvider>(
            builder: (context, provider, child) {
              return IconButton(
                icon: CustomBadge(
                  child: const Icon(Icons.shopping_cart),
                  value: provider.count,
                  textColor: kPrimaryColor,
                  backgroundColor: Colors.white,
                ),
                onPressed: () => context.navigateName(CartPage.routeName),
              );
            },
          ),
        ]
      ],
    );
  }

  Widget _addToCart() {
    if (provider.isProductEmpty()) {
      return const SizedBox();
    }
    return AddToCartButton.labelLarge(provider.product, showSuccessMessage: true);
  }

  Widget _similarProduct(BuildContext context) {
    double itemWidth = context.width / 3.2;
    double widgetHeight = 230;
    if (GlobalVar.checkListNotEmpty(provider.similarProductList)) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(start: 12, top: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 30,
              width: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SvgPicture.asset(
                    kAssetSvgBase + 'section_title_background.svg',
                    fit: BoxFit.fill,
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 10),
                      child: Text(
                        str.app.similarProduct,
                        style: context.textTheme.titleLarge!.copyWith(color: Colors.white, fontWeight: FontWeight.normal),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            context.addHeight(8),
            SizedBox(
              height: widgetHeight,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: provider.similarProductList.map((e) => ProductMiniSingleItem(item: e, width: itemWidth)).toList(),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox();
  }

  Widget _description(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: HtmlWidget(
        provider.product.description ?? '',
      ),
    );
  }

  Widget _prices(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (provider.product.hasAuthoritativeDiscount) ...[
            DiscountWidget(
              price: provider.product.originalPrice,
              textStyle: AppTheme.discountCurrencyStyle.copyWith(fontSize: 20, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
            ),
            context.addWidth(16),
          ],
          PriceTextWidget.large(
            price: provider.product.canonicalSellingPrice,
            textStyle: AppTheme.currencyIntegerStyleLarg.copyWith(fontSize: 30),
          ),
        ],
      ),
    );
  }

  Widget _title(BuildContext context) {
    return Text(
      '${provider.product.title} / ${provider.product.unit ?? ''}',
      style: context.textTheme.displaySmall,
      textAlign: TextAlign.center,
    );
  }

  Widget _slider(BuildContext context) {
    double imageWidth = 800, width = context.width;
    double imageHeight = imageWidth * kAppAspectRatio, height = width * kAppAspectRatio;
    if (GlobalVar.checkListNotEmpty(provider.product.photos)) {
      final photos = provider.product.photos!;
      return Stack(
        alignment: Alignment.bottomCenter,
        children: [
          CarouselSlider(
            options: CarouselOptions(
              autoPlay: true,
              viewportFraction: 0.75,
              aspectRatio: 4 / 3,
            ),
            items: photos.asMap().entries.map((entry) {
              final idx = entry.key;
              final e = entry.value;
              return ImageView(
                e,
                height: height,
                width: width,
                imageHeight: imageHeight,
                imageWidth: imageWidth,
                tapped: true,
                heroTag: 'catalog_product_${provider.product.id}_$idx',
                onTap: () {
                  ImageViewPage.openGallery(
                    context,
                    images: photos,
                    initialIndex: idx,
                    title: provider.product.title,
                    heroTag: 'catalog_product_${provider.product.id}_$idx',
                  );
                },
              );
            }).toList(),
          ),
          Positioned(
            bottom: 8,
            child: GestureDetector(
              onTap: () {
                ImageViewPage.openGallery(
                  context,
                  images: photos,
                  initialIndex: 0,
                  title: provider.product.title,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      PhosphorIconsBold.arrowsOut,
                      color: Colors.white,
                      size: 13,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'تكبير الصور',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Image.asset(kNoImage, height: 200);
  }
}
