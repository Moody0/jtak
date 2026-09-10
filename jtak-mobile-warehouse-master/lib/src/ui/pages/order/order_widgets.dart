import 'package:app_jtak_warehouse/src/config/constants/constants.dart';
import 'package:app_jtak_warehouse/src/config/themes/app_theme.dart';
import 'package:app_jtak_warehouse/src/config/themes/colors.dart';
import 'package:app_jtak_warehouse/src/core/controllers/order_provider.dart';
import 'package:app_jtak_warehouse/src/core/enums/order_details_status_enum.dart';
import 'package:app_jtak_warehouse/src/core/models/order_details_model.dart';
import 'package:app_jtak_warehouse/src/core/models/order_model.dart';
import 'package:app_jtak_warehouse/src/ui/widgets/price_widgets.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/image_widgets.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/messages.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/utilities/global_var.dart';
import '../../../../main_imports.dart';

class OrderSingleItem extends StatefulWidget {
  final OrderModel item;
  const OrderSingleItem(this.item);

  @override
  State<OrderSingleItem> createState() => _OrderSingleItemState();
}

class _OrderSingleItemState extends State<OrderSingleItem> {
  @override
  Widget build(BuildContext context) {
    OrderProvider provider = Provider.of<OrderProvider>(context);
    OrderDetailsStatus orderStatus = provider.getOrderStatus(widget.item);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 1),
      child: ExpansionTile(
        initiallyExpanded: orderStatus == OrderDetailsStatus.pending,
        title: _header(),
        children: _orderItems(),
        childrenPadding: const EdgeInsets.all(16),
        iconColor: kAccentColor,
        collapsedIconColor: kAccentColor,
      ),
    );
    // return Card(
    //   child: InkWell(
    //     // onTap: () => context.navigateName(OrderDetailsPage.routeName, data: item),
    //     child: Padding(
    //       padding: const EdgeInsets.all(8.0),
    //       child: Column(
    //         children: [
    //           ,
    //           _orderItems(),
    //         ],
    //       ),
    //     ),
    //   ),
    // );
  }

  Widget _header() {
    return Row(
      children: [
        Column(
          children: [
            Row(
              children: [
                PriceTextWidget.small(
                  price: widget.item.price,
                  currencyIntegerStyle: AppTheme.currencyIntegerStyleSmall.copyWith(fontSize: 18),
                ),
                context.addWidth(12),
                Text('#${widget.item.id}', style: context.textTheme.bodyText1),
              ],
            ),
            context.addHeight(8),
            Text(GlobalVar.dateForamt(widget.item.createdDate, kDateTimeFormat) ?? '', style: context.textTheme.bodyText1?.copyWith(fontSize: 16)),
          ],
        ),
        const Spacer(),
        _orderStatus(),
      ],
    );
  }

  Widget _orderStatus() {
    OrderProvider provider = Provider.of<OrderProvider>(context);
    OrderDetailsStatus orderStatus = provider.getOrderStatus(widget.item);
    if (orderStatus == OrderDetailsStatus.pending) {
      return Row(
        children: [
          OutlinedButton(
            // child: Icon(Icons.clear, color: kAccentColor),
            child: Text('✖', style: context.textTheme.headline3?.copyWith(color: kAccentColor, height: 0.8)),
            onPressed: () async {
              try {
                await provider.rejectOrder(widget.item);
              } catch (err) {
                showDialog(context: context, builder: (context) => CustomDialog(message: err.toString()));
              }
            },
          ),
          context.addWidth(12),
          ElevatedButton(
            child: Icon(Icons.check, color: Colors.white),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
            onPressed: () async {
              try {
                await provider.acceptOrder(widget.item);
              } catch (err) {
                showDialog(context: context, builder: (context) => CustomDialog(message: err.toString()));
              }
            },
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('حالة الطلب'),
        Text(provider.getOrderStatus(widget.item).value, style: context.textTheme.headline5),
      ],
    );
  }

  _orderItems() {
    return widget.item.orderDetails!.map((e) => OrderDetailsSingleItem(e)).toList();
    // return Column(
    //   children: widget.item.orderDetails!.map((e) => OrderDetailsSingleItem(e)).toList(),
    // );
  }
}

class OrderDetailsSingleItem extends StatelessWidget {
  final OrderDetailsModel item;
  const OrderDetailsSingleItem(this.item);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: InkWell(
        // onTap: () {
        //   context.navigateName(
        //     ProductDetailsPage.routeName,
        //     data: ProductModel(
        //       id: item.productId,
        //       title: item.productTitle,
        //       photos: item.productImage?.split(','),
        //     ),
        //   );
        // },
        child: Row(
          children: [
            _image(),
            context.addWidth(12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.productTitle ?? '', maxLines: 1, style: context.textTheme.headline4),
                  context.addHeight(4),
                  Row(
                    children: [
                      Text(item.productUnit ?? ''),
                      Text(' - '),
                      PriceTextWidget.small(
                        price: item.singleFinalPrice,
                        currencyIntegerStyle: AppTheme.currencyIntegerStyleSmall.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '${item.quantity} x ',
              style: context.textTheme.headline2?.copyWith(color: kAccentColor),
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
      ),
    );
  }

  Widget _image() {
    double cardHeight = 50;
    double imageWidth = cardHeight * 1;
    if (GlobalVar.checkString(item.productImage)) {
      return ImageView(item.productImage!.split(',').first, height: cardHeight, width: imageWidth);
    }
    return Image.asset(kNoImage, height: cardHeight, width: imageWidth);
  }
}
