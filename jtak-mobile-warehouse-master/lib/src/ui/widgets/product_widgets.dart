import 'package:app_jtak_warehouse/src/config/constants/app_constant.dart';
import 'package:app_jtak_warehouse/src/config/themes/app_theme.dart';
import 'package:app_jtak_warehouse/src/config/themes/colors.dart';
import 'package:app_jtak_warehouse/src/core/controllers/products_provider.dart';
import 'package:app_jtak_warehouse/src/core/models/product_model.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/image_widgets.dart';
import 'package:app_jtak_warehouse/src/utils/utilities/global_var.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../main_imports.dart';

class ProductSingleItem extends StatefulWidget {
  final ProductModel item;
  const ProductSingleItem(this.item);

  @override
  State<ProductSingleItem> createState() => _ProductSingleItemState();
}

class _ProductSingleItemState extends State<ProductSingleItem> {
  late TextEditingController _amountTextEditingController;
  final _amountFocusNode = FocusNode();

  @override
  void initState() {
    _amountTextEditingController = TextEditingController(text: '0.0');
    _amountFocusNode.addListener(() {
      if (_amountFocusNode.hasFocus) {
        _amountTextEditingController.selection = TextSelection(baseOffset: 0, extentOffset: _amountTextEditingController.text.length);
      }
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ProductsProvider provider = Provider.of<ProductsProvider>(context);
    double cardHeight = 60;
    double imageWidth = cardHeight * kAppAspectRatio;
    return InkWell(
      // onTap: () => context.navigateName(ProductDetailsPage.routeName, data: item),
      child: Container(
        margin: EdgeInsets.all(4),
        color: Colors.grey.shade100,
        child: Row(
          children: [
            ImageView(widget.item.productPhotos?.split(',').first, height: cardHeight, width: imageWidth, fit: BoxFit.cover),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.item.product ?? '', style: context.textTheme.headline6, maxLines: 3)),
            _resetPrice(context, provider),
            _priceWidget(context, provider),
          ],
        ),
      ),
    );
  }

  Widget _resetPrice(BuildContext context, ProductsProvider provider) {
    return ValueListenableBuilder<Map<int, double>>(
      valueListenable: provider.newPricesMap,
      builder: (context, Map<int, double> newPricesMap, child) {
        if (newPricesMap.containsKey(widget.item.productId)) {
          return InkWell(
            child: Icon(CupertinoIcons.refresh_bold, color: kAccentColor),
            onTap: () {
              provider.resetPrice(widget.item.productId!);
            },
          );
        }
        return const SizedBox();
      },
    );
  }

  Widget _priceWidget(BuildContext context, ProductsProvider provider) {
    _amountTextEditingController.text = (provider.newPricesMap.value[widget.item.productId] ?? widget.item.finalPrice).toString();
    return Container(
      width: 75,
      margin: EdgeInsets.only(right: 8, left: 12),
      child: TextFormField(
        controller: _amountTextEditingController,
        key: GlobalKey(),
        focusNode: _amountFocusNode,
        decoration: AppTheme.getBorderdTextFieldDecoration(hint: 'السعر').copyWith(
          errorStyle: TextStyle(fontSize: 9),
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        textAlign: TextAlign.end,
        keyboardType: TextInputType.number,
        validator: (value) => double.tryParse(value ?? '') == null ? str.msg.fillFieldNumber : null,
        onChanged: (val) {
          double newPrice = double.tryParse(val.trim()) ?? widget.item.finalPrice ?? 0.0;
          provider.setNewPrice(widget.item, newPrice);
        },
      ),
    );
  }
}
