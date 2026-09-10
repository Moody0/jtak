import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../config/themes/colors.dart';
import '../../core/models/user/user_model.dart';
import '../../utils/utilities/global_var.dart';
import '../pages/account/profile_page.dart';

/// ---------------------------------------------------------------------------
/// JTAK Professional Account Profile Card (Flat Design - Zero Shadows)
/// ---------------------------------------------------------------------------

class AccountCard extends StatelessWidget {
  final UserModel item;

  const AccountCard(this.item, {super.key});

  @override
  Widget build(BuildContext context) {
    final String displayName = GlobalVar.checkString(item.fullName)
        ? item.fullName!
        : (GlobalVar.checkString(item.phoneNumber) ? item.phoneNumber! : 'مستخدم جيتك');

    final String initialChar = displayName.trim().isNotEmpty
        ? displayName.trim().substring(0, 1).toUpperCase()
        : 'ج';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Circular Avatar with initial
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD6C2), width: 1.5),
            ),
            child: Center(
              child: Text(
                initialChar,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: kPrimaryOrange,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: kCharcoalDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Transform.flip(
                      flipX: true,
                      child: const Icon(
                        PhosphorIconsFill.sealCheck,
                        color: kPrimaryOrange,
                        size: 16,
                      ),
                    ),
                  ],
                ),
                if (GlobalVar.checkString(item.phoneNumber)) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.phoneNumber!,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                ],
                if (GlobalVar.checkString(item.email)) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.email!,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Edit Profile Action
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pushNamed(context, ProfilePage.routeName);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(PhosphorIconsRegular.pencilSimple, size: 14, color: kCharcoalDark),
                  const SizedBox(width: 4),
                  Text(
                    'تعديل',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kCharcoalDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
