import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../main_imports.dart';
import '../../config/themes/app_theme.dart';
import '../../config/themes/colors.dart';
import '../utilities/global_var.dart';
import 'button.dart';

class CustomDialog extends StatelessWidget {
  final String? title;
  final String? message;
  final List<Widget>? actions;
  final bool isSuccess;

  const CustomDialog({
    Key? key,
    this.title,
    this.message,
    this.actions,
    this.isSuccess = false,
  }) : super(key: key);

  static String cleanErrorMessage(String? msg) {
    if (msg == null || msg.isEmpty) return 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.';
    final lower = msg.toLowerCase();
    if (lower.contains('invalid') && (lower.contains('password') || lower.contains('username') || lower.contains('couple') || lower.contains('code'))) {
      return 'رمز التحقق المدخل غير صحيح أو قد انتهت صلاحيته.\nيرجى التأكد من كتابة الرمز أو إدخال (123456) للتجربة.';
    }
    if (lower.contains('access_denied') || lower.contains('unauthorized') || lower.contains('401')) {
      return 'لم يتم التحقق من بيانات الدخول. يرجى التأكد من صحة رقم الهاتف والرمز.';
    }
    if (lower.contains('سائق') || lower.contains('driver')) {
      return 'هذا الحساب ليس مسجلاً كحساب سائق توصيل معتمد. يرجى تسجيل الدخول بحساب كابتن.';
    }
    if (lower.contains('timeout') || lower.contains('network') || lower.contains('socketexception')) {
      return 'تعذر الاتصال بالخادم. يرجى التحقق من اتصال الإنترنت والمحاولة ثانية.';
    }
    return msg.replaceAll(RegExp(r'^Exception:\s*'), '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final displayMessage = cleanErrorMessage(message);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: kCardBorderColor, width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Badge Icon
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: isSuccess ? kGreenLight : kRedLight,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: AppIcon(
                  isSuccess ? PhosphorIcons.checkCircleBold : PhosphorIcons.warningCircleBold,
                  size: 30,
                  color: isSuccess ? kGreen : kRed,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              title ?? (isSuccess ? 'تمت العملية' : 'تنبيه'),
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: kCharcoalDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Body Message
            Text(
              displayMessage,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: kCharcoalMedium,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),

            // Actions Button
            if (actions != null && actions!.isNotEmpty)
              Row(children: actions!.map((w) => Expanded(child: w)).toList())
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSuccess ? kGreen : kPrimaryOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('حسناً، فهمت'),
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
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: kCardBorderColor, width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: kSurfaceWarm,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: AppIcon(
                  PhosphorIcons.questionBold,
                  size: 30,
                  color: kPrimaryOrange,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title ?? 'تأكيد الإجراء',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: kCharcoalDark,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                message!,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: kCharcoalMedium,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kCharcoalMuted,
                      side: const BorderSide(color: kBorderColor, width: 1.1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('إلغاء'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('تأكيد'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      yesBTNCallBack();
                    },
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
                    style: context.textTheme.headline5,
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
              style: context.textTheme.bodyText1,
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
              child: Text(str.main.yes),
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
  static SnackBar blankSnakBar(String text, {int? milliseconds = 1500}) {
    return SnackBar(
      // behavior: SnackBarBehavior.floating,
      content: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)), duration: Duration(milliseconds: milliseconds ?? 1500),
    );
  }
}
