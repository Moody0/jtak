enum ThemeType { dark, light }

extension StringValue on ThemeType {
  String get value {
    switch (this) {
      case ThemeType.light:
        return 'light Theme';
      case ThemeType.dark:
        return 'dark Theme';

      default:
        return '';
    }
  }
}
