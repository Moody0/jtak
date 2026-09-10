import 'package:flutter/material.dart';
import 'package:app_jtak_warehouse/src/core/controllers/user_provider.dart';
import '../../../config/themes/app_theme.dart';
import '../../../utils/custom_widgets/base_view.dart';
import '../../../utils/custom_widgets/button.dart';
import '../../../utils/custom_widgets/dotted_separater.dart';
import '../../../utils/custom_widgets/messages.dart';
import '../../../utils/custom_widgets/text_field.dart';
import '../../../utils/utilities/global_var.dart';
import '../../../../main_imports.dart';

class ChangePasswordPage extends StatefulWidget {
  static const String routeName = '/ChangePasswordPage';

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  late UserProvider provider;
  @override
  Widget build(BuildContext context) {
    return BaseView<UserProvider>(
      modelProvider: UserProvider(),
      builder: (context, modelProvider) {
        provider = modelProvider;
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
                      padding: AppTheme.standardPadding,
                      child: Form(
                        key: formKey,
                        child: Column(
                          children: [
                            context.addHeight(16),
                            _oldPassword(),
                            context.addHeight(16),
                            _newPassword(),
                            context.addHeight(32),
                            _saveBTN(),
                            context.addHeight(16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _newPassword() {
    return PasswordTextFormField(
      lable: str.formAndAction.newPassword,
      onChanged: (value) {
        provider.newPassword = value.trim();
      },
    );
  }

  Widget _oldPassword() {
    return PasswordTextFormField(
      lable: str.formAndAction.oldPassword,
      onChanged: (value) {
        provider.oldPassword = value.trim();
      },
    );
  }

  ButtonWidget _saveBTN() {
    return ButtonWidget(
      text: str.formAndAction.save,
      onPressed: () => saveFun(),
      alignment: AlignmentDirectional.centerEnd,
      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 12),
      margin: EdgeInsets.zero,
    );
  }

  void saveFun() async {
    try {
      if (formKey.currentState?.validate() ?? false) {
        await provider.changePassword();
        context.showSnakBar(str.msg.saveSucceeded);
        context.pop();
      }
    } catch (err) {
      showDialog(context: context, builder: (context) => CustomDialog(message: err.toString()));
    }
  }

  AppBar _appBar() {
    return AppBar(
      title: Text(str.formAndAction.changePassword),
    );
  }
}
