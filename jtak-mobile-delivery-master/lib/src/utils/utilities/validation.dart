import 'global_var.dart';

class ValidationUtil {
  ////////////////{ Email Validation } ////////////////
  static final RegExp emailValidatorRegExp = RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
  static const String emailRegExp =
      r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';

  static String? emailValidation(String? email, [bool requird = true]) {
    RegExp regExp = RegExp(emailRegExp);
    if (email?.isEmpty ?? true) {
      if (requird) return str.msg.enterEmail;
    } else {
      if (!regExp.hasMatch(email!)) return str.msg.invalidEmail;
    }
    return null;
  }

  ////////////////{ Phone Validation } ////////////////
  static const String phoneRegExp = r'^[+]*[(]{0,1}[0-9]{1,4}[)]{0,1}[-\s\./0-9]*$';
  static String? phoneValidation(String? phone, [bool requird = true]) {
    RegExp regExp = RegExp(phoneRegExp);
    if (phone?.isEmpty ?? true) {
      if (requird) return str.msg.enterPhone;
    } else {
      if (!regExp.hasMatch(phone!)) return str.msg.invalidPhone;
    }
    return null;
  }

  ////////////////{ Length Validation } ////////////////
  static String? stringLengthValidation(String? value, String msg, {requirLength = 5}) {
    return value == null || (value.isEmpty || value.length < requirLength) ? msg : null;
  }
}
