import '../../utils/utilities/global_var.dart';

enum AddressType { shipping, billing }

extension StringValueExtention on AddressType {
  String get value {
    switch (this) {
      case AddressType.shipping:
        return str.app.shippingAddress;

      case AddressType.billing:
        return str.app.billingAddress;

      default:
        return '';
    }
  }
}

extension ParseEnumExtention on int {
  AddressType get parseAddressType {
    switch (this) {
      case 0:
        return AddressType.shipping;
      case 1:
        return AddressType.billing;

      default:
        return AddressType.shipping;
    }
  }
}
