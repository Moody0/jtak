import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/user/address_provider.dart';
import '../../../core/enums/address_type_enum.dart';
import '../../../core/models/user/address_model.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/services/locator.dart';
import '../../../utils/custom_widgets/loading.dart';
import '../account/login_page.dart';
import 'add_address_page.dart';
import 'widgets.dart';
import '../../widgets/header_circle_button.dart';

class AddressPage extends StatefulWidget {
  static const String routeName = '/AddressPage';

  const AddressPage({super.key});

  @override
  State<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<AddressPage> {
  late AddressProvider provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AddressProvider>().loadData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    provider = Provider.of<AddressProvider>(context);
    final isLogin = locator<AuthenticationService>().isLogin();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: FullScreenLoading(
          inAsyncCall: provider.isBusy,
          child: !isLogin
              ? _buildGuestView(context)
              : RefreshIndicator(
                  color: kPrimaryOrange,
                  onRefresh: () => provider.loadData(),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                    children: [
                      // 1. Add New Address Primary CTA
                      _buildAddAddressPrimaryCard(context),

                      const SizedBox(height: 14),

                      // 2. Quick Presets Row (Home, Work, Other)
                      _buildQuickPresetsRow(context),

                      const SizedBox(height: 22),

                      // 3. Saved Addresses Section Header
                      _buildSavedAddressesHeader(),

                      const SizedBox(height: 12),

                      // 4. Saved Addresses List
                      _buildAddressList(context),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      leading: Center(
        child: HeaderCircleButton.back(
          onTap: () => Navigator.pop(context),
        ),
      ),
      title: Text(
        'عناوين التوصيل',
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 18.5,
          fontWeight: FontWeight.w800,
          color: kCharcoalDark,
        ),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFFF1F5F9), thickness: 1),
      ),
    );
  }

  Widget _buildGuestView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E8),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Center(
                child: Icon(
                  PhosphorIconsFill.mapPin,
                  color: kPrimaryOrange,
                  size: 40,
                  textDirection: TextDirection.ltr,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'تسجيل الدخول لإدارة العناوين',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 19.5,
                fontWeight: FontWeight.w800,
                color: kCharcoalDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'سجّل الدخول لحفظ وإدارة عناوينك المفضلة (المنزل، العمل) وتسهيل وصول طلباتك بدقة.',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 26),
            GestureDetector(
              onTap: () async {
                HapticFeedback.mediumImpact();
                var res = await Navigator.pushNamed(context, LoginPage.routeName);
                if (res is bool && res && context.mounted) {
                  provider.loadData();
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: kPrimaryOrange,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'تسجيل الدخول / إنشاء حساب',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
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

  Widget _buildAddAddressPrimaryCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFFFF3EB), Color(0xFFFFECE0)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kPrimaryOrange.withValues(alpha: 0.25), width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _navigateToAddAddress(context, 'عنوان جديد'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: kPrimaryOrange,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Center(
                    child: Icon(
                      PhosphorIconsFill.mapPinPlus,
                      color: Colors.white,
                      size: 22,
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إضافة عنوان جديد',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: kCharcoalDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'تحديد الموقع الدقيق للعنوان على الخريطة',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  PhosphorIconsRegular.caretLeft,
                  color: kPrimaryOrange,
                  size: 18,
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickPresetsRow(BuildContext context) {
    final presets = [
      {
        'title': 'المنزل',
        'icon': PhosphorIconsFill.house,
        'color': kPrimaryOrange,
        'bg': const Color(0xFFFFF0E8),
      },
      {
        'title': 'العمل',
        'icon': PhosphorIconsFill.buildings,
        'color': const Color(0xFF3B82F6),
        'bg': const Color(0xFFEFF6FF),
      },
      {
        'title': 'أخرى',
        'icon': PhosphorIconsFill.mapPin,
        'color': const Color(0xFF10B981),
        'bg': const Color(0xFFECFDF5),
      },
    ];

    return Row(
      children: presets.map((p) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _navigateToAddAddress(context, p['title'] as String),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        p['icon'] as IconData,
                        size: 16,
                        color: p['color'] as Color,
                        textDirection: TextDirection.ltr,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '+ ${p['title']}',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: kCharcoalDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSavedAddressesHeader() {
    final count = provider.dataList.where((a) => a.id != null && a.id != 0).length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              'العناوين المحفوظة',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: kCharcoalDark,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildAddressList(BuildContext context) {
    final list = provider.dataList.where((a) => a.id != null && a.id != 0).toList();

    if (list.isEmpty && !provider.isBusy) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        ),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Icon(
                  PhosphorIconsFill.mapPinLine,
                  color: Color(0xFF94A3B8),
                  size: 26,
                  textDirection: TextDirection.ltr,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'لا توجد عناوين محفوظة بعد',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: kCharcoalDark,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'أضف عنوانك لتسريع عملية الطلب والتوصيل إلى باب منزلك',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: list.map((e) => AddressSingleItem(e)).toList(),
    );
  }

  void _navigateToAddAddress(BuildContext context, String title) async {
    HapticFeedback.lightImpact();
    if (!locator<AuthenticationService>().isLogin()) {
      var res = await Navigator.pushNamed(context, LoginPage.routeName);
      if (res is bool && res && context.mounted) {
        provider.address = AddressModel(addressType: AddressType.shipping, title: title);
        Navigator.pushNamed(context, AddAddressPage.routeName);
      }
      return;
    }

    provider.address = AddressModel(addressType: AddressType.shipping, title: title);
    Navigator.pushNamed(context, AddAddressPage.routeName);
  }
}
