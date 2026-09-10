import 'package:app_jtak_warehouse/src/config/constants/app_constant.dart';
import 'package:app_jtak_warehouse/src/config/themes/colors.dart';
import 'package:app_jtak_warehouse/src/core/controllers/user_provider.dart';
import 'package:app_jtak_warehouse/src/core/models/phone_number_model.dart';
import 'package:app_jtak_warehouse/src/core/services/authentication_service.dart';
import 'package:app_jtak_warehouse/src/core/services/locator.dart';
import 'package:app_jtak_warehouse/src/ui/pages/account/phone_code_page.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/init_widget.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/phone_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../main_imports.dart';
import '../../../config/themes/app_theme.dart';
import '../../../utils/custom_widgets/base_view.dart';
import '../../../utils/custom_widgets/button.dart';
import '../../../utils/custom_widgets/loading.dart';
import '../../../utils/custom_widgets/messages.dart';
import '../../../utils/utilities/global_var.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);
  static const String routeName = '/LoginPage';
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  PhoneNumberModel _phoneNumber = PhoneNumberModel();
  bool _isPhoneNumberValid = true;
  late UserProvider userProvider;

  @override
  void initState() {
    if (kDebugMode) {
      _phoneNumber = PhoneNumberModel(
        phoneNumber: '+905555555552',
        dialCode: kCountryPhoneCodeDefualt,
        isoCode: kCountriesCode[kCountryPhoneCodeDefualt],
      );
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(str.formAndAction.logIn)),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: BaseView<UserProvider>(
          modelProvider: UserProvider(),
          builder: (context, modelNotifier) {
            userProvider = modelNotifier;
            return FullScreenLoading(
              inAsyncCall: userProvider.isBusy,
              child: ListView(
                padding: AppTheme.standardPadding,
                children: [
                  context.addHeight(32),
                  _infoWidget(),
                  _phoneNumberForm(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _infoWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تسجيل الدخول من خلال رقمك الهاتف',
          style: context.textTheme.headline3!.copyWith(color: kAccentColor, fontWeight: FontWeight.bold),
        ),
        context.addHeight(8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info, size: 20, color: Colors.grey.shade700),
            context.addWidth(8),
            Expanded(
              child: Text(
                'يتم بعدها ارسال كود تسجله في الصفحة التالي',
                style: context.textTheme.bodyText1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _phoneNumberForm() {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 16, top: 45),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhoneWidget(
            initValue: _phoneNumber,
            onChanged: (phone) => _phoneNumber = phone,
            onInputValidated: (isValid) => _isPhoneNumberValid = isValid,
          ),
          context.addHeight(64),
          ButtonWidget(
            text: str.formAndAction.logIn,
            onPressed: registerOrSignInByPhoneNumber,
            width: double.infinity,
            color: kAccentColor,
          ),
        ],
      ),
    );
  }

  void registerOrSignInByPhoneNumber() async {
    try {
      if (_isPhoneNumberValid) {
        await userProvider.registerOrSignInByPhoneNumber(_phoneNumber.phoneNumber!);
        context.showSnakBar(str.msg.smsCodeSend);
        var res = await context.navigateName(PhoneCodePage.routeName, data: _phoneNumber.toString());
        if (res is bool && res) {
          AuthenticationService authenticationService = locator<AuthenticationService>();
          if (authenticationService.user!.role == null || authenticationService.user!.role != kMerchantRole) {
            showDialog(context: context, builder: (context) => CustomDialog(message: 'يرجى تسجيل الدخول كتاجر'));
            authenticationService.logOut();
          } else {
            InitWidget.restartApp(context);
          }
        }
      } else {
        setState(() {});
      }
    } catch (err) {
      showDialog(context: context, builder: (context) => CustomDialog(message: err.toString()));
    }
  }
}
