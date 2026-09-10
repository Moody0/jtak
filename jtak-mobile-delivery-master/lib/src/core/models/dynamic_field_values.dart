import 'dart:convert';

import 'package:app_jtak_delivery/src/core/enums/dynamic_field_control_type.dart';

class DynamicFieldValuesModel {
  String? displayName;
  DynamicFieldControlType? controlType;
  String? value;
  DynamicFieldValuesModel({
    this.displayName,
    this.controlType,
    this.value,
  });

  DynamicFieldValuesModel copyWith({
    String? displayName,
    DynamicFieldControlType? controlType,
    String? value,
  }) {
    return DynamicFieldValuesModel(
      displayName: displayName ?? this.displayName,
      controlType: controlType ?? this.controlType,
      value: value ?? this.value,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'controlType': controlType?.index,
      'value': value,
    };
  }

  factory DynamicFieldValuesModel.fromMap(Map<String, dynamic> map) {
    return DynamicFieldValuesModel(
      displayName: map['displayName'],
      controlType: (map['controlType'] as int).getEnum,
      value: map['value'],
    );
  }

  String toJson() => json.encode(toMap());

  factory DynamicFieldValuesModel.fromJson(String source) => DynamicFieldValuesModel.fromMap(json.decode(source));

  @override
  String toString() => 'DynamicFieldValues(displayName: $displayName, controlType: $controlType, value: $value)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DynamicFieldValuesModel && other.displayName == displayName && other.controlType == controlType && other.value == value;
  }

  @override
  int get hashCode => displayName.hashCode ^ controlType.hashCode ^ value.hashCode;
}
