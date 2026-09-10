import 'package:flutter/material.dart';
import 'package:jtek_app/src/core/controllers/app_parameters_provider.dart';
import 'package:jtek_app/src/core/controllers/user/address_provider.dart';
import 'package:jtek_app/src/core/controllers/user/user_provider.dart';
import 'package:jtek_app/src/core/enums/viewstate.dart';
import 'package:jtek_app/src/core/services/authentication_service.dart';
import 'package:jtek_app/src/ui/pages/account/phone_code_page.dart';
import 'package:jtek_app/src/ui/pages/cart/order_payment_page.dart';
import 'package:jtek_app/src/ui/widgets/phone_widget.dart';
import '../../../core/services/locator.dart';
import '../../../config/themes/app_theme.dart';
import '../../../core/controllers/order/cart_provider.dart';
import '../../../utils/custom_widgets/button.dart';
import '../../../utils/custom_widgets/loading.dart';
import '../../../utils/custom_widgets/messages.dart';
import '../../../utils/utilities/global_var.dart';
import '../../../utils/utilities/validation.dart';
import 'package:provider/provider.dart';
import '../../../../main_imports.dart';

class CheckOutPage extends StatefulWidget {
  static const String routeName = '/CheckOutPage';
  @override
  _CheckOutPageState createState() => _CheckOutPageState();
}

class _CheckOutPageState extends State<CheckOutPage> {
  late CartProvider provider;
  GlobalKey<FormState> formKey = GlobalKey<FormState>();

  @override
  void initState() {
    locator<CartProvider>().cartInfo.initData();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    provider = Provider.of<CartProvider>(context);
    return FullScreenLoading(
      inAsyncCall: provider.isBusy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(str.app.checkOut),
        ),
        body: SafeArea(
          child: ListView(
            children: [
              context.addHeight(16),
              _orderInfo(),
            ],
          ),
        ),
        bottomNavigationBar: _bottomSection(context),
      ),
    );
  }

  Widget _orderInfo() {
    return Card(
      child: Form(
        key: formKey,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _fullName(),
              context.addHeight(16),
              _phoneNumber(),
              context.addHeight(16),
              _address(),
              context.addHeight(16),
            ],
          ),
        ),
      ),
    );
  }

  TextFormField _fullName() {
    return TextFormField(
      initialValue: provider.cartInfo.name,
      keyboardType: TextInputType.name,
      decoration: AppTheme.getBorderdTextFieldDecoration(lable: str.formAndAction.name),
      validator: (value) => ValidationUtil.stringLengthValidation(value, str.msg.pleaseAddFullName),
      onChanged: (value) {
        provider.cartInfo.name = value.trim();
      },
    );
  }

  TextFormField _address() {
    return TextFormField(
      initialValue: provider.cartInfo.address,
      keyboardType: TextInputType.text,
      decoration: AppTheme.getBorderdTextFieldDecoration(lable: str.formAndAction.address),
      validator: (value) => ValidationUtil.stringLengthValidation(value, str.msg.pleaseAddAddress),
      onChanged: (value) {
        provider.cartInfo.address = value.trim();
      },
    );
  }

  Widget _phoneNumber() {
    return PhoneWidget(
      initValue: provider.cartInfo.phoneNumber,
      isEnabled: !locator<AuthenticationService>().isLogin(),
      onChanged: (phone) {
        provider.cartInfo.phoneNumber = phone;
      },
    );
  }

  Widget _bottomSection(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1))),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ButtonWidget(
                width: context.width * 0.7,
                text: str.main.continueWord,
                onPressed: provider.order.orderDetails?.isEmpty ?? true
                    ? null
                    : () async {
                        try {
                          if (formKey.currentState?.validate() ?? false) {
                            if (locator<AuthenticationService>().isLogin()) {
                              context.navigateName(OrderPaymentPage.routeName);
                            } else {
                              await quickRegisterByPhoneNumber();
                            }
                          }
                        } catch (err) {
                          provider.setState(ViewState.idle);
                          showDialog(context: context, builder: (context) => CustomDialog(message: err.toString()));
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> quickRegisterByPhoneNumber() async {
    provider.setState(ViewState.busy);
    await UserProvider().registerOrSignInByPhoneNumber(provider.cartInfo.phoneNumber.toString());
    provider.setState(ViewState.idle);
    context.showSnakBar(str.msg.smsCodeSend);
    var res = await context.navigateName(PhoneCodePage.routeName, data: provider.cartInfo.phoneNumber.toString());
    if (res is bool && res) {
      provider.setState(ViewState.busy);
      AddressProvider addressProvider = Provider.of<AddressProvider>(context, listen: false);
      addressProvider.address = locator<AppParametersProvider>().mainAddressService.mainAddress;
      addressProvider.saveFun();
      provider.setState(ViewState.busy);
      context.navigateName(OrderPaymentPage.routeName);
    }
  }
}
