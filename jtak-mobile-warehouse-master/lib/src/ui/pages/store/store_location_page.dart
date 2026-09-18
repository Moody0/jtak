import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/merchant_profile_provider.dart';
import '../../../core/services/locator.dart';
import '../../../utils/custom_widgets/messages.dart';
import '../../../utils/utilities/lunch_url.dart';

/// ---------------------------------------------------------------------------
/// Store Location & Delivery Coverage Page
/// Allows merchant to configure store address, delivery radius (km/meters)
/// and GPS coordinates with Google Maps integration.
/// ---------------------------------------------------------------------------

class StoreLocationPage extends StatefulWidget {
  static const String routeName = '/StoreLocationPage';

  const StoreLocationPage({super.key});

  @override
  State<StoreLocationPage> createState() => _StoreLocationPageState();
}

class _StoreLocationPageState extends State<StoreLocationPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _addressController;
  late TextEditingController _latController;
  late TextEditingController _lngController;

  double _coverageKm = 5.0; // default 5 km
  bool _isSaving = false;

  final List<double> _presetDistances = [2.0, 5.0, 10.0, 15.0, 20.0, 30.0];

  @override
  void initState() {
    super.initState();
    final profile = locator<MerchantProfileProvider>().profile;
    _addressController = TextEditingController(text: profile?.address ?? '');
    _latController = TextEditingController(
      text: (profile?.lat != null && profile!.lat != 0.0) ? profile.lat.toString() : '',
    );
    _lngController = TextEditingController(
      text: (profile?.lng != null && profile!.lng != 0.0) ? profile.lng.toString() : '',
    );

    final meters = profile?.shippingCoverageInMeters ?? 5000;
    _coverageKm = (meters / 1000.0).clamp(1.0, 30.0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final provider = Provider.of<MerchantProfileProvider>(context, listen: false);
    if (provider.profile == null) {
      await provider.loadProfile();
    }
    final p = provider.profile;
    if (p != null && mounted) {
      setState(() {
        if (_addressController.text.isEmpty) {
          _addressController.text = p.address;
        }
        if (_latController.text.isEmpty && p.lat != 0.0) {
          _latController.text = p.lat.toString();
        }
        if (_lngController.text.isEmpty && p.lng != 0.0) {
          _lngController.text = p.lng.toString();
        }
        _coverageKm = (p.shippingCoverageInMeters / 1000.0).clamp(1.0, 30.0);
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      final provider = Provider.of<MerchantProfileProvider>(context, listen: false);
      final p = provider.profile;

      final coverageMeters = (_coverageKm.clamp(1.0, 30.0) * 1000).round().clamp(0, 30000);
      final latVal = double.tryParse(_latController.text.trim()) ?? p?.lat ?? 0.0;
      final lngVal = double.tryParse(_lngController.text.trim()) ?? p?.lng ?? 0.0;

      final success = await provider.updateProfile(
        title: p?.title ?? '',
        shortDescription: p?.shortDescription ?? '',
        description: p?.description ?? '',
        phone1: p?.phone1 ?? '',
        phone2: p?.phone2 ?? '',
        address: _addressController.text.trim(),
        shippingCoverageInMeters: coverageMeters,
        logo: p?.logo,
        coverBanner: p?.coverBanner,
        lat: latVal != 0.0 ? latVal : null,
        lng: lngVal != 0.0 ? lngVal : null,
      );

      if (!mounted) return;

      if (success) {
        SnackBarWidget.showCustomSnackBar(
          context,
          'تم تحديث العنوان ونطاق التوصيل بنجاح 🟢',
          backgroundColor: const Color(0xFF064E3B),
        );
        Navigator.pop(context, true);
      } else {
        SnackBarWidget.showCustomSnackBar(
          context,
          provider.errorMessage ?? 'تعذر حفظ البيانات، يرجى المحاولة ثانية',
          backgroundColor: const Color(0xFF7F1D1D),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _openGoogleMapsPreview() async {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());

    String url;
    if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
      url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    } else if (_addressController.text.trim().isNotEmpty) {
      final query = Uri.encodeComponent(_addressController.text.trim());
      url = 'https://www.google.com/maps/search/?api=1&query=$query';
    } else {
      SnackBarWidget.showCustomSnackBar(
        context,
        'يرجى إدخال العنوان أو الإحداثيات لمعاينتها على الخريطة',
        backgroundColor: const Color(0xFF92400E),
      );
      return;
    }

    final launched = await LunchUrl.canLaunch(url);
    if (!launched && mounted) {
      SnackBarWidget.showCustomSnackBar(
        context,
        'تعذر فتح تطبيق الخرائط على هذا الجهاز',
        backgroundColor: const Color(0xFF7F1D1D),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileProv = Provider.of<MerchantProfileProvider>(context);
    final isBusy = profileProv.isLoading || profileProv.isSaving || _isSaving;

    return Scaffold(
      backgroundColor: kPageBackground,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'الموقع الجغرافي ونطاق التوصيل',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: kCharcoalDark,
          ),
        ),
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowRight, color: kCharcoalDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: isBusy ? null : _handleSave,
            child: isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryOrange),
                  )
                : Text(
                    'حفظ',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kPrimaryOrange,
                    ),
                  ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Info Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE), width: 1.0),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(PhosphorIconsFill.mapPin, color: Color(0xFF1D4ED8), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تغطية التوصيل والظهور للزبائن',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'يحدد نطاق التوصيل الزبائن الذين يظهر لهم متجرك في تطبيق جيتك ويتمكنون من الطلب منك مباشرة.',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1E40AF),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Physical Address Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kCardBorderColor, width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3EB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(PhosphorIconsRegular.mapPinLine, color: kPrimaryOrange, size: 20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'عنوان المتجر الفعلي',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: kCharcoalDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'العنوان بالتفصيل *',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: kCharcoalMedium,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _addressController,
                    maxLines: 2,
                    validator: (v) => v == null || v.trim().isEmpty ? 'يرجى إدخال عنوان المتجر' : null,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: kCharcoalDark,
                    ),
                    decoration: InputDecoration(
                      hintText: 'مثال: دمشق، المزة، أوتوستراد المزة بجانب بنك البركة',
                      hintStyle: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12.5,
                        color: const Color(0xFF94A3B8),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: kPrimaryOrange, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. Delivery Radius & Coverage Slider Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kCardBorderColor, width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3EB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Icon(PhosphorIconsRegular.navigationArrow, color: kPrimaryOrange, size: 20),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'نطاق تغطية التوصيل',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: kCharcoalDark,
                            ),
                          ),
                        ],
                      ),
                      // Value Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3EB),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFFD6C2)),
                        ),
                        child: Text(
                          '${_coverageKm.toStringAsFixed(1)} كم (${(_coverageKm * 1000).toInt()} م)',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: kPrimaryOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Slider
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: kPrimaryOrange,
                      inactiveTrackColor: const Color(0xFFFFE3D3),
                      thumbColor: kPrimaryOrange,
                      overlayColor: kPrimaryOrange.withValues(alpha: 0.15),
                      trackHeight: 6,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                    ),
                    child: Slider(
                      value: _coverageKm,
                      min: 1.0,
                      max: 30.0,
                      divisions: 58, // 0.5 km steps
                      onChanged: (val) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _coverageKm = val;
                        });
                      },
                    ),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '1 كم (نطاق قريب)',
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: kCharcoalMuted),
                      ),
                      Text(
                        '30 كم (أقصى نطاق)',
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: kCharcoalMuted),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'خيارات سريعة لنطاق التوصيل:',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kCharcoalMedium,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Preset Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _presetDistances.map((km) {
                      final isSelected = (_coverageKm - km).abs() < 0.2;
                      return ChoiceChip(
                        label: Text('${km.toInt()} كم'),
                        labelStyle: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : kCharcoalDark,
                        ),
                        selected: isSelected,
                        selectedColor: kPrimaryOrange,
                        backgroundColor: const Color(0xFFF1F5F9),
                        onSelected: (selected) {
                          if (selected) {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _coverageKm = km;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 4. GPS Coordinates Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kCardBorderColor, width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3EB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(PhosphorIconsRegular.crosshair, color: kPrimaryOrange, size: 20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'إحداثيات الموقع (GPS Coordinates)',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: kCharcoalDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'خط العرض (Latitude)',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: kCharcoalMedium,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _latController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: kCharcoalDark,
                              ),
                              decoration: InputDecoration(
                                hintText: '33.5138',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'خط الطول (Longitude)',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: kCharcoalMedium,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _lngController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: kCharcoalDark,
                              ),
                              decoration: InputDecoration(
                                hintText: '36.2765',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Open Google Maps Button
                  OutlinedButton.icon(
                    onPressed: _openGoogleMapsPreview,
                    icon: const Icon(PhosphorIconsRegular.googleLogo, size: 18, color: Color(0xFF1E3A8A)),
                    label: Text(
                      'معاينة الموقع على خرائط Google',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E3A8A),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 5. Submit Button
            ElevatedButton(
              onPressed: isBusy ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryOrange,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: isBusy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(PhosphorIconsRegular.checkCircle, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'حفظ الموقع ونطاق التوصيل',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
