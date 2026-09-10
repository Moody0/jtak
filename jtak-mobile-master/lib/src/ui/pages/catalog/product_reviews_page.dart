import 'package:flutter/material.dart';
import '../../../core/controllers/catalog/product_review_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/catalog/reviews_widgets.dart';
import '../../../utils/custom_widgets/base_view.dart';
import '../../../utils/custom_widgets/loading.dart';
import '../../../utils/utilities/global_var.dart';

class ProductReviewsPage extends StatefulWidget {
  static const String routeName = '/ProductReviewsPage';
  @override
  _ProductReviewsPageState createState() => _ProductReviewsPageState();
}

class _ProductReviewsPageState extends State<ProductReviewsPage> {
  @override
  Widget build(BuildContext context) {
    return BaseView<ProductReviewProvider>(
      modelProvider: ProductReviewProvider(),
      onModelReady: (modelProvider) => modelProvider.loadData(),
      builder: (context, modelProvider) {
        return Scaffold(
          appBar: AppBar(
            title: Text(str.app.productReviews),
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () => modelProvider.loadData(),
              child: _dataList(modelProvider),
            ),
          ),
        );
      },
    );
  }

  Widget _dataList(ProductReviewProvider provider) {
    if (provider.isBusy) {
      return const LoadingWidget();
    }
    if (!GlobalVar.checkListNotEmpty(provider.dataList)) {
      return ListView(
        children: const [
          NoDataAvailableWidget(),
        ],
      );
    }
    return ListView(
      children: provider.dataList.map((e) => ProductReviewSingleItem(e)).toList(),
    );
  }
}
