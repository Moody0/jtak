import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../config/themes/colors.dart';
import '../utilities/global_var.dart';

class CustomDialog extends StatelessWidget {
  final String? title;
  final String? message;
  final List<Widget>? actions;
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBg;

  const CustomDialog({
    super.key,
    this.title,
    this.message,
    this.actions,
    this.icon,
    this.iconColor,
    this.iconBg,
  });

  static String _cleanMessage(String raw) {
    return raw
        .replaceAll('Exception: ', '')
        .replaceAll('Exception:', '')
        .replaceAll('Error: ', '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final cleanMsg = message != null ? _cleanMessage(message!) : '';
    final isLoginPrompt = cleanMsg.contains('تسجيل الدخول') || (title != null && title!.contains('تسجيل الدخول'));
    final isWarning = cleanMsg.contains('تنبيه') ||
        cleanMsg.contains('تحذير') ||
        cleanMsg.contains('للأسف') ||
        cleanMsg.contains('غير متوفر') ||
        cleanMsg.contains('مراجعة') ||
        cleanMsg.contains('الحد الأدنى') ||
        (title != null && (title!.contains('تنبيه') || title!.contains('تحذير')));

    final effectiveIcon = icon ??
        (isLoginPrompt
            ? PhosphorIconsFill.signIn
            : (isWarning ? PhosphorIconsFill.warningCircle : PhosphorIconsFill.info));
    final effectiveIconColor = iconColor ??
        (isLoginPrompt
            ? kPrimaryOrange
            : (isWarning ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6)));
    final effectiveIconBg = iconBg ??
        (isLoginPrompt
            ? const Color(0xFFFFF0E8)
            : (isWarning ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF)));

    final isMultiLine = cleanMsg.contains('\n');

    return Dialog(
      backgroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Icon Badge Squircle
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: effectiveIconBg,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(effectiveIcon, color: effectiveIconColor, size: 28),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Dialog Title
            if (title != null && title!.isNotEmpty) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: kCharcoalDark,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // 3. Message Body
            if (cleanMsg.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isMultiLine ? 4 : 0),
                child: Text(
                  cleanMsg,
                  textAlign: isMultiLine ? TextAlign.start : TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 4. Action Buttons
            if (actions != null && actions!.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: actions!,
              )
            else
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: kPrimaryOrange,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        _safeStrMainOk(),
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _safeStrMainOk() {
    try {
      return (GlobalVar.checkString(str.main.ok) ? str.main.ok : 'موافق');
    } catch (_) {
      return 'موافق';
    }
  }
}

class CustomConfirmationDialog extends StatelessWidget {
  final String? title;
  final String? message;
  final VoidCallback yesBTNCallBack;
  final String? yesText;
  final String? cancelText;

  const CustomConfirmationDialog({
    super.key,
    this.title,
    this.message,
    required this.yesBTNCallBack,
    this.yesText,
    this.cancelText,
  });

  static String _safeCancel() {
    try {
      return (GlobalVar.checkString(str.main.cancel) ? str.main.cancel : 'إلغاء');
    } catch (_) {
      return 'إلغاء';
    }
  }

  static String _safeOk() {
    try {
      return (GlobalVar.checkString(str.main.ok) ? str.main.ok : 'موافق');
    } catch (_) {
      return 'موافق';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0E8),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(PhosphorIconsFill.question, color: kPrimaryOrange, size: 28),
              ),
            ),
            const SizedBox(height: 16),
            if (title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: kCharcoalDark,
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (message != null) ...[
              Text(
                message!,
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
            ],
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          cancelText ?? _safeCancel(),
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop(true);
                      yesBTNCallBack();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: kPrimaryOrange,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          yesText ?? _safeOk(),
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorCustomWidget extends StatelessWidget {
  final String errorMsg;
  final IconData icon;
  final Color? color;
  final double size;
  final bool showErrorWord;
  final Widget? action;

  const ErrorCustomWidget(
    this.errorMsg, {
    super.key,
    this.icon = Icons.sentiment_very_dissatisfied,
    this.color,
    this.size = 80,
    this.showErrorWord = false,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: (color ?? kPrimaryOrange).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, size: size * 0.5, color: color ?? kPrimaryOrange),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              errorMsg,
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: kCharcoalDark,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class SnackBarWidget {
  static void showCustomSnackBar(
    BuildContext context,
    String message, {
    int? milliseconds,
    Color? backgroundColor,
    TextStyle? textStyle,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      blankSnakBar(
        message,
        milliseconds: milliseconds,
        backgroundColor: backgroundColor,
        textStyle: textStyle,
      ),
    );
  }

  static SnackBar blankSnakBar(
    String message, {
    int? milliseconds,
    Color? backgroundColor,
    TextStyle? textStyle,
  }) {
    return SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      backgroundColor: backgroundColor ?? kCharcoalDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      duration: Duration(milliseconds: milliseconds ?? 2500),
      content: Text(
        message,
        style: textStyle ??
            GoogleFonts.ibmPlexSansArabic(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
      ),
    );
  }
}

