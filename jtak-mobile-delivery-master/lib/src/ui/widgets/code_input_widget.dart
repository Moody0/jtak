import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/themes/colors.dart';

class CodeInputWidget extends StatefulWidget {
  final int codeLength;
  final String? initialCode;
  final void Function(String code) onEnd;
  final void Function(String code)? onChange;
  const CodeInputWidget({
    required this.onEnd,
    this.onChange,
    this.initialCode,
    this.codeLength = 6,
    Key? key,
  }) : super(key: key);

  @override
  CodeInputWidgetState createState() => CodeInputWidgetState();
}

class CodeInputWidgetState extends State<CodeInputWidget> {
  List<TextEditingController> controllerList = [];
  List<FocusNode> focusNodeList = [];
  List<String> codeList = [];

  void setCode(String newCode) {
    String clean = newCode.replaceAll(RegExp(r'\D'), '');
    for (var i = 0; i < widget.codeLength; i++) {
      if (i < clean.length) {
        controllerList[i].text = clean[i];
        codeList[i] = clean[i];
      } else {
        controllerList[i].text = '';
        codeList[i] = '';
      }
    }
    setState(() {});
    if (widget.onChange != null) {
      widget.onChange!(codeList.join());
    }
    if (clean.length >= widget.codeLength) {
      widget.onEnd(codeList.join());
    }
  }

  @override
  void initState() {
    codeList = List.generate(widget.codeLength, (index) => '');
    focusNodeList = List.generate(widget.codeLength, (index) => FocusNode());
    controllerList = List.generate(widget.codeLength, (index) => TextEditingController());
    for (var i = 0; i < widget.codeLength; i++) {
      FocusNode focusNode = focusNodeList[i];
      focusNode.addListener(() {
        setState(() {});
        if (focusNode.hasFocus) {
          controllerList[i].selection = TextSelection(baseOffset: 0, extentOffset: controllerList[i].text.length);
        }
      });
    }

    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setCode(widget.initialCode!);
      });
    } else {
      focusNodeList[0].requestFocus();
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    List<Widget> inputList = [];
    for (var i = 0; i < widget.codeLength; i++) {
      final isFocused = focusNodeList[i].hasFocus;
      final hasValue = codeList[i].isNotEmpty;

      inputList.add(
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 54,
            decoration: BoxDecoration(
              color: isFocused
                  ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                  : (isDark ? const Color(0xFF0F172A) : kGreyBackground),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isFocused
                    ? kPrimaryOrange
                    : hasValue
                        ? kPrimaryOrange.withOpacity(0.5)
                        : (isDark ? const Color(0xFF334155) : kCardBorderColor),
                width: isFocused ? 1.8 : 1.1,
              ),
            ),
            child: Center(
              child: RawKeyboardListener(
                focusNode: FocusNode(),
                onKey: (event) {
                  if (event is RawKeyUpEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.backspace && i > 0 && controllerList[i].text.isEmpty) {
                      focusNodeList[i - 1].requestFocus();
                    }
                  }
                },
                child: TextFormField(
                  controller: controllerList[i],
                  focusNode: focusNodeList[i],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : kCharcoalDark,
                  ),
                  showCursor: false,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    counterText: "",
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                  onChanged: (value) {
                    codeList[i] = value;
                    if (widget.onChange != null) {
                      widget.onChange!(codeList.join());
                    }
                    if (value.isNotEmpty) {
                      if (i < widget.codeLength - 1) {
                        focusNodeList[i + 1].requestFocus();
                      }
                      if (i == widget.codeLength - 1) {
                        widget.onEnd(codeList.join());
                      }
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: inputList,
      ),
    );
  }

  @override
  void dispose() {
    for (var element in controllerList) {
      element.dispose();
    }
    for (var element in focusNodeList) {
      element.dispose();
    }
    super.dispose();
  }
}
