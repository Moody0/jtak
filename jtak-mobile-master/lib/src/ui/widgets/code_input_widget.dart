import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/themes/colors.dart';

/// ---------------------------------------------------------------------------
/// JTAK Modern Discrete OTP Code Input Widget (4 / 6 Squircles)
///
/// Features:
/// - Unified single-input architecture:
///   1. Deleting via keyboard immediately clears the last digit without
///      any text selection highlight or second-tap delay.
///   2. Completely eliminates the native selection effect (orange box).
///   3. Supports tapping directly on any box to delete/rewind to that position.
///   4. Full SMS autofill & clipboard paste support.
/// ---------------------------------------------------------------------------

class CodeInputWidget extends StatefulWidget {
  final int codeLength;
  final void Function(String code) onEnd;
  final void Function(String code)? onChange;

  const CodeInputWidget({
    super.key,
    required this.onEnd,
    this.onChange,
    this.codeLength = 4,
  });

  @override
  State<CodeInputWidget> createState() => _CodeInputWidgetState();
}

class _CodeInputWidgetState extends State<CodeInputWidget> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isFixingSelection = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();

    _controller.addListener(() {
      if (_isFixingSelection) return;
      final len = _controller.text.length;
      if (_controller.selection.baseOffset != len ||
          _controller.selection.extentOffset != len) {
        _isFixingSelection = true;
        _controller.value = _controller.value.copyWith(
          selection: TextSelection.collapsed(offset: len),
        );
        _isFixingSelection = false;
      }
      if (mounted) setState(() {});
    });

    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text;
    final isFocused = _focusNode.hasFocus;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Transparent real input field capturing keyboard, backspace, and paste events
              Positioned.fill(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(widget.codeLength),
                  ],
                  maxLength: widget.codeLength,
                  enableInteractiveSelection: false,
                  showCursor: false,
                  cursorColor: Colors.transparent,
                  cursorWidth: 0,
                  autofocus: true,
                  style: const TextStyle(
                    color: Colors.transparent,
                    fontSize: 1,
                    height: 1,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) {
                    final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
                    final trimmed = clean.length > widget.codeLength
                        ? clean.substring(0, widget.codeLength)
                        : clean;

                    if (trimmed != value) {
                      _controller.value = TextEditingValue(
                        text: trimmed,
                        selection: TextSelection.collapsed(offset: trimmed.length),
                      );
                      return;
                    }

                    widget.onChange?.call(trimmed);
                    if (trimmed.length == widget.codeLength) {
                      widget.onEnd(trimmed);
                    }
                  },
                ),
              ),

              // 2. Discrete visual OTP Squircles
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.codeLength, (index) {
                  final isFilled = index < text.length;
                  final char = isFilled ? text[index] : '';

                  // The active box is the current slot waiting for input,
                  // or the last box when completely filled.
                  final isCurrentActive = isFocused &&
                      (index == text.length ||
                          (text.length == widget.codeLength && index == widget.codeLength - 1));

                  return GestureDetector(
                    onTap: () {
                      _focusNode.requestFocus();
                      // Tapping an already filled box immediately deletes digits from that box onwards
                      if (index < _controller.text.length) {
                        final newText = _controller.text.substring(0, index);
                        _controller.value = TextEditingValue(
                          text: newText,
                          selection: TextSelection.collapsed(offset: newText.length),
                        );
                        widget.onChange?.call(newText);
                      } else {
                        _controller.selection =
                            TextSelection.collapsed(offset: _controller.text.length);
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 54,
                      height: 60,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: isCurrentActive ? Colors.white : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isCurrentActive
                              ? kPrimaryOrange
                              : (isFilled ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
                          width: isCurrentActive ? 1.8 : 1.1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          char,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: kCharcoalDark,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
