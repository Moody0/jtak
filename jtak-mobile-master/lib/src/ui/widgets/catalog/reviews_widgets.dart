import 'package:flutter/material.dart';
import 'package:jtek_app/src/core/models/catalog/product_model.dart';
import '../../../config/themes/app_theme.dart';
import '../../../core/controllers/catalog/product_review_provider.dart';
import '../../../core/models/catalog/product_review_model.dart';
import '../../pages/catalog/product_detials_page.dart';
import '../../pages/catalog/single_product_review_page.dart';
import '../../../utils/custom_widgets/button.dart';
import '../../../utils/custom_widgets/image_widgets.dart';
import '../../../utils/custom_widgets/messages.dart';
import '../../../utils/custom_widgets/rating_bar.dart';
import '../../../utils/utilities/global_var.dart';
import 'package:provider/provider.dart';
import '../../../../main_imports.dart';

class ProductReviewSingleItem extends StatelessWidget {
  final ProductReviewModel item;
  const ProductReviewSingleItem(this.item);
  @override
  Widget build(BuildContext context) {
    double cardHeight = 130;
    double imageWidth = cardHeight * (3 / 4);
    return Card(
      child: InkWell(
        onTap: () async {
          var res = await context.navigateName(SingleProductReviewPage.routeName, data: item);
          if (res is bool && res) {
            Provider.of<ProductReviewProvider>(context, listen: false).loadData();
          }
        },
        child: Column(
          children: [
            Row(
              children: [
                ImageView(item.productImage, height: cardHeight, width: imageWidth, fit: BoxFit.cover),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(
                          item.productTitle ?? '',
                          style: context.textTheme.headlineSmall,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                        ),
                        RatingBarWidget(
                          rate: item.rate ?? 0,
                        )
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Provider.of<ProductReviewProvider>(context, listen: false).delete(item.id!),
                  icon: const Icon(Icons.close),
                )
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                item.textReview ?? '',
                style: context.textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final ProductReviewModel item;
  const ProductCard(this.item);

  @override
  Widget build(BuildContext context) {
    double cardHeight = 130;
    double imageWidth = cardHeight * (3 / 4);
    return Card(
      child: InkWell(
        onTap: () => context.navigateName(ProductDetailsPage.routeName,
            data: ProductModel(id: item.productId, title: item.productTitle, photos: item.productImage?.split(','))),
        child: Row(
          children: [
            ImageView(item.productImage, height: cardHeight, width: imageWidth, fit: BoxFit.cover),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  item.productTitle ?? '',
                  style: context.textTheme.headlineSmall,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddReviewWidget extends StatefulWidget {
  final double initRate;
  final void Function(double rate)? onRatingChange;
  final String textReview;
  final void Function(String textReview)? onTextReviewChange;
  final int productId;
  const AddReviewWidget({required this.productId, this.initRate = 0, this.onRatingChange, this.textReview = '', this.onTextReviewChange});

  @override
  State<AddReviewWidget> createState() => _AddReviewWidgetState();
}

class _AddReviewWidgetState extends State<AddReviewWidget> {
  double rate = 0;
  String textReview = '';
  @override
  void initState() {
    super.initState();
    rate = widget.initRate;
    textReview = widget.textReview;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _rateWidget(),
            context.addHeight(12),
            _textReviewWidget(context),
            saveBTN(context),
          ],
        ),
      ),
    );
  }

  Widget _rateWidget() {
    return RatingBarWidget(
      rate: widget.initRate,
      onRatingUpdateHandler: (rating) {
        rate = rating;
        if (widget.onRatingChange != null) {
          widget.onRatingChange!(rating);
        }
      },
      itemSize: 40,
    );
  }

  Widget _textReviewWidget(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(str.app.addReviewTextMsg, style: context.textTheme.titleLarge),
        context.addHeight(12),
        TextFormField(
          initialValue: widget.textReview,
          maxLines: 5,
          minLines: 2,
          decoration: AppTheme.getBorderdTextFieldDecoration(hint: str.app.addReviewTextMsg),
          onChanged: (value) {
            textReview = value;
            if (widget.onTextReviewChange != null) {
              widget.onTextReviewChange!(value);
            }
          },
        ),
      ],
    );
  }

  Widget saveBTN(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ButtonWidget(
          text: str.formAndAction.save,
          onPressed: () async {
            try {
              ProductReviewProvider productReviewProvider = ProductReviewProvider();
              ProductReviewModel item = ProductReviewModel(
                productId: widget.productId,
                rate: rate,
                textReview: textReview,
              );
              await productReviewProvider.save(item);
              context.showSnakBar(str.msg.saveSucceeded);
            } catch (err) {
              showDialog(context: context, builder: (context) => CustomDialog(message: err.toString()));
            }
          }),
    );
  }
}
