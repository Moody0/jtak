import 'package:flutter/material.dart';

import '../../../main_imports.dart';
import '../../config/themes/app_theme.dart';
import '../utilities/global_var.dart';
import 'button.dart';

class CustomDialog extends StatelessWidget {
  final String? title;
  final String? message;
  final List<Widget>? actions;

  const CustomDialog({Key? key, this.title, this.message, this.actions}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      elevation: 25,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      title: title != null ? Text(title!, style: context.textTheme.headline6!.copyWith(fontSize: 16, fontWeight: FontWeight.w600)) : null,
      content: message != null && message!.isNotEmpty ? Text(message!, style: context.textTheme.subtitle2) : null,
      actions: actions ?? [TextButton(child: Text(str.main.ok), onPressed: () => Navigator.of(context).pop())],
    );
  }
}

class CustomConfirmationDialog extends StatelessWidget {
  final String? title;
  final String? message;
  final Function() yesBTNCallBack;

  const CustomConfirmationDialog({Key? key, this.title, this.message, required this.yesBTNCallBack}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      elevation: 25,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      title: title != null ? Text(title!, style: context.textTheme.headline5) : null,
      content: message != null && message!.isNotEmpty ? Text(message!, style: context.textTheme.bodyText1) : null,
      actions: <Widget>[
        TextButton(
          child: Text(str.main.ok),
          onPressed: yesBTNCallBack,
        ),
        TextButton(
          child: Text(str.main.cancel),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class ErrorCustomWidget extends StatelessWidget {
  final String errorMsg;
  final IconData icon;
  final Color? color;
  final double size;
  final bool showErrorWord;
  final Widget? action;
  const ErrorCustomWidget(
    this.errorMsg, {
    Key? key,
    this.icon = Icons.sentiment_very_dissatisfied,
    this.color,
    this.size = 80,
    this.showErrorWord = false,
    this.action,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const SizedBox(height: 25),
        Opacity(opacity: .5, child: Center(child: Icon(icon, color: color ?? context.appTheme.colorScheme.secondary, size: size))),
        showErrorWord
            ? Center(
                child: Padding(
                  padding: AppTheme.standardPadding,
                  child: Text(
                    '${str.msg.errorOccurred} ',
                    style: context.textTheme.headline5,
                  ),
                ),
              )
            : const SizedBox(),
        const SizedBox(height: 15),
        Center(
          child: Padding(
            padding: AppTheme.standardPadding,
            child: Text(
              ' $errorMsg',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyText1,
            ),
          ),
        ),
        action ?? const SizedBox(),
      ],
    );
  }
}

class DeleteConfermationDialog {
  void delete({required BuildContext context, required String explainMsg, required Function deleteFun}) {
    showDialog(
      context: context,
      builder: (context) => CustomDialog(
        title: str.msg.deleteConfermation,
        message: explainMsg,
        actions: <Widget>[
          TextButton(
              child: Text(str.main.yes),
              onPressed: () {
                Navigator.pop(context);
                deleteFun();
              }),
          ButtonWidget(
            text: str.main.no,
            onPressed: () => Navigator.pop(context),
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }
}

class SnackBarWidget {
  static SnackBar blankSnakBar(String text, {int? milliseconds = 1500}) {
    return SnackBar(
      // behavior: SnackBarBehavior.floating,
      content: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)), duration: Duration(milliseconds: milliseconds ?? 1500),
    );
  }
}
