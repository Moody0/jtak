import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'header_circle_button.dart';

/// ---------------------------------------------------------------------------
/// JTAK Modern Search Bar Component with Animated Rotating Placeholder
///
/// Features:
/// - Clean, soft grey pill with Search Icon placed directly BEFORE the placeholder
/// - Static prefix: "ابحث عن "
/// - Animated Dynamic Suffix: Smoothly slides up and fades out while the new
///   popular search term slides in from the bottom (e.g., شاورما، برجر، فطور، مشاوي، خضار).
/// ---------------------------------------------------------------------------

class JtakSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final VoidCallback? onFilterTap;
  final bool readOnly;
  final List<String>? rotatingHints;

  const JtakSearchBar({
    super.key,
    this.controller,
    this.onChanged,
    this.onTap,
    this.onFilterTap,
    this.readOnly = false,
    this.rotatingHints,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Search Icon (Matching the unified dark charcoal color)
            const JtakSearchIcon(
              color: Color(0xFF374151),
              size: 22,
            ),

            const SizedBox(width: 10),

            // 2. Animated Rotating Search Placeholder (or TextField)
            Expanded(
              child: readOnly
                  ? const DynamicRotatingSearchHint()
                  : TextField(
                      controller: controller,
                      onChanged: onChanged,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: const Color(0xFF374151),
                        fontSize: 15.0,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'ابحث عن وجبة، مطعم، صنف...',
                        hintStyle: GoogleFonts.ibmPlexSansArabic(
                          color: const Color(0xFF374151),
                          fontSize: 15.0,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                        ),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Dynamic Rotating Search Hint Widget
///
/// Displays a static "ابحث عن " prefix paired with a vertically sliding
/// and fading text ticker of authentic Syrian dishes and categories.
/// ---------------------------------------------------------------------------
class DynamicRotatingSearchHint extends StatefulWidget {
  final List<String>? customHints;
  final Duration interval;

  const DynamicRotatingSearchHint({
    super.key,
    this.customHints,
    this.interval = const Duration(milliseconds: 2600),
  });

  @override
  State<DynamicRotatingSearchHint> createState() => _DynamicRotatingSearchHintState();
}

class _DynamicRotatingSearchHintState extends State<DynamicRotatingSearchHint> {
  int _currentIndex = 0;
  Timer? _rotationTimer;

  static const List<String> _defaultFoodKeywords = [
    'شاورما عربي',
    'بروستد مقرمش',
    'مناقيش وصفيحة',
    'فلافل ومسبحة',
    'فتة حمص بالسمنة',
    'مشاوي وكباب مشكل',
    'برجر على الفحم',
    'بيتزا إيطالية',
    'دجاج مسحب كرسبي',
    'حلويات شامية',
    'بوظة عربية بالقشطة',
    'خضار وفواكه طازجة',
    'معجنات ومخبوزات',
    'عصائر وكوكتيل طبيعي',
    'ألبان وأجبان بلدية',
  ];

  List<String> get _hints => widget.customHints ?? _defaultFoodKeywords;

  @override
  void initState() {
    super.initState();
    _startRotation();
  }

  void _startRotation() {
    _rotationTimer?.cancel();
    _rotationTimer = Timer.periodic(widget.interval, (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _hints.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentText = _hints[_currentIndex];

    return Row(
      children: [
        // Static Prefix: "ابحث عن " (Color matched to Color(0xFF374151))
        Text(
          'ابحث عن ',
          style: GoogleFonts.ibmPlexSansArabic(
            color: const Color(0xFF374151),
            fontSize: 15.0,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),

        // Dynamic Rotating Suffix (Color matched to Color(0xFF374151))
        Expanded(
          child: ClipRect(
            child: SizedBox(
              height: 26,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final inAnimation = Tween<Offset>(
                    begin: const Offset(0.0, 1.2),
                    end: Offset.zero,
                  ).animate(animation);

                  final outAnimation = Tween<Offset>(
                    begin: const Offset(0.0, -1.2),
                    end: Offset.zero,
                  ).animate(animation);

                  return SlideTransition(
                    position: child.key == ValueKey<String>(currentText)
                        ? inAnimation
                        : outAnimation,
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                child: Align(
                  key: ValueKey<String>(currentText),
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    currentText,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: const Color(0xFF374151),
                      fontSize: 15.0,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
