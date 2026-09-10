import 'package:flutter/material.dart';
import 'package:jtek_app/src/config/themes/colors.dart';
import 'package:jtek_app/src/core/controllers/app_parameters_provider.dart';
import 'package:jtek_app/src/core/controllers/order/cart_provider.dart';
import 'package:jtek_app/src/core/controllers/user/address_provider.dart';
import 'package:jtek_app/src/core/models/catalog/product_model.dart';
import 'package:jtek_app/src/core/models/order/local_cart_item.dart';
import 'package:jtek_app/src/core/services/locator.dart';
import 'package:jtek_app/src/core/services/main_address_service.dart';
import 'package:jtek_app/src/ui/pages/address/add_address_page.dart';
import 'package:jtek_app/src/ui/pages/cart/cart_page.dart';
import 'package:jtek_app/src/utils/custom_widgets/messages.dart';
import 'package:jtek_app/src/utils/utilities/global_var.dart';
import 'package:provider/provider.dart';
import '../../../../main_imports.dart';

enum AddToCartType { circular, labelLarge }

class AddToCartButton extends StatefulWidget {
  final ProductModel item;
  final AddToCartType _type;
  final bool showSuccessMessage;

  const AddToCartButton.labelLarge(this.item, {this.showSuccessMessage = false}) : _type = AddToCartType.labelLarge;
  const AddToCartButton.circular(this.item, {this.showSuccessMessage = false}) : _type = AddToCartType.circular;

  @override
  State<AddToCartButton> createState() => _AddToCartButtonState();
}

class _AddToCartButtonState extends State<AddToCartButton> {
  late CartProvider cartProvider;
  LocalCartItem? cartItem;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    cartProvider = Provider.of<CartProvider>(context);
    cartItem = cartProvider.findItme(widget.item.id!, widget.item.merchantId ?? 0);
    switch (widget._type) {
      case AddToCartType.labelLarge:
        return _buttonWidget(context);
      case AddToCartType.circular:
        return _circularWidget(context);

      default:
        return _buttonWidget(context);
    }
  }

  Widget _buttonWidget(BuildContext context) {
    String btnTitle = cartItem != null ? '${str.app.addedToCart}  ( ${cartItem!.quantity} ) ${widget.item.unit}' : str.app.addToCart;
    return Align(
      alignment: Alignment.center,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.shopping_cart_rounded),
        label: Text('   $btnTitle   '),
        style: ElevatedButton.styleFrom(
          shape: const ContinuousRectangleBorder(
            borderRadius: BorderRadiusDirectional.only(
              topEnd: Radius.circular(35),
              bottomStart: Radius.circular(35),
            ),
          ),
        ),
        onPressed: () => addToCartFun(context, widget.item),
      ),
    );
  }

  Widget _circularWidget(BuildContext context) {
    double turns = 0;
    IconData icon = Icons.add;
    Color color = Colors.white;
    Color iconColor = kAccentColor;
    if (cartItem != null) {
      turns = 0.13;
      color = kAccentColor;
      iconColor = Colors.white;
    }

    double btnDimention = 50;

    return AnimatedRotation(
      turns: turns,
      duration: const Duration(milliseconds: 250),

      child: SizedBox(
        width: btnDimention,
        height: btnDimention,
        child: Material(
          type: MaterialType.circle,
          clipBehavior: Clip.antiAlias,
          color: Colors.transparent,
          child: InkWell(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Material(
                elevation: 2,
                type: MaterialType.circle,
                clipBehavior: Clip.antiAlias,
                color: color,
                child: Icon(icon, size: 20, color: iconColor),
              ),
            ),
            onTap: () async {
              if (cartItem != null) {
                await cartProvider.removeFromCart(widget.item.id!, widget.item.merchantId!);
              } else {
                await addToCartFun(context, widget.item);
              }
              setState(() {});
            },
          ),
        ),
      ),
      // child: CircularButton(
      //   child: Icon(icon, size: 20, color: iconColor),
      //   color: color,
      //   dimension: 30,
      //   onTap: () async {
      //     if (inCart) {
      //       await cartProvider.removeFromCart(widget.item.id!, widget.item.merchantId!);
      //     } else {
      //       await addToCartFun(context, widget.item);
      //     }
      //     setState(() {});
      //   },
      // ),
    );
  }

  Future addToCartFun(BuildContext context, ProductModel product) async {
    try {
      MainAddressService mainAddressService = locator<AppParametersProvider>().mainAddressService;
      if (mainAddressService.isAddressEmpty()) {
        locator<AddressProvider>().address = mainAddressService.mainAddress;

        await showDialog(context: context, builder: (context) => CustomDialog(message: str.msg.chooseLocationFirst));
        await context.navigatePage(const AddAddressPage());
      }
      if (!mainAddressService.isAddressEmpty()) {
        await cartProvider.addToCart(
          product.id!,
          product.merchantId!,
          product.finalPrice ?? 0.0,
        );
        if (widget.showSuccessMessage) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            // behavior: SnackBarBehavior.floating,
            content: Text(str.msg.addedToCartSuccessfully, style: const TextStyle(fontWeight: FontWeight.bold)),
            duration: const Duration(milliseconds: 2500),
            action: SnackBarAction(label: 'السلة', onPressed: () => context.navigateName(CartPage.routeName)),
          ));
        }
      }
    } catch (err) {
      showDialog(context: context, builder: (context) => CustomDialog(message: err.toString()));
    }
  }
}
