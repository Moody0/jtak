import 'package:flutter/material.dart';
import 'package:jtek_app/src/utils/custom_widgets/button.dart';
import 'package:lottie/lottie.dart';
import '../../config/constants/constants.dart';
import '../../config/themes/app_theme.dart';
import '../../config/themes/colors.dart';
import '../../utils/utilities/global_var.dart';
import '../../../main_imports.dart';

class AppBarWidget {
  static PreferredSizeWidget getAppBar({Widget? leading, Function()? onChange}) {
    return AppBar(
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GestureDetector(
              onTap: onChange,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Image.asset(kLogo2),
              )),
        )
      ],
      leading: leading,
      leadingWidth: 250,
    );
  }
}

class NoDataAvailableWidget extends StatelessWidget {
  final String? msg;
  final Widget? image;
  const NoDataAvailableWidget({this.msg, this.image});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          image ?? Image.asset(kAssetsImageBase + ('no_data_available.png'), color: kAccentColor, height: 100),
          Center(child: Text(msg ?? str.msg.noDataAvailable, style: context.textTheme.bodyLarge!.copyWith(color: kAccentColor.withOpacity(0.7)))),
        ],
      ),
    );
  }
}

class TextFormFieldWidget extends StatelessWidget {
  final String? initialValue;
  final String? lable;
  final String? hint;
  final void Function(String value)? onChanged;
  final String? Function(String?)? validator;

  const TextFormFieldWidget({this.initialValue, this.lable, this.hint, this.onChanged, this.validator});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      decoration: AppTheme.getBorderdTextFieldDecoration(lable: lable, hint: hint),
      onChanged: onChanged,
      validator: validator,
    );
  }
}

class SuccessDialog extends StatelessWidget {
  final String message;
  const SuccessDialog({required this.message});
  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      alignment: Alignment.center,
      children: [
        Lottie.asset(kAssetsAnimationBase + 'check.json', height: 150, repeat: false),
        context.addHeight(24),
        Center(child: Text(message, style: context.textTheme.headlineMedium)),
        context.addHeight(24),
        ButtonWidget(
          text: str.main.ok,
          alignment: Alignment.center,
          onPressed: () {
            context.pop();
          },
        ),
      ],
    );
  }
}

/// Renders icons in their true, un-mirrored orientation in RTL locales.
class AppIcon extends StatelessWidget {
  final IconData? icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  const AppIcon(
    this.icon, {
    Key? key,
    this.size,
    this.color,
    this.semanticLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (icon == null) return const SizedBox.shrink();
    return Icon(
      icon,
      size: size,
      color: color,
      semanticLabel: semanticLabel,
      textDirection: TextDirection.ltr,
    );
  }
}
