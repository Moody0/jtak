import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/themes/colors.dart';
import '../../utils/utilities/global_var.dart';

/// ---------------------------------------------------------------------------
/// JTAK Modern Social Media & Community Channels Section
/// Strictly styled to match JTAK Design System (PhosphorIcons, Flat #E2E8F0 borders)
/// ---------------------------------------------------------------------------

class SocialMediaWidget extends StatelessWidget {
  const SocialMediaWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Column(
        children: [
          // Section Title
          Text(
            'تابعنا على منصات التواصل',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: kCharcoalDark,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'كن أول من يعرف بالعروض والخصومات اليومية',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 14),

          // Social Channels Strip (Phosphor Icons System)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // WhatsApp (Live Support)
              _buildChannelButton(
                icon: PhosphorIconsFill.whatsappLogo,
                iconColor: const Color(0xFF10B981),
                bgColor: const Color(0xFFECFDF5),
                onTap: () => _whatsappFun(context),
              ),
              const SizedBox(width: 12),

              // Call Hotline (JTAK Brand Orange)
              _buildChannelButton(
                icon: PhosphorIconsFill.phone,
                iconColor: kPrimaryOrange,
                bgColor: const Color(0xFFFFF3EB),
                onTap: _call,
              ),
              const SizedBox(width: 12),

              // Instagram (Rose)
              _buildChannelButton(
                icon: PhosphorIconsFill.instagramLogo,
                iconColor: const Color(0xFFE11D48),
                bgColor: const Color(0xFFFFF1F2),
                onTap: _instagramFun,
              ),
              const SizedBox(width: 12),

              // Facebook (Blue)
              _buildChannelButton(
                icon: PhosphorIconsFill.facebookLogo,
                iconColor: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
                onTap: _facebookFun,
              ),
              const SizedBox(width: 12),

              // YouTube (Red)
              _buildChannelButton(
                icon: PhosphorIconsFill.youtubeLogo,
                iconColor: const Color(0xFFDC2626),
                bgColor: const Color(0xFFFEF2F2),
                onTap: _youtubeFun,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChannelButton({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.18),
              width: 1.0,
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              size: 21,
              color: iconColor,
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
      ),
    );
  }

  void _call() async {
    final Uri uri = Uri.parse('tel:+963933112233');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      GlobalVar.log(e.toString());
    }
  }

  void _facebookFun() async {
    final Uri fbApp = Uri.parse('fb://page/103594782320636');
    final Uri fbWeb = Uri.parse('https://www.facebook.com/app.jtak/');
    try {
      if (!kIsWeb && !Platform.isIOS && await canLaunchUrl(fbApp)) {
        await launchUrl(fbApp, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(fbWeb, mode: LaunchMode.externalApplication);
      }
    } catch (err) {
      GlobalVar.log(err.toString());
      try {
        await launchUrl(fbWeb, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  void _instagramFun() async {
    final Uri igUri = Uri.parse('https://www.instagram.com/JTAKcompany/');
    try {
      await launchUrl(igUri, mode: LaunchMode.externalApplication);
    } catch (err) {
      GlobalVar.log(err.toString());
    }
  }

  void _whatsappFun(BuildContext context) async {
    const String whatsappPhone = "963933112233";
    final Uri waUri = Uri.parse('https://wa.me/$whatsappPhone');
    try {
      if (await canLaunchUrl(waUri)) {
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يوجد تطبيق واتساب مثبت!')),
          );
        }
      }
    } catch (e) {
      GlobalVar.log(e.toString());
    }
  }

  void _youtubeFun() async {
    final Uri ytUri = Uri.parse('https://www.youtube.com/channel/UCXEnrIm0euKKFEQOROAQPSQ');
    try {
      await launchUrl(ytUri, mode: LaunchMode.externalApplication);
    } catch (err) {
      GlobalVar.log(err.toString());
    }
  }
}
