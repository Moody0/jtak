import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/app/merchant_state_provider.dart';
import '../../../core/controllers/merchant_profile_provider.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/services/upload_service.dart';
import '../../../utils/custom_widgets/messages.dart';
import '../account/login_page.dart';
import '../account/profile_page.dart';
import '../pages/about_app_page.dart';
import '../pages/app_page.dart';
import 'store_location_page.dart';
import 'store_profile_page.dart';

/// ---------------------------------------------------------------------------
/// JTAK Merchant Store Settings & Account Management Overview Page
/// Senior UI/UX Redesign: Full functional parity, real-time status control,
/// sound chime preview, and unified navigation to all sub-pages.
/// ---------------------------------------------------------------------------

class StoreSettingsPage extends StatefulWidget {
  const StoreSettingsPage({super.key});

  @override
  State<StoreSettingsPage> createState() => _StoreSettingsPageState();
}

class _StoreSettingsPageState extends State<StoreSettingsPage> {
  Widget _flippedIcon(IconData icon, {double? size, Color? color}) {
    return Transform.flip(
      flipX: true,
      child: Icon(icon, size: size, color: color),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MerchantProfileProvider>(context, listen: false).loadProfile();
    });
  }

  void _openStoreProfile() {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(context, StoreProfilePage.routeName).then((_) {
      if (mounted) {
        Provider.of<MerchantProfileProvider>(context, listen: false).loadProfile();
      }
    });
  }

  void _openStoreLocation() {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(context, StoreLocationPage.routeName).then((_) {
      if (mounted) {
        Provider.of<MerchantProfileProvider>(context, listen: false).loadProfile();
      }
    });
  }

  void _confirmCloseStore(BuildContext context, MerchantStateProvider merchantProv, MerchantProfileProvider profileProv) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Center(
                  child: _flippedIcon(PhosphorIconsFill.storefront, color: const Color(0xFFDC2626), size: 28),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'إيقاف استقبال الطلبات؟',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: kCharcoalDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'عند إغلاق المتجر مؤقتاً، سيظهر متجرك بحالة «مغلق» ولن يتمكن الزبائن من إرسال طلبات جديدة حتى تقوم بإعادة الفتح.',
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13,
                  color: kCharcoalMedium,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'إلغاء والاحتفاظ به مفتوحاً',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kCharcoalDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        HapticFeedback.mediumImpact();
                        merchantProv.setStoreOpen(false);
                        profileProv.toggleStoreStatus(false);
                        SnackBarWidget.showCustomSnackBar(
                          context,
                          'تم إغلاق المتجر مؤقتاً 🔴',
                          backgroundColor: const Color(0xFF7F1D1D),
                        );
                      },
                      child: Text(
                        'تأكيد الإغلاق',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthenticationService>(context);
    final merchantProvider = Provider.of<MerchantStateProvider>(context);
    final profileProv = Provider.of<MerchantProfileProvider>(context);
    final user = authService.user;
    final p = profileProv.profile;

    final storeName = p?.title.isNotEmpty == true
        ? p!.title
        : (user?.fullName?.isNotEmpty == true ? user!.fullName! : 'متجر شريك جيتك');
    final phone = p?.phone1.isNotEmpty == true
        ? p!.phone1
        : (user?.phoneNumber ?? '');
    final logoUrl = UploadService.resolveImageUrl(p?.logo);
    final coverageKm = (((p?.shippingCoverageInMeters ?? 5000).clamp(0, 30000)) / 1000.0).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: kPageBackground,
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Store Header Profile Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kCardBorderColor, width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Store Avatar Squircle (Tap to edit)
                      GestureDetector(
                        onTap: _openStoreProfile,
                        child: Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3EB),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFFFD6C2), width: 1.2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: logoUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: logoUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Center(
                                      child: _flippedIcon(PhosphorIconsFill.storefront, size: 28, color: kPrimaryOrange),
                                    ),
                                    errorWidget: (_, __, ___) => Center(
                                      child: _flippedIcon(PhosphorIconsFill.storefront, size: 28, color: kPrimaryOrange),
                                    ),
                                  )
                                : Center(
                                    child: _flippedIcon(
                                      PhosphorIconsFill.storefront,
                                      size: 30,
                                      color: kPrimaryOrange,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Store Title & Phone / Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    storeName,
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w800,
                                      color: kCharcoalDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _flippedIcon(
                                  PhosphorIconsFill.sealCheck,
                                  size: 18,
                                  color: kPrimaryOrange,
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              phone.isNotEmpty ? phone : 'متجر معتمد على منصة جيتك',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: kCharcoalMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),

                            // Quick Info Chips
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                // Delivery Coverage Chip
                                InkWell(
                                  onTap: _openStoreLocation,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _flippedIcon(PhosphorIconsRegular.mapPin, size: 12, color: kPrimaryOrange),
                                        const SizedBox(width: 4),
                                        Text(
                                          'نطاق: $coverageKm كم',
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: kCharcoalDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Verified Partner Chip
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFA7F3D0), width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _flippedIcon(PhosphorIconsFill.shieldCheck, size: 12, color: const Color(0xFF059669)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'شريك معتمد',
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF047857),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Edit Profile Button
                      IconButton(
                        icon: _flippedIcon(PhosphorIconsRegular.pencilSimpleLine, color: kPrimaryOrange, size: 20),
                        tooltip: 'تعديل بيانات المتجر',
                        onPressed: _openStoreProfile,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 14),

                  // Store Status Switch Inside Card
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: merchantProvider.isStoreOpen ? kGreen : kRed,
                                boxShadow: [
                                  BoxShadow(
                                    color: (merchantProvider.isStoreOpen ? kGreen : kRed).withValues(alpha: 0.4),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                merchantProvider.isStoreOpen
                                    ? 'حالة المتجر: مفتوح ونستقبل الطلبات'
                                    : 'حالة المتجر: مغلق مؤقتاً',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: merchantProvider.isStoreOpen ? kGreen : kRed,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch.adaptive(
                        value: merchantProvider.isStoreOpen,
                        activeTrackColor: kGreen,
                        onChanged: (val) {
                          if (!val) {
                            // Prompt confirmation before closing store to prevent accidental downtime
                            _confirmCloseStore(context, merchantProvider, profileProv);
                          } else {
                            HapticFeedback.mediumImpact();
                            merchantProvider.setStoreOpen(true);
                            profileProv.toggleStoreStatus(true);
                            SnackBarWidget.showCustomSnackBar(
                              context,
                              'تم فتح المتجر لاستقبال الطلبات 🟢',
                              backgroundColor: const Color(0xFF064E3B),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 2. Sound Alerts Toggle Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kCardBorderColor, width: 1.0),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        // Sound Icon (Tap to test chime)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            merchantProvider.playSoundPreview();
                            SnackBarWidget.showCustomSnackBar(
                              context,
                              'تجربة رنين التنبيه 🔔',
                            );
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3EB),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Center(
                              child: _flippedIcon(
                                merchantProvider.isSoundAlertEnabled
                                    ? PhosphorIconsFill.bellRinging
                                    : PhosphorIconsRegular.bellSlash,
                                size: 20,
                                color: kPrimaryOrange,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'نغمة التنبيه عند وصول طلب جديد',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: kCharcoalDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                merchantProvider.isSoundAlertEnabled ? 'مفعّلة (رنين فوري عند أي طلب)' : 'معطلة (صامتة)',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: kCharcoalMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch.adaptive(
                    value: merchantProvider.isSoundAlertEnabled,
                    activeTrackColor: kPrimaryOrange,
                    onChanged: (val) {
                      merchantProvider.setSoundAlertEnabled(val);
                      SnackBarWidget.showCustomSnackBar(
                        context,
                        val ? 'تم تفعيل نغمة التنبيه للطلبات 🔔' : 'تم كتم نغمة التنبيه 🔕',
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Section Label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                'إعدادات الحساب والمتجر',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: kCharcoalDark,
                ),
              ),
            ),
            const SizedBox(height: 6),

            // 3. Grouped Settings Menu List
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kCardBorderColor, width: 1.0),
              ),
              child: Column(
                children: [
                  // 1) Store Identity & Branding
                  _buildSettingItem(
                    icon: PhosphorIconsRegular.storefront,
                    title: 'هوية المتجر، الشعار وصورة الغلاف',
                    subtitle: 'تعديل الشعار، صورة الغلاف، اسم وتصنيف المتجر',
                    onTap: _openStoreProfile,
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),

                  // 2) Geolocation & Delivery Radius
                  _buildSettingItem(
                    icon: PhosphorIconsRegular.mapPin,
                    title: 'الموقع الجغرافي ونطاق التوصيل',
                    subtitle: 'تحديد العنوان التفصيلي ونصف قطر التغطية (بالكم)',
                    onTap: _openStoreLocation,
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),

                  // 3) Owner Personal Profile
                  _buildSettingItem(
                    icon: PhosphorIconsRegular.user,
                    title: 'البيانات الشخصية للمالك',
                    subtitle: 'اسم المالك، رقم الهاتف المعتمد، والبريد الإلكتروني',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pushNamed(context, ProfilePage.routeName);
                    },
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),

                  // 4) Terms & Conditions
                  _buildSettingItem(
                    icon: PhosphorIconsRegular.fileText,
                    title: 'الشروط وسياسة الاستخدام',
                    subtitle: 'اتفاقية الشركاء وسياسة التوصيل وحقوق المتاجر',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AppPage(
                            pageType: 'TermsAndConditions',
                            pageTitle: 'الشروط وسياسة الاستخدام',
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),

                  // 6) About JTAK Merchant App
                  _buildSettingItem(
                    icon: PhosphorIconsRegular.info,
                    title: 'حول تطبيق جيتك للمتاجر',
                    subtitle: 'بيانات الإصدار، الدعم الفني المباشر، وتواصل الشركاء',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pushNamed(context, AboutAppPage.routeName);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 4. Logout Button
            GestureDetector(
              onTap: () => _confirmLogout(context, authService),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFECACA), width: 1.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'تسجيل الخروج من الحساب',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Transform.flip(
                      flipX: true,
                      child: const Icon(PhosphorIconsRegular.signOut, color: Color(0xFFDC2626), size: 18),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 5. App Version Footer
            Center(
              child: Text(
                'تطبيق جيتك للمتاجر • الإصدار 1.0.3 (Build 15)',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
              ),
              child: Center(
                child: _flippedIcon(icon, size: 19, color: kCharcoalDark),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13.8,
                      fontWeight: FontWeight.w700,
                      color: kCharcoalDark,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1.5),
                    Text(
                      subtitle,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: kCharcoalMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _flippedIcon(
              PhosphorIconsRegular.caretLeft,
              size: 16,
              color: const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthenticationService authService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: _flippedIcon(PhosphorIconsRegular.signOut, color: const Color(0xFFDC2626), size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'تسجيل الخروج',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في تسجيل الخروج من حساب المتجر؟ لن تتلقى إشعارات بالطلبات الجديدة أثناء تسجيل الخروج.',
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 13.5, color: kCharcoalMedium, height: 1.45),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'إلغاء',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700, color: kCharcoalMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await authService.logOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, LoginPage.routeName, (route) => false);
              }
            },
            child: Text(
              'تسجيل الخروج',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
