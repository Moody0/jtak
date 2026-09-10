import 'dart:math';

import 'package:app_jtak_delivery/main.dart';
import 'package:flutter/material.dart';
import '../custom_widgets/messages.dart';

import '../../../generated/locale_base.dart';

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
  Widget addHeight(double height) => SizedBox(height: height);
}

extension NavigationExtension on BuildContext {
  NavigatorState get navigation => Navigator.of(this);

  Future<void> pop() async => navigation.pop();

  Future<T?> navigateName<T>(String path, {Object? data}) async {
    return await navigation.pushNamed<T>(path, arguments: data);
  }

  Future<T?> navigateToReset<T>(String path, {String untilPath = MyApp.routeName, Object? data}) async {
    return await Navigator.of(this).pushNamedAndRemoveUntil(path, ModalRoute.withName(untilPath), arguments: data);
  }

  Future<T?> pushReplacementNamed<T>(String path, {Object? data}) async {
    return await Navigator.of(this).pushReplacementNamed(path, arguments: data);
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

extension TextThemeCompatExtension on TextTheme {
  TextStyle? get headline1 => displayLarge;
  TextStyle? get headline2 => displayMedium;
  TextStyle? get headline3 => displaySmall;
  TextStyle? get headline4 => headlineMedium;
  TextStyle? get headline5 => headlineSmall;
  TextStyle? get headline6 => titleLarge;
  TextStyle? get subtitle1 => titleMedium;
  TextStyle? get subtitle2 => titleSmall;
  TextStyle? get bodyText1 => bodyLarge;
  TextStyle? get bodyText2 => bodyMedium;
  TextStyle? get caption => bodySmall;
  TextStyle? get button => labelLarge;
  TextStyle? get overline => labelSmall;
}
