import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../../main_imports.dart';
import '../../../config/themes/colors.dart';
import '../../../core/controllers/app_parameters_provider.dart';
import '../../../core/controllers/user/address_provider.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/services/locator.dart';
import '../../../utils/custom_widgets/init_widget.dart';
import '../../../utils/custom_widgets/loading.dart';
import '../../../utils/custom_widgets/messages.dart';
import '../../../utils/utilities/validation.dart';
import 'choose_location_map_page.dart';
import 'search_address_page.dart';
import '../account/login_page.dart';
import '../../widgets/header_circle_button.dart';

class AddAddressPage extends StatefulWidget {
  static const String routeName = '/AddAddressPage';

  const AddAddressPage({super.key});

  @override
  State<AddAddressPage> createState() => _AddAddressPageState();
}

class _AddAddressPageState extends State<AddAddressPage> {
  late AddressProvider provider;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _detailsController;

  @override
  void initState() {
    super.initState();
    final addressProvider = Provider.of<AddressProvider>(context, listen: false);
    addressProvider.stage = 0;
    _titleController = TextEditingController(text: addressProvider.address.title ?? 'المنزل');
    _detailsController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    provider = Provider.of<AddressProvider>(context);
    final isLogin = locator<AuthenticationService>().isLogin();

    if (!isLogin) {
      return _buildGuestGate(context);
    }

    return PopScope(
      canPop: provider.stage == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && provider.stage == 1) {
          provider.setStage(0);
        }
      },
      child: FullScreenLoading(
        inAsyncCall: provider.isBusy,
        child: Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: true,
          appBar: _buildAppBar(context),
          body: SafeArea(
            child: Stack(
              children: [
                // 1. Google Map Fullscreen
                const Positioned.fill(
                  child: ChooseLocationMapPage(),
                ),

                // 2. Bottom Floating Action Sheet
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildBottomSection(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildGuestAppBar(BuildContext context) {
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
        'إضافة عنوان جديد',
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

  Widget _buildGuestGate(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildGuestAppBar(context),
      body: SafeArea(
        child: Center(
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
                      PhosphorIconsFill.mapPinPlus,
                      color: kPrimaryOrange,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'تسجيل الدخول لإضافة عنوان',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 19.5,
                    fontWeight: FontWeight.w800,
                    color: kCharcoalDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'يتطلب حفظ وإضافة عنوان جديد إلى حسابك تسجيل الدخول أولاً لتتمكن من استخدامه في جميع طلباتك.',
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
                    final res = await Navigator.pushNamed(context, LoginPage.routeName);
                    if (res is bool && res && mounted) {
                      setState(() {});
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: kPrimaryOrange,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x40FF5400),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
          onTap: () {
            if (provider.stage == 1) {
              provider.setStage(0);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      actions: [
        if (provider.stage == 0)
          Center(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 14),
              child: HeaderCircleButton.search(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SearchAddressPage(),
                    ),
                  );
                  if (result is Map<String, dynamic> && context.mounted) {
                    final double lat = result['lat'] ?? 0.0;
                    final double lon = result['lon'] ?? 0.0;
                    if (lat != 0.0 && lon != 0.0) {
                      provider.mapAnimateToPosision(LatLng(lat, lon));
                    }
                  }
                },
              ),
            ),
          ),
      ],
      title: Text(
        provider.stage == 0 ? 'تحديد موقع التوصيل' : 'تفاصيل العنوان',
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

  Widget _buildBottomSection(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
      ),
      child: provider.stage == 0 ? _buildStage0LocationSheet(context) : _buildStage1DetailsSheet(context),
    );
  }

  // ---------------------------------------------------------------------------
  // Stage 0: Pin Location on Map
  // ---------------------------------------------------------------------------
  Widget _buildStage0LocationSheet(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Icon(
                  PhosphorIconsFill.mapPin,
                  color: kPrimaryOrange,
                  size: 22,
                  textDirection: TextDirection.ltr,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الموقع المحدد للتوصيل',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: kCharcoalDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    provider.isGeocodingLocation
                        ? 'جارٍ قراءة العنوان بدقة...'
                        : (provider.locationAddressName?.isNotEmpty == true
                            ? provider.locationAddressName!
                            : 'حرّك الخريطة لتحديد موقع باب البناء أو المنزل'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12.5,
                      fontWeight: (provider.locationAddressName?.isNotEmpty == true && !provider.isGeocodingLocation)
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: (provider.locationAddressName?.isNotEmpty == true && !provider.isGeocodingLocation)
                          ? kPrimaryOrange
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Confirm Location CTA
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            if (_detailsController.text.isEmpty && provider.locationAddressName != null) {
              _detailsController.text = provider.locationAddressName!;
            }
            provider.setLocation();
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: kPrimaryOrange,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'تأكيد ومتابعة تفاصيل العنوان',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  PhosphorIconsRegular.arrowLeft,
                  color: Colors.white,
                  size: 18,
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Stage 1: Enter Detailed Address Form
  // ---------------------------------------------------------------------------
  Widget _buildStage1DetailsSheet(BuildContext context) {
    final presets = [
      {'title': 'المنزل', 'icon': PhosphorIconsFill.house},
      {'title': 'العمل', 'icon': PhosphorIconsFill.buildings},
      {'title': 'أخرى', 'icon': PhosphorIconsFill.mapPin},
    ];

    return SingleChildScrollView(
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar with Edit Location Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'بيانات وتفاصيل العنوان',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: kCharcoalDark,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    provider.setStage(0);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          PhosphorIconsRegular.pencilSimple,
                          size: 13,
                          color: Color(0xFF475569),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'تعديل الموقع',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Quick Preset Tag Selector
            Row(
              children: presets.map((p) {
                final isSelected = _titleController.text.trim() == p['title'];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _titleController.text = p['title'] as String;
                          provider.address.title = p['title'] as String;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFFFF0E8) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? kPrimaryOrange : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.4 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              p['icon'] as IconData,
                              size: 15,
                              color: isSelected ? kPrimaryOrange : const Color(0xFF64748B),
                              textDirection: TextDirection.ltr,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              p['title'] as String,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? kPrimaryOrange : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Address Title Field
            Text(
              'تسمية العنوان',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _titleController,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: kCharcoalDark,
              ),
              decoration: InputDecoration(
                hintText: 'مثال: المنزل، شقة المزة، المكتب',
                hintStyle: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12.5,
                  color: const Color(0xFF94A3B8),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: kPrimaryOrange, width: 1.5),
                ),
              ),
              validator: (value) => ValidationUtil.stringLengthValidation(
                value,
                'يرجى إدخال تسمية للعنوان',
                requirLength: 2,
              ),
              onChanged: (value) => provider.address.title = value.trim(),
            ),
            const SizedBox(height: 12),

            // Address Details Field (Optional)
            Row(
              children: [
                Text(
                  'تفاصيل العنوان الدقيقة',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '(اختياري)',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _detailsController,
              maxLines: 2,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: kCharcoalDark,
              ),
              decoration: InputDecoration(
                hintText: 'مثال: اسم البناء، الطابق، رقم الشقة، علامة مميزة...',
                hintStyle: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12,
                  color: const Color(0xFF94A3B8),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: kPrimaryOrange, width: 1.5),
                ),
              ),
              validator: null,
              onChanged: (value) => provider.address.fullAddress = value.trim(),
            ),
            const SizedBox(height: 16),

            // Save CTA Button
            GestureDetector(
              onTap: () async {
                HapticFeedback.mediumImpact();
                try {
                  if (validate()) {
                    provider.address.title = _titleController.text.trim().isNotEmpty
                        ? _titleController.text.trim()
                        : 'المنزل';

                    final customDetails = _detailsController.text.trim();
                    if (customDetails.isNotEmpty) {
                      provider.address.fullAddress = customDetails;
                    } else if (provider.locationAddressName?.isNotEmpty == true) {
                      provider.address.fullAddress = provider.locationAddressName!;
                    } else if (provider.address.fullAddress == null || provider.address.fullAddress!.isEmpty) {
                      provider.address.fullAddress = 'الموقع المحدد على الخريطة';
                    }

                    if (locator<AuthenticationService>().isLogin()) {
                      await provider.saveFun();
                    }
                    locator<AppParametersProvider>().mainAddressService.setMainAddress(provider.address);
                    provider.globalMessage = 'تم حفظ وتحديد العنوان بنجاح';
                    if (context.mounted) {
                      InitWidget.restartApp(context);
                    }
                  }
                } catch (err) {
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => CustomDialog(message: err.toString()),
                    );
                  }
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
                    'حفظ العنوان واعتماده للتوصيل',
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

  bool validate() {
    bool valid = true;
    if (provider.address.lat == null || provider.address.lng == null) {
      valid = false;
      context.showSnakBar('يرجى تحديد الموقع على الخريطة أولاً');
    }
    if (!(formKey.currentState?.validate() ?? false)) {
      valid = false;
    }
    return valid;
  }
}
