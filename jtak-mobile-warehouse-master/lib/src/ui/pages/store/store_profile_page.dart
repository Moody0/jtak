import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/merchant_profile_provider.dart';
import '../../../core/services/locator.dart';
import '../../../core/services/upload_service.dart';
import '../../../utils/custom_widgets/messages.dart';

/// ---------------------------------------------------------------------------
/// Store Profile Page: Full Control over Brand Logo, Cover Banner, Info & Hours
/// ---------------------------------------------------------------------------

class StoreProfilePage extends StatefulWidget {
  static const String routeName = '/StoreProfilePage';

  const StoreProfilePage({super.key});

  @override
  State<StoreProfilePage> createState() => _StoreProfilePageState();
}

class _StoreProfilePageState extends State<StoreProfilePage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _shortDescController;
  late TextEditingController _descriptionController;
  late TextEditingController _phone1Controller;
  late TextEditingController _phone2Controller;
  late TextEditingController _addressController;
  late TextEditingController _coverageController;

  String? _localLogoPath;
  String? _localCoverPath;
  bool _isStoreActive = true;
  bool _isSaving = false;

  String _normalizeDigits(String input) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    var res = input;
    for (int i = 0; i < 10; i++) {
      res = res.replaceAll(arabicDigits[i], '$i');
      res = res.replaceAll(persianDigits[i], '$i');
    }
    return res;
  }

  @override
  void initState() {
    super.initState();
    final cached = locator<MerchantProfileProvider>().profile;
    _titleController = TextEditingController(text: cached?.title ?? '');
    _shortDescController = TextEditingController(text: cached?.shortDescription ?? '');
    _descriptionController = TextEditingController(text: cached?.description ?? '');
    _phone1Controller = TextEditingController(text: cached?.phone1 ?? '');
    _phone2Controller = TextEditingController(text: cached?.phone2 ?? '');
    _addressController = TextEditingController(text: cached?.address ?? '');
    _coverageController = TextEditingController(
      text: (cached?.shippingCoverageInMeters ?? 5000).toString(),
    );
    _isStoreActive = cached?.active ?? true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _shortDescController.dispose();
    _descriptionController.dispose();
    _phone1Controller.dispose();
    _phone2Controller.dispose();
    _addressController.dispose();
    _coverageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final provider = Provider.of<MerchantProfileProvider>(context, listen: false);
    await provider.loadProfile();
    final p = provider.profile;
    if (p != null && mounted) {
      setState(() {
        _titleController.text = p.title;
        _shortDescController.text = p.shortDescription;
        _descriptionController.text = p.description;
        _phone1Controller.text = p.phone1;
        _phone2Controller.text = p.phone2;
        _addressController.text = p.address;
        _coverageController.text = p.shippingCoverageInMeters.toString();
        _isStoreActive = p.active;
      });
    }
  }

  Future<void> _pickImage(bool isCover) async {
    final uploadService = locator<UploadService>();
    final source = await _showSourceSelectorSheet();
    if (source == null) return;

    final path = await uploadService.pickImage(source: source);
    if (path != null && mounted) {
      setState(() {
        if (isCover) {
          _localCoverPath = path;
        } else {
          _localLogoPath = path;
        }
      });
    }
  }

  Future<ImageSource?> _showSourceSelectorSheet() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'اختيار مصدر الصورة',
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kCharcoalDark,
                ),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3EB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(PhosphorIconsRegular.camera, color: kPrimaryOrange, size: 22),
                  ),
                ),
                title: Text(
                  'التقاط صورة بالكاميرا',
                  style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3EB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(PhosphorIconsRegular.images, color: kPrimaryOrange, size: 22),
                  ),
                ),
                title: Text(
                  'اختيار من معرض الصور',
                  style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      final profileProv = Provider.of<MerchantProfileProvider>(context, listen: false);
      final uploadService = locator<UploadService>();

      String? finalCoverId = profileProv.profile?.coverBanner;
      String? finalLogoId = profileProv.profile?.logo;

      // Upload local cover if picked
      if (_localCoverPath != null) {
        final uploadedCover = await uploadService.uploadImage(_localCoverPath!);
        if (uploadedCover != null) {
          finalCoverId = uploadedCover;
        } else {
          if (!mounted) return;
          SnackBarWidget.showCustomSnackBar(
            context,
            'تعذر رفع صورة الغلاف، يرجى التأكد من اتصال الإنترنت والمحاولة ثانية',
            backgroundColor: const Color(0xFF7F1D1D),
          );
          return;
        }
      }

      // Upload local logo if picked
      if (_localLogoPath != null) {
        final uploadedLogo = await uploadService.uploadImage(_localLogoPath!);
        if (uploadedLogo != null) {
          finalLogoId = uploadedLogo;
        } else {
          if (!mounted) return;
          SnackBarWidget.showCustomSnackBar(
            context,
            'تعذر رفع صورة الشعار، يرجى التأكد من اتصال الإنترنت والمحاولة ثانية',
            backgroundColor: const Color(0xFF7F1D1D),
          );
          return;
        }
      }

      final cleanCoverageStr = _normalizeDigits(_coverageController.text.trim());
      final coverage = int.tryParse(cleanCoverageStr) ?? 5000;

      final success = await profileProv.updateProfile(
        title: _titleController.text.trim(),
        shortDescription: _shortDescController.text.trim(),
        description: _descriptionController.text.trim(),
        phone1: _normalizeDigits(_phone1Controller.text.trim()),
        phone2: _normalizeDigits(_phone2Controller.text.trim()),
        address: _addressController.text.trim(),
        shippingCoverageInMeters: coverage,
        logo: finalLogoId,
        coverBanner: finalCoverId,
        lat: profileProv.profile?.lat,
        lng: profileProv.profile?.lng,
      );

      if (!mounted) return;

      if (success) {
        // Also sync active status if changed
        if (_isStoreActive != (profileProv.profile?.active ?? true)) {
          await profileProv.toggleStoreStatus(_isStoreActive);
        }

        SnackBarWidget.showCustomSnackBar(
          context,
          'تم حفظ بيانات المتجر والشعار بنجاح 🟢',
          backgroundColor: const Color(0xFF064E3B),
        );
        Navigator.pop(context, true);
      } else {
        SnackBarWidget.showCustomSnackBar(
          context,
          profileProv.errorMessage ?? 'حدث خطأ أثناء حفظ البيانات',
          backgroundColor: const Color(0xFF7F1D1D),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileProv = Provider.of<MerchantProfileProvider>(context);
    final isBusy = profileProv.isLoading || profileProv.isSaving || _isSaving;

    return Scaffold(
      backgroundColor: kPageBackground,
      appBar: AppBar(
        title: Text(
          'تخصيص وهوية المتجر',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: kCharcoalDark,
          ),
        ),
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft, color: kCharcoalDark),
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
      ),
      body: profileProv.isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryOrange))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  // 1. Cover Banner & Overlapping Logo Section
                  _buildVisualsSection(profileProv),

                  const SizedBox(height: 24),

                  // 2. Store Basic Identity Card
                  _buildCard(
                    title: 'هوية وبيانات المتجر',
                    icon: PhosphorIconsRegular.storefront,
                    children: [
                      _buildTextField(
                        controller: _titleController,
                        label: 'اسم المتجر / المطعم *',
                        hint: 'مثال: شاورما أنس الدمشقي',
                        validator: (v) => v == null || v.trim().isEmpty ? 'اسم المتجر مطلوب' : null,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _shortDescController,
                        label: 'التصنيف والوصف المختصر',
                        hint: 'مثال: شاورما، وجبات سريعة، مأكولات شرقية وغربية',
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'نبذة عن المتجر (Bio)',
                        hint: 'اكتب وصفاً جذاباً يعرف الزبائن بما يميز وجباتكم وأطباقكم...',
                        maxLines: 3,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 3. Contact & Phone Numbers Card
                  _buildCard(
                    title: 'أرقام التواصل والتنسيق',
                    icon: PhosphorIconsRegular.phoneCall,
                    children: [
                      _buildTextField(
                        controller: _phone1Controller,
                        label: 'رقم الهاتف الأساسي للطلبات *',
                        hint: '09xxxxxxxx',
                        keyboardType: TextInputType.phone,
                        validator: (v) => v == null || v.trim().isEmpty ? 'رقم الهاتف مطلوب' : null,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _phone2Controller,
                        label: 'رقم الواتساب / رقم إضافي',
                        hint: '09xxxxxxxx',
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 4. Address & Coverage Card
                  _buildCard(
                    title: 'الموقع الجغرافي ونطاق التوصيل',
                    icon: PhosphorIconsRegular.mapPin,
                    children: [
                      _buildTextField(
                        controller: _addressController,
                        label: 'عنوان المتجر بالتفصيل',
                        hint: 'دمشق، المزة، أوتوستراد المزة بجانب...',
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _coverageController,
                        label: 'نطاق التوصيل بالمتر (Shipping Coverage)',
                        hint: '5000',
                        keyboardType: TextInputType.number,
                        suffixText: 'متر',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 5. Receiving Orders Switch Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kCardBorderColor, width: 1.0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isStoreActive ? kGreen : kRed,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isStoreActive ? 'المتجر متاح ويستقبل الطلبات' : 'المتجر مغلق مؤقتاً',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: _isStoreActive ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                  ),
                                ),
                                Text(
                                  _isStoreActive ? 'يظهر للزبائن كمتجر نشط' : 'لا يمكن للزبائن إرسال طلبات جديدة',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 11.5,
                                    color: kCharcoalMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch.adaptive(
                          value: _isStoreActive,
                          activeTrackColor: kGreen,
                          onChanged: (val) {
                            setState(() {
                              _isStoreActive = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 6. Sticky Save Changes Button
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
                                'حفظ كل التعديلات',
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

  Widget _buildVisualsSection(MerchantProfileProvider provider) {
    final existingCover = UploadService.resolveImageUrl(provider.profile?.coverBanner);
    final existingLogo = UploadService.resolveImageUrl(provider.profile?.logo);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kCardBorderColor, width: 1.0),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Column(
            children: [
              // Cover Banner Box
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                child: SizedBox(
                  width: double.infinity,
                  height: 150,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Banner Image
                      if (_localCoverPath != null)
                        Image.file(File(_localCoverPath!), fit: BoxFit.cover)
                      else if (existingCover.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: existingCover,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: const Color(0xFFF1F5F9)),
                          errorWidget: (_, __, ___) => _buildPlaceholderCover(),
                        )
                      else
                        _buildPlaceholderCover(),

                      // Gradient Overlay
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black26, Colors.transparent, Colors.black45],
                          ),
                        ),
                      ),

                      // Change Cover Pill Button
                      Positioned(
                        top: 12,
                        left: 12,
                        child: GestureDetector(
                          onTap: () => _pickImage(true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white30, width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(PhosphorIconsRegular.camera, size: 15, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  'تغيير الغلاف',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Spacing beneath banner for overlapping logo
              const SizedBox(height: 48),
            ],
          ),

          // Overlapping Logo Squircle
          Positioned(
            bottom: 6,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                GestureDetector(
                  onTap: () => _pickImage(false),
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 3.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1F000000),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _localLogoPath != null
                          ? Image.file(File(_localLogoPath!), fit: BoxFit.cover)
                          : existingLogo.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: existingLogo,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(color: const Color(0xFFFFF3EB)),
                                  errorWidget: (_, __, ___) => _buildPlaceholderLogo(),
                                )
                              : _buildPlaceholderLogo(),
                    ),
                  ),
                ),

                // Camera Badge Button on Logo
                GestureDetector(
                  onTap: () => _pickImage(false),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: kPrimaryOrange,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      PhosphorIconsRegular.camera,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      color: const Color(0xFFFFF3EB),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(PhosphorIconsRegular.image, size: 36, color: Color(0xFFFFB28A)),
          const SizedBox(height: 6),
          Text(
            'اضغط لإضافة صورة غلاف للمتجر',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFC45A2C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderLogo() {
    return Container(
      color: const Color(0xFFFFF3EB),
      child: const Center(
        child: Icon(PhosphorIconsFill.storefront, size: 34, color: kPrimaryOrange),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3EB),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Icon(icon, size: 18, color: kPrimaryOrange),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: kCharcoalDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? suffixText,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: kCharcoalMedium,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 13.5,
            color: kCharcoalDark,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12.5,
              color: const Color(0xFF94A3B8),
            ),
            suffixText: suffixText,
            suffixStyle: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kCharcoalMuted,
            ),
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
    );
  }
}
