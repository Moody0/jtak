import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CodeInputWidget extends StatefulWidget {
  final int codeLength;
  final void Function(String code) onEnd;
  final void Function(String code)? onChange;
  const CodeInputWidget({required this.onEnd, this.onChange, this.codeLength = 6});

  @override
  _CodeInputWidgetState createState() => _CodeInputWidgetState();
}

class _CodeInputWidgetState extends State<CodeInputWidget> {
  List<TextEditingController> controllerList = [];
  List<FocusNode> focusNodeList = [];
  List<String> codeList = [];
  @override
  void initState() {
    codeList = List.generate(widget.codeLength, (index) => '');
    focusNodeList = List.generate(widget.codeLength, (index) => FocusNode());
    controllerList = List.generate(widget.codeLength, (index) => TextEditingController());
    for (var i = 0; i < widget.codeLength; i++) {
      FocusNode focusNode = focusNodeList[i];
      focusNode.addListener(() {
        if (focusNode.hasFocus) {
          controllerList[i].selection = TextSelection(baseOffset: 0, extentOffset: controllerList[i].text.length);
        }
      });
    }
    focusNodeList[0].requestFocus();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> inputList = [];
    for (var i = 0; i < widget.codeLength; i++) {
      inputList.add(
        Expanded(
          child: Container(
            // width: inputWidth,
            decoration: BoxDecoration(
              borderRadius: _getBorderRaduis(i),
              border: Border.all(color: Colors.grey),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: RawKeyboardListener(
              autofocus: i == 0,
              focusNode: FocusNode(),
              key: ValueKey(i.toString()),
              onKey: (event) {
                if (event.runtimeType.toString() == 'RawKeyUpEvent') {
                  if (event.logicalKey == LogicalKeyboardKey.backspace && i > 0) {
                    focusNodeList[i - 1].requestFocus();
                  }
                }
              },
              child: _textField(i),
            ),
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: inputList,
        ),
      ),
    );
  }

  TextFormField _textField(int i) {
    return TextFormField(
      controller: controllerList[i],
      focusNode: focusNodeList[i],
      keyboardType: TextInputType.number,
      maxLength: 1,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 25),
      showCursor: false,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.zero,
        counterText: "",
        border: UnderlineInputBorder(),
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
    );
  }

  // double _calcInputWidth() {
  //   double initWidth = 60;
  //   if ((initWidth * widget.codeLength) * 0.9 > context.width) {
  //     initWidth = context.width * 0.9 / widget.codeLength;
  //   }
  //   return initWidth;
  // }

  BorderRadiusGeometry _getBorderRaduis(int i) {
    BorderRadiusGeometry borderRadius = BorderRadius.circular(0);
    if (i == 0) {
      borderRadius = const BorderRadiusDirectional.horizontal(start: Radius.circular(4));
    } else if (i == widget.codeLength - 1) {
      borderRadius = const BorderRadiusDirectional.horizontal(end: Radius.circular(4));
    }
    return borderRadius;
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
