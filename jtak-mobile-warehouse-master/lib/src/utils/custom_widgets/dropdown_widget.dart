import 'dart:developer';

import 'package:flutter/material.dart';

import '../../../main_imports.dart';
import '../../config/themes/app_theme.dart';
import '../../config/themes/colors.dart';
import '../utilities/global_var.dart';

class DropDownWidget<T> extends StatefulWidget {
  final List<T> dataList;
  final T? initValue;
  final Function(T item) onChange;
  final Function(T item)? itemToString;
  final String? hint;
  final bool isExpanded;
  final TextStyle? textStyle;
  final TextStyle? selectedTextStyle;
  final double borderRadius;
  final bool buttonShape;
  final Color buttonShapeColor;
  final bool borderShap;
  final Color borderColor;
  final Widget? underLine;
  final bool disabled;

  DropDownWidget({
    required this.dataList,
    required this.onChange,
    this.initValue,
    this.itemToString,
    this.hint,
    this.isExpanded = true,
    this.textStyle,
    this.selectedTextStyle,
    this.borderRadius = 4,
    this.buttonShape = false,
    this.buttonShapeColor = kAccentColor,
    this.borderShap = false,
    this.borderColor = kGreyLight,
    this.underLine,
    this.disabled = false,
  });

  @override
  State<DropDownWidget<T>> createState() => _DropDownWidgetState<T>();
}

class _DropDownWidgetState<T> extends State<DropDownWidget<T>> {
  T? selectedValue;

  @override
  void initState() {
    selectedValue = widget.initValue;
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant DropDownWidget<T> oldWidget) {
    selectedValue = widget.initValue;
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.buttonShape) {
      return _btnShape(_buildDropdownButton());
    } else if (widget.borderShap) {
      return _borderShape(_buildDropdownButton());
    } else {
      return _buildDropdownButton();
    }
  }

  Widget _buildDropdownButton() {
    return DropdownButton<T>(
      value: selectedValue,
      style: widget.textStyle,
      hint: widget.hint != null ? Text(widget.hint ?? '', style: widget.textStyle) : null,
      isDense: true,
      isExpanded: widget.isExpanded,
      borderRadius: BorderRadius.circular(widget.borderRadius),
      onTap: () => log('DropdownButton on tap'),
      underline: widget.buttonShape || widget.borderShap ? const SizedBox() : widget.underLine,
      items: widget.dataList
          .map((e) => DropdownMenuItem(
                child: _singleItem(e),
                value: e,
              ))
          .toList(),
      onChanged: widget.disabled
          ? null
          : (value) {
              setState(() => selectedValue = value);
              if (value != null) widget.onChange(value);
            },
      selectedItemBuilder: (context) {
        return widget.dataList.map<Widget>((e) => _singleItem(e, widget.selectedTextStyle)).toList();
      },
    );
  }

  Widget _singleItem(T item, [TextStyle? textStyle]) {
    return Center(
      child: Text(
        (widget.itemToString != null ? widget.itemToString!(item) : item.toString()) ?? '',
        style: textStyle ?? widget.textStyle,
      ),
    );
  }

  Widget _borderShape(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: widget.borderColor),
      ),
      child: child,
    );
  }

  Widget _btnShape(Widget child) {
    return Material(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      shadowColor: widget.buttonShapeColor.withOpacity(.6),
      color: widget.buttonShapeColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: child,
      ),
    );
  }
}

class DropdownWidgetq extends StatefulWidget {
  final List<dynamic> dataList;
  final Function(dynamic item) onChange;
  final Function(dynamic item)? itemToString;
  final dynamic initValue;
  final String? hint;
  final bool isExpanded;
  final TextStyle textStyle;
  final double? itemHeight;
  final Widget? underline;
  final bool buttonShape;
  final Color buttonShapeColor;
  final double borderRadius;
  final double elevation;
  final bool disabled;
  final TextStyle? selectedTextStyle;
  final Function? addItemFun;
  final Widget? icon;

  final bool borderShap;
  final Color borderColor;

  const DropdownWidgetq({
    Key? key,
    required this.dataList,
    required this.onChange,
    this.itemToString,
    this.initValue,
    this.hint,
    this.isExpanded = true,
    this.textStyle = const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    this.itemHeight,
    this.underline,
    this.buttonShape = false,
    this.buttonShapeColor = kAccentColor,
    this.borderRadius = AppTheme.borderRadiusValue,
    this.elevation = 1,
    this.disabled = false,
    this.addItemFun,
    this.borderShap = false,
    this.selectedTextStyle,
    this.icon,
    this.borderColor = Colors.grey,
  }) : super(key: key);

  @override
  _DropdownWidgetqState createState() => _DropdownWidgetqState();
}

class _DropdownWidgetqState extends State<DropdownWidgetq> {
  dynamic value;
  dynamic tempInitValue;
  List<dynamic> localDataList = [];

  @override
  void initState() {
    tempInitValue = widget.initValue;
    value = widget.initValue;
    localDataList = widget.dataList.toList();
    if (widget.addItemFun != null) localDataList.add(null);
    super.initState();
  }

  void checkDataUpdate() {
    if (tempInitValue != widget.initValue) {
      tempInitValue = widget.initValue;
      value = widget.initValue;
    }
    if (widget.dataList.contains(value)) value = null;
    int addedItem = 0;
    if (widget.addItemFun != null) addedItem++;
    if (widget.dataList.length != localDataList.length - addedItem) {
      localDataList.removeWhere((element) => element != null);
      localDataList.insertAll(0, widget.dataList);
    }
  }

  @override
  Widget build(BuildContext context) {
    checkDataUpdate();
    if (widget.buttonShape) {
      return _btnShape(_buildDropdownButton());
    } else if (widget.borderShap) {
      return _borderShape(_buildDropdownButton());
    } else {
      return _buildDropdownButton();
    }
  }

  Widget _buildDropdownButton() {
    return DropdownButton<dynamic>(
      itemHeight: widget.itemHeight,
      isDense: false,
      icon: widget.icon,
      underline: widget.buttonShape || widget.borderShap ? const SizedBox() : widget.underline,
      isExpanded: widget.isExpanded,
      value: value,
      items: localDataList
          .map(
            (e) => DropdownMenuItem<dynamic>(
              child: _singleItem(e, widget.textStyle),
              value: e,
              alignment: AlignmentDirectional.center,
            ),
          )
          .toList(),
      onChanged: widget.disabled
          ? null
          : (value) {
              if (value != null) {
                setState(() {
                  this.value = value;
                  widget.onChange(value);
                });
              } else if (widget.addItemFun != null) {
                widget.addItemFun!();
              }
            },
      selectedItemBuilder: (context) {
        return localDataList.map<Widget>((e) => Text(e.toString(), style: TextStyle(color: Colors.red))).toList();
      },
    );
  }

  Widget _singleItem(dynamic item, TextStyle? textStyle) {
    return Container(
      alignment: Alignment.center,
      height: widget.itemHeight,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      // decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: item == null
          ? Container(
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(str.main.add, style: textStyle ?? widget.textStyle),
                  context.addWidth(4),
                  const Icon(Icons.add_circle_rounded, color: kPrimaryColor),
                ],
              ),
            )
          : Text(widget.itemToString != null ? widget.itemToString!(item) : item.toString(), style: TextStyle(color: Colors.amber)),
    );
  }

  Widget _borderShape(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: widget.borderColor),
      ),
      child: child,
    );
  }

  Widget _btnShape(Widget child) {
    return Material(
      elevation: widget.elevation,
      borderRadius: BorderRadius.circular(widget.borderRadius),
      shadowColor: widget.buttonShapeColor.withOpacity(.6),
      color: widget.buttonShapeColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: child,
      ),
    );
  }
}
