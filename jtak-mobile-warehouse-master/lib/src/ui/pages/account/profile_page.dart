import 'package:app_jtak_warehouse/src/core/services/authentication_service.dart';
import 'package:app_jtak_warehouse/src/core/services/locator.dart';
import 'package:app_jtak_warehouse/src/ui/pages/account/login_page.dart';
import 'package:flutter/material.dart';
import 'package:app_jtak_warehouse/src/core/controllers/user_provider.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/phone_widget.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/widgets.dart';
import '../../../config/themes/app_theme.dart';
import '../../../config/themes/colors.dart';
import '../../../utils/custom_widgets/base_view.dart';
import '../../../utils/custom_widgets/button.dart';
import '../../../utils/custom_widgets/dotted_separater.dart';
import '../../../utils/custom_widgets/messages.dart';
import '../../../utils/utilities/global_var.dart';
import '../../../../main_imports.dart';

class ProfilePage extends StatefulWidget {
  static const String routeName = '/ProfilePage';

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  bool _isPhoneNumberValid = true;
  @override
  Widget build(BuildContext context) {
    return BaseView<UserProvider>(
      modelProvider: UserProvider(),
      onModelReady: (modelProvider) => modelProvider.loadUserDataProfile(),
      builder: (context, modelProvider) {
        return FullScreenLoading(
          inAsyncCall: modelProvider.isBusy,
          child: Scaffold(
            appBar: _appBar(),
            body: SafeArea(
              child: ListView(
                children: [
                  context.addHeight(16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Form(
                        key: formKey,
                        child: Column(
                          children: [
                            Text(str.main.personalInfo, style: context.textTheme.headline4),
                            context.addHeight(32),
                            _fullName(modelProvider),
                            context.addHeight(24),
                            _phoneNumber(modelProvider, context),
                            context.addHeight(32),
                            _saveBTN(context, modelProvider),
                            context.addHeight(16),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Divider(),
                  _logoutWidget(kPrimaryColor, context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  TextFormField _fullName(UserProvider modelProvider) {
    return TextFormField(
      initialValue: modelProvider.authService.user?.fullName,
      keyboardType: TextInputType.name,
      decoration: AppTheme.getBorderdTextFieldDecoration(lable: str.formAndAction.fullName),
      onChanged: (value) {
        modelProvider.fullName = value.trim();
      },
    );
  }

  Widget _phoneNumber(UserProvider modelProvider, BuildContext context) {
    return PhoneWidget(
      initValue: modelProvider.phoneNumber,
      onInputValidated: (isValid) => _isPhoneNumberValid = isValid,
      isEnabled: false,
      onChanged: (phone) {
        modelProvider.phoneNumber = phone;
      },
    );
  }

  ListTile _logoutWidget(Color iconColor, BuildContext context) {
    bool isLogin = locator<AuthenticationService>().isLogin();
    String title = isLogin ? str.formAndAction.logout : str.formAndAction.logIn;
    return ListTile(
      leading: Icon(Icons.reviews, color: iconColor),
      title: Text(title),
      trailing: const ArrowWidget(),
      onTap: () {
        if (isLogin) {
          showDialog(
            context: context,
            builder: (context) => CustomConfirmationDialog(
              title: str.formAndAction.logout,
              message: str.msg.logoutConfirm,
              yesBTNCallBack: () async {
                await locator<AuthenticationService>().logOut();
                context.navigateToReset(LoginPage.routeName);
              },
            ),
          );
        } else {
          context.navigateName(LoginPage.routeName);
        }
      },
    );
  }

  ButtonWidget _saveBTN(BuildContext context, UserProvider modelProvider) {
    return ButtonWidget(
      text: str.formAndAction.save,
      onPressed: () => saveFun(context, modelProvider),
      alignment: AlignmentDirectional.centerEnd,
      margin: EdgeInsets.zero,
    );
  }

  void saveFun(BuildContext context, UserProvider modelProvider) async {
    try {
      if (formKey.currentState!.validate() && _isPhoneNumberValid) {
        await modelProvider.update();
        context.showSnakBar(str.msg.saveSucceeded);
        context.pop();
      }
    } catch (err) {
      showDialog(context: context, builder: (context) => CustomDialog(message: err.toString()));
    }
  }

  AppBar _appBar() {
    return AppBar(
      title: Text(str.main.profile),
    );
  }
}
