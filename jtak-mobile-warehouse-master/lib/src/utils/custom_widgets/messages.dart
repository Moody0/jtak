import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../main_imports.dart';
import '../../config/themes/app_theme.dart';
import '../../config/themes/colors.dart';
import '../utilities/global_var.dart';
import 'button.dart';

/// ---------------------------------------------------------------------------
/// JTAK Modern Clean Dialogs & Messages (Zero Shadow, Crisp Typography)
/// ---------------------------------------------------------------------------

class CustomDialog extends StatelessWidget {
  final String? title;
  final String? message;
  final List<Widget>? actions;
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBg;

  const CustomDialog({
    Key? key,
    this.title,
    this.message,
    this.actions,
    this.icon,
    this.iconColor,
    this.iconBg,
  }) : super(key: key);

  /// Sanitizes raw exceptions and translates raw backend errors into clear Arabic
  static String sanitizeMessage(String raw) {
    String clean = raw
        .replaceAll('Exception: ', '')
        .replaceAll('Exception:', '')
        .replaceAll('Error: ', '')
        .replaceAll('FetchDataException', '')
        .trim();

    // Specific translation for Identity / OpenIddict / SMS token errors
    if (clean.contains('The username/password couple is invalid') ||
        clean.contains('invalid_grant') ||
        clean.contains('InvalidUsernamePassword')) {
      return 'رمز التحقق المدخل غير صحيح أو انتهت صلاحيته.\nيرجى التأكد من الرمز وإعادة المحاولة.';
    }

    if (clean.contains('user is not active') || clean.contains('ForbidInactive')) {
      return 'تم تعطيل هذا الحساب مؤقتاً. يرجى التواصل مع إدارة جيتك.';
    }

    if (clean.contains('SocketException') ||
        clean.contains('Network is unreachable') ||
        clean.contains('Connection refused') ||
        clean.contains('Failed host lookup') ||
        clean.contains('NetworkError')) {
      return 'تعذر الاتصال بالخادم. يرجى التأكد من اتصال الإنترنت والمحاولة مجدداً.';
    }

    if (clean.contains('TimeoutException')) {
      return 'استغرقت الاستجابة وقتاً طويلاً. يرجى إعادة المحاولة.';
    }

    return clean;
  }

  @override
  Widget build(BuildContext context) {
    final cleanMsg = message != null ? sanitizeMessage(message!) : '';
    final isError = cleanMsg.contains('غير صحيح') ||
        cleanMsg.contains('خطأ') ||
        cleanMsg.contains('تعذر') ||
        cleanMsg.contains('فشل') ||
        (title != null && (title!.contains('خطأ') || title!.contains('تنبيه') || title!.contains('غير مكتمل')));

    final effectiveIcon = icon ??
        (isError ? PhosphorIconsFill.warningCircle : PhosphorIconsFill.info);
    final effectiveIconColor = iconColor ??
        (isError ? const Color(0xFFEF4444) : kPrimaryOrange);
    final effectiveIconBg = iconBg ??
        (isError ? const Color(0xFFFEF2F2) : const Color(0xFFFFF3EB));

    return Dialog(
      backgroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Icon Badge (Soft tint circle, flat, zero shadow)
            Container(
              width: 54,
              height: 54,
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
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  cleanMsg,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
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
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: kPrimaryOrange,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        'حسناً',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 15,
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
}

class CustomConfirmationDialog extends StatelessWidget {
  final String? title;
  final String? message;
  final Function() yesBTNCallBack;

  const CustomConfirmationDialog({Key? key, this.title, this.message, required this.yesBTNCallBack}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF3EB),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(PhosphorIconsFill.question, color: kPrimaryOrange, size: 28),
              ),
            ),
            const SizedBox(height: 16),
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
            if (message != null && message!.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF475569),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop(false);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                      ),
                      child: Center(
                        child: Text(
                          str.main.cancel,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: kCharcoalMedium,
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
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop(true);
                      yesBTNCallBack();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: kPrimaryOrange,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Center(
                        child: Text(
                          str.main.ok,
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
    Key? key,
    this.icon = Icons.sentiment_very_dissatisfied,
    this.color,
    this.size = 80,
    this.showErrorWord = false,
    this.action,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const SizedBox(height: 25),
        Opacity(opacity: .5, child: Center(child: Icon(icon, color: color ?? context.appTheme.colorScheme.secondary, size: size))),
        showErrorWord
            ? Center(
                child: Padding(
                  padding: AppTheme.standardPadding,
                  child: Text(
                    '${str.msg.errorOccurred} ',
                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 16, fontWeight: FontWeight.w700, color: kCharcoalDark),
                  ),
                ),
              )
            : const SizedBox(),
        const SizedBox(height: 15),
        Center(
          child: Padding(
            padding: AppTheme.standardPadding,
            child: Text(
              ' $errorMsg',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 13.5, color: kCharcoalMedium),
            ),
          ),
        ),
        action ?? const SizedBox(),
      ],
    );
  }
}

class DeleteConfermationDialog {
  void delete({required BuildContext context, required String explainMsg, required Function deleteFun}) {
    showDialog(
      context: context,
      builder: (context) => CustomDialog(
        title: str.msg.deleteConfermation,
        message: explainMsg,
        actions: <Widget>[
          TextButton(
              child: Text(str.main.yes, style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700, color: kPrimaryOrange)),
              onPressed: () {
                Navigator.pop(context);
                deleteFun();
              }),
          ButtonWidget(
            text: str.main.no,
            onPressed: () => Navigator.pop(context),
            padding: const EdgeInsets.all(8),
          ),
        ],
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
    String text, {
    int? milliseconds = 2500,
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
        text,
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
