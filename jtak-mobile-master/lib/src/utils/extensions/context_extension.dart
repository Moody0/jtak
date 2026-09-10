import 'dart:math';

import 'package:flutter/material.dart';

import '../../../generated/locale_base.dart';
import '../custom_widgets/messages.dart';

extension StringLocalizationsExtension on BuildContext {
  LocaleBase? get str => Localizations.of<LocaleBase>(this, LocaleBase);
}

extension ContextExtension on BuildContext {
  MediaQueryData get mediaQuery => MediaQuery.of(this);

  TextTheme get textTheme => Theme.of(this).textTheme;
  TextTheme get primaryTextTheme => Theme.of(this).primaryTextTheme;

  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  ThemeData get appTheme => Theme.of(this);
  MaterialColor get randomColor => Colors.primaries[Random().nextInt(17)];

  bool get isKeyBoardOpen => MediaQuery.of(this).viewInsets.bottom > 0;
  Brightness get appBrightness => MediaQuery.of(this).platformBrightness;
}

extension MediaQueryExtension on BuildContext {
  double get height => mediaQuery.size.height;
  double get width => mediaQuery.size.width;
}

extension AddSpaceExtension on BuildContext {
  Widget addWidth(double width) => SizedBox(width: width);
  Widget addHeight(final double height) => SizedBox(height: height);
}

extension NavigationExtension on BuildContext {
  NavigatorState get navigation => Navigator.of(this);

  Future<void> pop({Object? data}) async => navigation.pop(data);

  void popUntil(String path, {Object? data}) => navigation.popUntil((route) => route.settings.name == path);

  Future<T?> navigateName<T>(String path, {Object? data}) async {
    return await navigation.pushNamed<T>(path, arguments: data);
  }

  Future<T?> navigateToReset<T>(String path, {Object? data}) async {
    return await navigation.pushNamedAndRemoveUntil(path, (route) {
      return route.settings.name == path;
    }, arguments: data);
  }

  Future<T> navigateDialog<T>(Widget dialog) async {
    return await navigation.push(
      MaterialPageRoute(
        builder: (BuildContext context) => dialog,
        fullscreenDialog: true,
        // this flag will provide out screen “close symbol” in the top left corner instead of the default “back arrow”.
        //  On iOS devices, it also affects swipe back behavior.
      ),
    );
  }

  Future<T> navigatePage<T>(Widget page) async {
    return await navigation.push(
      MaterialPageRoute(
        builder: (BuildContext context) => page,
      ),
    );
  }
}

extension ToastExtention on BuildContext {
  void showSnakBar(String? text, {int? milliseconds}) => ScaffoldMessenger.of(this).showSnackBar(
        SnackBarWidget.blankSnakBar(text ?? '', milliseconds: milliseconds),
      );
}
