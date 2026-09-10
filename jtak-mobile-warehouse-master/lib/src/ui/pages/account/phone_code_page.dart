import 'package:app_jtak_warehouse/src/config/themes/app_theme.dart';
import 'package:app_jtak_warehouse/src/config/themes/colors.dart';
import 'package:app_jtak_warehouse/src/core/controllers/user_provider.dart';
import 'package:app_jtak_warehouse/src/ui/widgets/code_input_widget.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/base_view.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/button.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/dotted_separater.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/messages.dart';
import 'package:app_jtak_warehouse/src/utils/utilities/global_var.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../main_imports.dart';

class PhoneCodePage extends StatefulWidget {
  static const String routeName = '/PhoneCodePage';
  final String phoneNumber;
  const PhoneCodePage(this.phoneNumber);
  @override
  _PhoneCodePageState createState() => _PhoneCodePageState();
}

class _PhoneCodePageState extends State<PhoneCodePage> {
  String _code = '';
  late UserProvider userProvider;

  @override
  Widget build(BuildContext context) {
    return BaseView<UserProvider>(
      modelProvider: UserProvider(),
      builder: (context, modelProvider) {
        userProvider = modelProvider;
        return Scaffold(
          appBar: AppBar(title: Text(str.formAndAction.activationCode)),
          body: SafeArea(
            child: FullScreenLoading(
              inAsyncCall: userProvider.isBusy,
              child: ListView(
                padding: AppTheme.standardPadding,
                children: [
                  context.addHeight(32),
                  _infoWidget(),
                  _codeForm(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _infoWidget() {
    int phoneLength = widget.phoneNumber.length;
    String number = widget.phoneNumber.substring(0, 5);
    number += List<String>.generate(phoneLength - 8, (index) => '*').join();
    number += widget.phoneNumber.substring(phoneLength - 3, phoneLength);
    return Column(
      children: [
        Text(str.formAndAction.enterCodeSended, style: context.textTheme.bodyText1),
        context.addHeight(8),
        Text(
          number,
          style: context.textTheme.headline4!.copyWith(letterSpacing: 1),
          textDirection: TextDirection.ltr,
        ),
      ],
    );
  }

  Widget _codeForm() {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 16, top: 45),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CodeInputWidget(
            onChange: (code) => _code = code,
            onEnd: (code) {
              _code = code;
              loginFun();
            },
          ),
          context.addHeight(16),
          _resendWidget(),
          context.addHeight(48),
          ButtonWidget(
            text: str.formAndAction.send,
            onPressed: loginFun,
            width: double.infinity,
            color: kAccentColor,
          ),
        ],
      ),
    );
  }

  Widget _resendWidget() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(CupertinoIcons.refresh_thin, color: Colors.grey.shade700, size: 18),
        context.addWidth(8),
        GestureDetector(
          child: Text(
            str.formAndAction.resendCode,
            style: AppTheme.linkStyle.copyWith(color: Colors.grey.shade700, height: 2),
          ),
          onTap: resendCodeFun,
        ),
      ],
    );
  }

  void loginFun() async {
    try {
      if (_code.length == 6) {
        await userProvider.loginByPhone(widget.phoneNumber, _code);
        Navigator.pop(context, true);
      }
    } catch (err) {
      showDialog(context: context, builder: (context) => CustomDialog(message: err.toString()));
    }
  }

  void resendCodeFun() async {
    try {
      await userProvider.resendSmsCode(widget.phoneNumber);
      context.showSnakBar(str.msg.smsCodeSend);
    } catch (err) {
      showDialog(context: context, builder: (context) => CustomDialog(message: err.toString()));
    }
  }
}
