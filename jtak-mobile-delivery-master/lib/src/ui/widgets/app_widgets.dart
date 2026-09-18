import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../config/constants/constants.dart';
import '../../config/themes/colors.dart';

class AppBarWidget {
  static PreferredSizeWidget getAppBar({Widget? leading, String? title, BuildContext? context}) {
    final isDark = context != null && Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      title: title != null
          ? Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : kCharcoalDark,
              ),
            )
          : Image.asset(kLogo2, height: 28),
      centerTitle: true,
      leading: leading,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: isDark ? const Color(0xFF334155) : kBorderColor, height: 1),
      ),
    );
  }
}

class NoDataAvailableWidget extends StatelessWidget {
  final String? msg;
  final String? subMsg;
  final String? imageName;
  final IconData? icon;
  final VoidCallback? onRetry;

  const NoDataAvailableWidget({
    Key? key,
    this.msg,
    this.subMsg,
    this.imageName,
    this.icon,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : kSurfaceWarm,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : kPrimaryOrange.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  icon ?? PhosphorIcons.mopedBold,
                  size: 44,
                  color: kPrimaryOrange,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              msg ??
                  (isArabic ? 'لا توجد طلبات حالياً' : 'No orders available'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : kCharcoalDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subMsg ??
                  (isArabic
                      ? 'سيتم إشعارك فور وصول طلب توصيل جديد لمنطقتك'
                      : 'You will be notified once a new delivery order is in your area'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon:
                    const AppIcon(PhosphorIcons.arrowsClockwiseBold, size: 16),
                label: Text(isArabic ? 'تحديث' : 'Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimaryOrange,
                  side: const BorderSide(color: kPrimaryOrange, width: 1.2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Renders icons in their true, un-mirrored orientation in RTL locales.
class AppIcon extends StatelessWidget {
  final IconData? icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  const AppIcon(
    this.icon, {
    Key? key,
    this.size,
    this.color,
    this.semanticLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (icon == null) return const SizedBox.shrink();
    return Icon(
      icon,
      size: size,
      color: color,
      semanticLabel: semanticLabel,
      textDirection: TextDirection.ltr,
    );
  }
}

/// Horizontally mirrors an icon for the delivery work surfaces. This is kept
/// separate from AppIcon so the rest of the app can retain its existing icon
/// orientation.
class HomeMirroredIcon extends StatelessWidget {
  final IconData? icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  const HomeMirroredIcon(
    this.icon, {
    Key? key,
    this.size,
    this.color,
    this.semanticLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (icon == null) return const SizedBox.shrink();
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
      child: Icon(
        icon,
        size: size,
        color: color,
        semanticLabel: semanticLabel,
        textDirection: TextDirection.ltr,
      ),
    );
  }
}
