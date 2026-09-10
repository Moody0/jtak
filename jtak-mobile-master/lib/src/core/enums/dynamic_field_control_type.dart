enum DynamicFieldControlType { string, number }

extension ParseInt on int {
  DynamicFieldControlType get getEnum {
    switch (this) {
      case 0:
        return DynamicFieldControlType.string;
      case 1:
        return DynamicFieldControlType.number;

      default:
        return DynamicFieldControlType.string;
    }
  }
}
