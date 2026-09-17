import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../widgets/catalog/replace_cart_bottom_sheet.dart';
import '../../../../main_imports.dart';

enum AddToCartType { circular, labelLarge }

class AddToCartButton extends StatefulWidget {
  final ProductModel item;
  final AddToCartType _type;
  final bool showSuccessMessage;

  const AddToCartButton.labelLarge(this.item, {super.key, this.showSuccessMessage = false}) : _type = AddToCartType.labelLarge;
  const AddToCartButton.circular(this.item, {super.key, this.showSuccessMessage = false}) : _type = AddToCartType.circular;

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
    final mid = widget.item.merchantId ?? 0;
    cartItem = cartProvider.findItme(widget.item.id!, mid);

    switch (widget._type) {
      case AddToCartType.labelLarge:
        return _buttonWidget(context);
      case AddToCartType.circular:
        return _circularWidget(context);
    }
  }

  Widget _buttonWidget(BuildContext context) {
    if (cartItem != null && cartItem!.quantity > 0) {
      return Align(
        alignment: Alignment.center,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: kPrimaryOrange,
            borderRadius: const BorderRadiusDirectional.only(
              topEnd: Radius.circular(24),
              bottomStart: Radius.circular(24),
              topStart: Radius.circular(8),
              bottomEnd: Radius.circular(8),
            ),
            boxShadow: [
              BoxShadow(
                color: kPrimaryOrange.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const ValueKey('label_stepper_decrement_btn'),
                icon: const Icon(Icons.remove_rounded, color: Colors.white),
                onPressed: () => _onDecrement(context),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '${_addedToCartText()}  ( ${cartItem!.quantity} ) ${widget.item.unit ?? ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('label_stepper_increment_btn'),
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                onPressed: () => _onIncrement(context),
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.center,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.shopping_cart_rounded),
        label: Text('   ${_addToCartText()}   '),
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
    final inCart = cartItem != null && cartItem!.quantity > 0;
    final quantity = inCart ? cartItem!.quantity : 0;

    return GestureDetector(
      onTap: () {}, // Prevent tap bubbling to parent product card
      behavior: HitTestBehavior.opaque,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
        child: inCart
            ? _buildStepper(context, quantity)
            : _buildInitialAddButton(context),
      ),
    );
  }

  Widget _buildInitialAddButton(BuildContext context) {
    return SizedBox(
      key: const ValueKey('initial_add_btn'),
      width: 34,
      height: 34,
      child: Material(
        color: kPrimaryOrange,
        shape: const CircleBorder(),
        elevation: 1.5,
        shadowColor: kPrimaryOrange.withOpacity(0.35),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('circular_add_tap_target'),
          onTap: () async {
            HapticFeedback.lightImpact();
            await addToCartFun(context, widget.item);
          },
          child: const Center(
            child: Icon(
              Icons.add_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepper(BuildContext context, int quantity) {
    return Container(
      key: const ValueKey('quantity_stepper'),
      height: 34,
      constraints: const BoxConstraints(minWidth: 88, maxWidth: 96),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: kPrimaryOrange, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: kPrimaryOrange.withOpacity(0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Decrement button [-]
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: const ValueKey('stepper_decrement_btn'),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(17)),
                onTap: () => _onDecrement(context),
                child: const SizedBox(
                  width: 28,
                  height: 34,
                  child: Center(
                    child: Icon(
                      Icons.remove_rounded,
                      size: 18,
                      color: kPrimaryOrange,
                    ),
                  ),
                ),
              ),
            ),
            // Quantity text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '$quantity',
                key: ValueKey('stepper_qty_$quantity'),
                style: const TextStyle(
                  color: kCharcoalDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'IBMPlexSansArabic',
                ),
              ),
            ),
            // Increment button [+]
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: const ValueKey('stepper_increment_btn'),
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(17)),
                onTap: () => _onIncrement(context),
                child: const SizedBox(
                  width: 28,
                  height: 34,
                  child: Center(
                    child: Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: kPrimaryOrange,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onIncrement(BuildContext context) async {
    HapticFeedback.lightImpact();
    final mid = widget.item.merchantId ?? (cartItem?.merchantId ?? 0);
    await cartProvider.addToCart(
      widget.item.id!,
      mid,
      widget.item.canonicalSellingPrice,
      quantity: 1,
      title: widget.item.title,
      imageUrl: widget.item.photos?.firstOrNull,
      merchantTitle: widget.item.merchant,
    );
  }

  Future<void> _onDecrement(BuildContext context) async {
    HapticFeedback.lightImpact();
    if (cartItem == null) return;
    final mid = widget.item.merchantId ?? (cartItem?.merchantId ?? 0);
    if (cartItem!.quantity > 1) {
      await cartProvider.setToCart(
        widget.item.id!,
        mid,
        widget.item.canonicalSellingPrice,
        cartItem!.quantity - 1,
        title: widget.item.title,
        imageUrl: widget.item.photos?.firstOrNull,
        merchantTitle: widget.item.merchant,
      );
    } else {
      await cartProvider.removeFromCart(widget.item.id!, mid);
    }
  }

  Future addToCartFun(BuildContext context, ProductModel product) async {
    try {
      MainAddressService mainAddressService = locator<AppParametersProvider>().mainAddressService;
      if (mainAddressService.isAddressEmpty()) {
        locator<AddressProvider>().address = mainAddressService.mainAddress;

        await showDialog(context: context, builder: (context) => CustomDialog(message: _chooseLocationFirstText()));
        if (!context.mounted) return;
        await context.navigatePage(const AddAddressPage());
        if (!context.mounted) return;
      }
      if (!mainAddressService.isAddressEmpty() && context.mounted) {
        final mid = product.merchantId ?? 0;
        if (cartProvider.isDifferentMerchant(mid)) {
          final shouldReplace = await ReplaceCartBottomSheet.show(
            context,
            currentStoreName: cartProvider.getConflictingMerchantName(mid),
            newStoreName: (product.merchant != null && product.merchant!.isNotEmpty)
                ? product.merchant!.split(' - ').first
                : 'المتجر الجديد',
          );
          if (shouldReplace != true || !context.mounted) return;
          await cartProvider.replaceCartWithItem(
            product.id!,
            mid,
            product.canonicalSellingPrice,
            1,
            title: product.title,
            imageUrl: product.photos?.firstOrNull,
            merchantTitle: product.merchant,
          );
          if (widget.showSuccessMessage && context.mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(_addedSuccessText(), style: const TextStyle(fontWeight: FontWeight.bold)),
              duration: const Duration(milliseconds: 2500),
              action: SnackBarAction(label: 'السلة', onPressed: () => context.navigateName(CartPage.routeName)),
            ));
          }
          return;
        }

        await cartProvider.addToCart(
          product.id!,
          mid,
          product.canonicalSellingPrice,
          title: product.title,
          imageUrl: product.photos?.firstOrNull,
          merchantTitle: product.merchant,
        );
        if (widget.showSuccessMessage && context.mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_addedSuccessText(), style: const TextStyle(fontWeight: FontWeight.bold)),
            duration: const Duration(milliseconds: 2500),
            action: SnackBarAction(label: 'السلة', onPressed: () => context.navigateName(CartPage.routeName)),
          ));
        }
      }
    } catch (err) {
      if (context.mounted) {
        showDialog(context: context, builder: (context) => CustomDialog(message: err.toString()));
      }
    }
  }

  String _addedToCartText() {
    try {
      return str.app.addedToCart;
    } catch (_) {
      return 'تمت الإضافة إلى السلة';
    }
  }

  String _addToCartText() {
    try {
      return str.app.addToCart;
    } catch (_) {
      return 'إضافة إلى السلة';
    }
  }

  String _chooseLocationFirstText() {
    try {
      return str.msg.chooseLocationFirst;
    } catch (_) {
      return 'يرجى تحديد موقع التوصيل أولاً';
    }
  }

  String _addedSuccessText() {
    try {
      return str.msg.addedToCartSuccessfully;
    } catch (_) {
      return 'تمت إضافة المنتج إلى السلة بنجاح';
    }
  }
}
