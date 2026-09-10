import 'package:flutter/material.dart';
import '../../../core/controllers/catalog/product_review_provider.dart';
import '../../../core/models/catalog/product_review_model.dart';
import '../../widgets/catalog/reviews_widgets.dart';
import '../../../utils/custom_widgets/base_view.dart';
import '../../../utils/custom_widgets/dotted_separater.dart';
import '../../../utils/utilities/global_var.dart';

class SingleProductReviewPage extends StatefulWidget {
  static const String routeName = '/SingleProductReviewPage';
  final ProductReviewModel item;
  const SingleProductReviewPage(this.item);
  @override
  _SingleProductReviewPageState createState() => _SingleProductReviewPageState();
}

class _SingleProductReviewPageState extends State<SingleProductReviewPage> {
  @override
  Widget build(BuildContext context) {
    return BaseView<ProductReviewProvider>(
      modelProvider: ProductReviewProvider(),
      builder: (context, modelProvider) {
        return Scaffold(
          appBar: AppBar(
            title: Text(str.app.productReview),
          ),
          body: SafeArea(
            child: FullScreenLoading(
              inAsyncCall: modelProvider.isBusy,
              child: ListView(
                children: [
                  ProductCard(widget.item),
                  AddReviewWidget(
                    productId: widget.item.productId ?? 0,
                    initRate: widget.item.rate ?? 0,
                    onRatingChange: (rate) => widget.item.rate = rate,
                    textReview: widget.item.textReview ?? '',
                    onTextReviewChange: (textReview) => widget.item.textReview = textReview,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
