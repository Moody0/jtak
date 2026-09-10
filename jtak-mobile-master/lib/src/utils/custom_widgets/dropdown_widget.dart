import 'package:flutter/material.dart';

import '../../../main_imports.dart';
import '../../config/themes/app_theme.dart';
import '../../config/themes/colors.dart';
import '../utilities/global_var.dart';

class DropdownWidget extends StatefulWidget {
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

  const DropdownWidget({
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
  _DropdownWidgetState createState() => _DropdownWidgetState();
}

class _DropdownWidgetState extends State<DropdownWidget> {
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
      hint: Text(widget.hint ?? '', style: widget.textStyle),
      itemHeight: widget.itemHeight,
      isDense: false,
      icon: widget.icon,
      underline: widget.buttonShape || widget.borderShap ? const SizedBox() : widget.underline,
      isExpanded: widget.isExpanded,
      value: value,
      items: localDataList
          .map(
            (e) => DropdownMenuItem<dynamic>(child: _singleItem(e, widget.textStyle), value: e),
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
        return localDataList.map<Widget>((e) => _singleItem(e, widget.selectedTextStyle)).toList();
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
          : Text(widget.itemToString!(item) ?? item.toString() ?? '', style: textStyle ?? widget.textStyle),
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
