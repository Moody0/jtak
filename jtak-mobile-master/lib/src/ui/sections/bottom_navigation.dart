import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../config/themes/colors.dart';
import '../../core/controllers/app/home_navigation_provider.dart';

/// ---------------------------------------------------------------------------
/// JTAK Modern Bottom Navigation Bar (Animated Brand Harmony with PhosphorIcons)
///
/// Animations:
/// 1. Smooth Pill Capsule Expansion (AnimatedContainer with cubic easing)
/// 2. Icon Micro-Pop / Bounce (AnimatedScale with easeOutBack curve)
/// 3. Morphing Outline-to-Fill Transition (AnimatedSwitcher)
/// 4. Typography Interpolation (AnimatedDefaultTextStyle)
/// 5. Subtle Haptic Feedback
/// ---------------------------------------------------------------------------

class BottomNavigation extends StatelessWidget {
  static const double height = 66.0;
  final ValueChanged<int> onChange;

  const BottomNavigation({
    super.key,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final homeNavigationProvider = Provider.of<HomeNavigationProvider>(context);
    final activeIndex = homeNavigationProvider.currentIndex;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
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
          // index 1 is at (2 * tabWidth), index 2 at (1 * tabWidth), index 3 at (0 * tabWidth)
          final isRTL = Directionality.of(context) == TextDirection.rtl;
          final pillLeft = isRTL
              ? (3 - activeIndex) * tabWidth + (tabWidth - pillWidth) / 2
              : activeIndex * tabWidth + (tabWidth - pillWidth) / 2;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Sliding Pill Capsule (Glides smoothly from tab to tab, zero AI-slop shadow)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                left: pillLeft,
                top: 0,
                width: pillWidth,
                height: pillHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0E8),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0xFFFFD6C2), width: 0.9),
                  ),
                ),
              ),

              // 2. Interactive Navigation Tabs
              Row(
                children: [
                  // Tab 0: الرئيسية (Home)
                  _buildNavItem(
                    context: context,
                    index: 0,
                    width: tabWidth,
                    label: 'الرئيسية',
                    activeIcon: PhosphorIconsFill.house,
                    inactiveIcon: PhosphorIconsRegular.house,
                    isActive: activeIndex == 0,
                  ),

                  // Tab 1: طلباتي (Orders)
                  _buildNavItem(
                    context: context,
                    index: 1,
                    width: tabWidth,
                    label: 'طلباتي',
                    activeIcon: PhosphorIconsFill.shoppingBag,
                    inactiveIcon: PhosphorIconsRegular.shoppingBag,
                    isActive: activeIndex == 1,
                  ),

                  // Tab 2: المفضلة (Favorites)
                  _buildNavItem(
                    context: context,
                    index: 2,
                    width: tabWidth,
                    label: 'المفضلة',
                    activeIcon: PhosphorIconsFill.heart,
                    inactiveIcon: PhosphorIconsRegular.heart,
                    isActive: activeIndex == 2,
                  ),

                  // Tab 3: المزيد (More)
                  _buildNavItem(
                    context: context,
                    index: 3,
                    width: tabWidth,
                    label: 'المزيد',
                    activeIcon: PhosphorIconsFill.dotsThreeOutline,
                    inactiveIcon: PhosphorIconsRegular.dotsThreeOutline,
                    isActive: activeIndex == 3,
                    isMoreTab: true,
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
    bool isMoreTab = false,
  }) {
    return GestureDetector(
      onTap: () {
        if (!isActive) {
          HapticFeedback.selectionClick();
        }
        FocusScope.of(context).unfocus();
        onChange(index);
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon Container (30px height, aligned directly over the sliding pill)
            SizedBox(
              width: 58,
              height: 30,
              child: Center(
                child: AnimatedScale(
                  scale: isActive ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutBack,
                  child: isMoreTab
                      ? AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isActive ? kPrimaryOrange : const Color(0xFF6B7280),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.more_horiz_rounded,
                              size: 14,
                              color: isActive ? kPrimaryOrange : const Color(0xFF6B7280),
                            ),
                          ),
                        )
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                          child: Icon(
                            isActive ? activeIcon : inactiveIcon,
                            key: ValueKey('${label}_$isActive'),
                            color: isActive ? kPrimaryOrange : const Color(0xFF6B7280),
                            size: 21,
                            textDirection: TextDirection.ltr,
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 3),

            // Animated Label Text (Brand Orange & Weight Transition)
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              style: GoogleFonts.ibmPlexSansArabic(
                color: isActive ? kPrimaryOrange : const Color(0xFF6B7280),
                fontSize: isActive ? 11.8 : 11.0,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
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
