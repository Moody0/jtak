import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../config/themes/colors.dart';
import '../../core/controllers/order_provider.dart';

/// ---------------------------------------------------------------------------
/// JTAK Delivery Bottom Navigation Bar (Animated Brand Harmony with PhosphorIcons)
/// ---------------------------------------------------------------------------

class DeliveryBottomNavigation extends StatelessWidget {
  static const double height = 66.0;
  final int currentIndex;
  final ValueChanged<int> onChange;

  const DeliveryBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final orderProv = Provider.of<OrderProvider>(context);
    final activeOrdersCount = orderProv.activeOrders.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        top: 6,
        bottom: bottomPadding > 0 ? bottomPadding : 8,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final tabWidth = totalWidth / 4;
          const pillWidth = 58.0;
          const pillHeight = 30.0;

          // In Arabic RTL: index 0 is on the far right (3 * tabWidth),
          // index 1 at (2 * tabWidth), index 2 at (1 * tabWidth), index 3 at (0 * tabWidth)
          final isRTL = Directionality.of(context) == TextDirection.rtl;
          final pillLeft = isRTL
              ? (3 - currentIndex) * tabWidth + (tabWidth - pillWidth) / 2
              : currentIndex * tabWidth + (tabWidth - pillWidth) / 2;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Sliding Pill Capsule (Glides smoothly between tabs)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                left: pillLeft,
                top: 0,
                width: pillWidth,
                height: pillHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFFFF0E8),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFFFD6C2),
                      width: 0.9,
                    ),
                  ),
                ),
              ),

              // 2. Interactive Navigation Tabs
              Row(
                children: [
                  // Tab 0: الطلبات (Orders)
                  _buildNavItem(
                    context: context,
                    index: 0,
                    width: tabWidth,
                    label: isRTL ? 'الطلبات' : 'Orders',
                    activeIcon: PhosphorIconsFill.moped,
                    inactiveIcon: PhosphorIconsRegular.moped,
                    isActive: currentIndex == 0,
                    badgeCount: activeOrdersCount,
                  ),

                  // Tab 1: المالية (Finances / Transactions)
                  _buildNavItem(
                    context: context,
                    index: 1,
                    width: tabWidth,
                    label: isRTL ? 'المالية' : 'Finances',
                    activeIcon: PhosphorIconsFill.wallet,
                    inactiveIcon: PhosphorIconsRegular.wallet,
                    isActive: currentIndex == 1,
                  ),

                  // Tab 2: الملف الشخصي (Profile)
                  _buildNavItem(
                    context: context,
                    index: 2,
                    width: tabWidth,
                    label: isRTL ? 'الملف' : 'Profile',
                    activeIcon: PhosphorIconsFill.user,
                    inactiveIcon: PhosphorIconsRegular.user,
                    isActive: currentIndex == 2,
                  ),

                  // Tab 3: الإعدادات (Settings)
                  _buildNavItem(
                    context: context,
                    index: 3,
                    width: tabWidth,
                    label: isRTL ? 'الإعدادات' : 'Settings',
                    activeIcon: PhosphorIconsFill.gear,
                    inactiveIcon: PhosphorIconsRegular.gear,
                    isActive: currentIndex == 3,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required double width,
    required String label,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required bool isActive,
    int badgeCount = 0,
  }) {
    return SizedBox(
      width: width,
      height: 52,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onChange(index);
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon Stack with Badge
            SizedBox(
              height: 28,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  AnimatedScale(
                    scale: isActive ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        isActive ? activeIcon : inactiveIcon,
                        key: ValueKey<bool>(isActive),
                        size: 22,
                        color: isActive ? kPrimaryOrange : const Color(0xFF64748B),
                      ),
                    ),
                  ),

                  // Badge Counter for Active Orders
                  if (badgeCount > 0)
                    Positioned(
                      top: -4,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: kPrimaryOrange,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Center(
                          child: Text(
                            '$badgeCount',
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 2),

            // Tab Label
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? kPrimaryOrange : const Color(0xFF64748B),
                letterSpacing: -0.2,
                height: 1.1,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
