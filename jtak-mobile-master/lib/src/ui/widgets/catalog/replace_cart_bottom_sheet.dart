import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../config/themes/colors.dart';

/// ---------------------------------------------------------------------------
/// JTAK Replace Cart Confirmation Bottom Sheet
///
/// Displayed when a user attempts to add an item from a different restaurant/market
/// than the one currently in their active cart.
/// ---------------------------------------------------------------------------

class ReplaceCartBottomSheet extends StatelessWidget {
  final String currentStoreName;
  final String newStoreName;

  const ReplaceCartBottomSheet({
    super.key,
    required this.currentStoreName,
    required this.newStoreName,
  });

  /// Displays the modal bottom sheet and returns `true` if the user confirmed replacing the cart.
  static Future<bool?> show(
    BuildContext context, {
    required String currentStoreName,
    required String newStoreName,
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ReplaceCartBottomSheet(
        currentStoreName: currentStoreName,
        newStoreName: newStoreName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Top Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 2. Dual-Store Transfer Icon Badge
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0E8),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  PhosphorIconsFill.arrowsLeftRight,
                  color: kPrimaryOrange,
                  size: 34,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 3. Title
            Text(
              'استبدال المتجر؟',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: kCharcoalDark,
              ),
            ),

            const SizedBox(height: 10),

            // 4. Message with Store Names
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'لديك حالياً منتجات في سلتك من '),
                  TextSpan(
                    text: '«$currentStoreName»',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.w800,
                      color: kCharcoalDark,
                    ),
                  ),
                  const TextSpan(
                    text: '.\nإضافة منتجات من ',
                  ),
                  TextSpan(
                    text: '«$newStoreName»',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.w800,
                      color: kPrimaryOrange,
                    ),
                  ),
                  TextSpan(
                    text: ' ستؤدي إلى استبدال منتجات «$currentStoreName» ومتابعة الطلب.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // 5. Primary Action: Replace & Start New Cart
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context, true);
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: kPrimaryOrange,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'استبدال ومتابعة',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 6. Secondary Action: Keep Current Cart
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context, false);
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'الاحتفاظ بالسلة الحالية',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF475569),
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
