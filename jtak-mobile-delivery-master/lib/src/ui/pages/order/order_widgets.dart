import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/order_provider.dart';
import '../../../core/enums/order_details_status_enum.dart';
import '../../../core/models/merchant_order_details.dart';
import '../../../core/models/order_details_model.dart';
import '../../../core/models/order_model.dart';
import '../../../ui/widgets/app_widgets.dart';
import '../../../ui/widgets/quick_chat_sheet.dart';
import '../../../utils/custom_widgets/image_widgets.dart';
import '../../../utils/utilities/global_var.dart';
import '../../../utils/utilities/phone_helper.dart';
import 'order_details_page.dart';

// -----------------------------------------------------------------------------
// 1. Proof of Delivery (PoD) Verification Dialog
// -----------------------------------------------------------------------------
class PoDVerificationDialog extends StatefulWidget {
  final OrderModel order;

  const PoDVerificationDialog({required this.order, Key? key})
      : super(key: key);

  static Future<bool?> show(BuildContext context, OrderModel order) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PoDVerificationDialog(order: order),
    );
  }

  @override
  State<PoDVerificationDialog> createState() => _PoDVerificationDialogState();
}

class _PoDVerificationDialogState extends State<PoDVerificationDialog> {
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _isPhotoMode = false;
  XFile? _capturedPhoto;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _otpController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleOtpSubmit(OrderProvider orderProv, bool isArabic) async {
    final clean =
        PhoneHelper.cleanDigits(_otpController.text).replaceAll('+', '');
    if (clean.length < 4) {
      setState(() {
        _errorMessage = isArabic
            ? 'يرجى إدخال رمز التحقق المكون من 4 أرقام'
            : 'Please enter the 4-digit verification code';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final success =
          await orderProv.deliverOrder(widget.order.id!, otp: clean);
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'تم تأكيد تسليم الطلب #${widget.order.id} بنجاح ✓'
                  : 'Order #${widget.order.id} delivered successfully ✓',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
            ),
            backgroundColor: kGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('Error: ', '')
            .trim();
      });
    }
  }

  Future<void> _handlePhotoSubmit(
      OrderProvider orderProv, bool isArabic) async {
    if (_capturedPhoto == null) {
      setState(() {
        _errorMessage = isArabic
            ? 'يرجى التقاط صورة لتوثيق تسليم الطلب أولاً'
            : 'Please capture a photo first to document delivery';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final photoUrl = await orderProv.uploadPoDPhoto(_capturedPhoto!);
      if (photoUrl == null || photoUrl.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          _errorMessage = isArabic
              ? 'فشل رفع صورة التسليم، يرجى المحاولة ثانية'
              : 'Failed to upload photo, please try again';
        });
        return;
      }

      final notesText = _notesController.text.trim();
      final finalNotes = notesText.isNotEmpty
          ? notesText
          : (isArabic
              ? 'توثيق التسليم عبر الصورة (PoD)'
              : 'Proof of delivery via photo');

      final success = await orderProv.deliverOrder(
        widget.order.id!,
        photoUrl: photoUrl,
        notes: finalNotes,
      );

      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'تم توثيق وتسليم الطلب #${widget.order.id} بالصورة بنجاح ✓'
                  : 'Order #${widget.order.id} delivered with photo PoD ✓',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
            ),
            backgroundColor: kGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('Error: ', '')
            .trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProv = Provider.of<OrderProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kGreenLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const AppIcon(PhosphorIcons.shieldCheckBold,
                color: kGreen, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'تأكيد تسليم الطلب' : 'Confirm Delivery',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '#${widget.order.id}',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kPrimaryOrange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode Switcher Tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _isSubmitting
                          ? null
                          : () => setState(() => _isPhotoMode = false),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: !_isPhotoMode
                              ? (isDark
                                  ? const Color(0xFF334155)
                                  : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: !_isPhotoMode
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppIcon(
                                PhosphorIcons.keyBold,
                                size: 14,
                                color: !_isPhotoMode
                                    ? kPrimaryOrange
                                    : kCharcoalMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isArabic ? 'رمز التحقق (OTP)' : 'Customer OTP',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: !_isPhotoMode
                                      ? (isDark ? Colors.white : kCharcoalDark)
                                      : kCharcoalMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: _isSubmitting
                          ? null
                          : () => setState(() => _isPhotoMode = true),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _isPhotoMode
                              ? (isDark
                                  ? const Color(0xFF334155)
                                  : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _isPhotoMode
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppIcon(
                                PhosphorIcons.cameraBold,
                                size: 14,
                                color: _isPhotoMode
                                    ? kPrimaryOrange
                                    : kCharcoalMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isArabic ? 'صورة التسليم' : 'Photo PoD',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _isPhotoMode
                                      ? (isDark ? Colors.white : kCharcoalDark)
                                      : kCharcoalMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: kRedLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: kRed, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: kRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (!_isPhotoMode) ...[
              // OTP Mode
              Text(
                isArabic
                    ? 'اطلب رمز تأكيد الاستلام من العميل (4 أرقام):'
                    : 'Ask the customer for the 4-digit confirmation code:',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12.5,
                  color: kCharcoalMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  maxLength: 8,
                  textAlign: TextAlign.center,
                  enabled: !_isSubmitting,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9٠-٩۰-۹\s\-]')),
                  ],
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    hintText: '----',
                    hintStyle: const TextStyle(
                        letterSpacing: 8, color: Color(0xFFCBD5E1)),
                    counterText: '',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : kSurfaceWarm,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.paste_rounded,
                          color: kPrimaryOrange, size: 20),
                      tooltip: isArabic ? 'لصق الرمز' : 'Paste Code',
                      onPressed: _isSubmitting
                          ? null
                          : () async {
                              final data =
                                  await Clipboard.getData(Clipboard.kTextPlain);
                              if (data != null && data.text != null) {
                                final clean =
                                    PhoneHelper.cleanDigits(data.text);
                                if (clean.isNotEmpty) {
                                  setState(() => _otpController.text = clean);
                                }
                              }
                            },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: kPrimaryOrange, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: kPrimaryOrange, width: 2),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Photo Mode
              Text(
                isArabic
                    ? 'في حال تعذر استلام رمز OTP، التقط صورة واضحة للطلب عند باب العميل:'
                    : 'Capture a clear photo of the delivered package at the door:',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12.5,
                  color: kCharcoalMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              if (_capturedPhoto == null) ...[
                InkWell(
                  onTap: _isSubmitting
                      ? null
                      : () async {
                          try {
                            final photo = await _picker.pickImage(
                              source: ImageSource.camera,
                              imageQuality: 75,
                              maxWidth: 1280,
                              maxHeight: 1280,
                            );
                            if (photo != null) {
                              setState(() {
                                _capturedPhoto = photo;
                                _errorMessage = null;
                              });
                            }
                          } catch (e) {
                            setState(() => _errorMessage = e.toString());
                          }
                        },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : kSurfaceWarm,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kPrimaryOrange, width: 1.2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AppIcon(PhosphorIcons.cameraBold,
                            size: 32, color: kPrimaryOrange),
                        const SizedBox(height: 6),
                        Text(
                          isArabic
                              ? 'اضغط لفتح الكاميرا والتقاط صورة'
                              : 'Tap to open camera & take photo',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: kPrimaryOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        File(_capturedPhoto!.path),
                        height: 130,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.black.withValues(alpha: 0.6),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.refresh_rounded,
                              color: Colors.white, size: 18),
                          onPressed: _isSubmitting
                              ? null
                              : () async {
                                  final photo = await _picker.pickImage(
                                    source: ImageSource.camera,
                                    imageQuality: 75,
                                  );
                                  if (photo != null) {
                                    setState(() => _capturedPhoto = photo);
                                  }
                                },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                enabled: !_isSubmitting,
                decoration: InputDecoration(
                  hintText: isArabic
                      ? 'ملاحظات إضافية (اختياري: مثال: تم الاستلام باليد)'
                      : 'Additional notes (optional)',
                  hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : kPageBackground,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: Text(
            isArabic ? 'إلغاء' : 'Cancel',
            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w600),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kGreen,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          onPressed: _isSubmitting
              ? null
              : () => _isPhotoMode
                  ? _handlePhotoSubmit(orderProv, isArabic)
                  : _handleOtpSubmit(orderProv, isArabic),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  isArabic ? 'تأكيد التسليم' : 'Confirm Delivery',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 2. Merchant Order Details Card (Pickup Stop)
// -----------------------------------------------------------------------------
class MerchentOrderDetailsCard extends StatelessWidget {
  final MerchentOrderDetailsModel item;
  final int orderId;
  final bool showPickupAction;

  const MerchentOrderDetailsCard({
    required this.item,
    required this.orderId,
    this.showPickupAction = true,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final orderProv = Provider.of<OrderProvider>(context);
    final isActionInFlight = orderProv.isActionInFlight(orderId);
    final isPickedUp = item.orderDetailStatus == OrderDetailsStatus.shipping ||
        item.orderDetailStatus == OrderDetailsStatus.delivered;
    final isReadyForPickup =
        item.orderDetailStatus == OrderDetailsStatus.readyForPickup;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDarkStore = item.isDarkStore;

    final navUrl = GlobalVar.getMerchantNavigationUrl(
      lat: item.lat,
      lng: item.lng,
      address: item.merchantAddress,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDarkStore
              ? const Color(0xFF6366F1).withValues(alpha: 0.6)
              : (isDark ? const Color(0xFF334155) : kCardBorderColor),
          width: isDarkStore ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Store Header Row
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GlobalVar.checkString(
                        GlobalVar.getMerchantLogo(item.merchantLogo))
                    ? ImageView(
                        GlobalVar.getMerchantLogo(item.merchantLogo),
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDarkStore
                              ? const Color(0xFFEEF2FF)
                              : kSurfaceWarm,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: AppIcon(
                            isDarkStore
                                ? PhosphorIcons.packageBold
                                : PhosphorIcons.storefrontBold,
                            size: 22,
                            color: isDarkStore
                                ? const Color(0xFF6366F1)
                                : kPrimaryOrange,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            GlobalVar.checkString(item.merchantTitle)
                                ? item.merchantTitle!
                                : (isArabic
                                    ? 'متجر #${item.merchantId ?? ""}'
                                    : 'Store #${item.merchantId ?? ""}'),
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : kCharcoalDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (isDarkStore)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          isArabic
                              ? '🏢 مستودع جيتك المركزي'
                              : '🏢 Jitak Dark Store',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                      ),
                    if (GlobalVar.checkString(item.merchantAddress))
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: [
                            const AppIcon(PhosphorIcons.mapPinBold,
                                size: 12, color: kCharcoalMuted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item.merchantAddress!,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : kCharcoalMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildMerchantStatusPill(
                  item.orderDetailStatus, isDark, isArabic),
            ],
          ),

          const SizedBox(height: 12),

          // Action Buttons (Call, WhatsApp, Maps)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (PhoneHelper.isValidPhone(item.merchantPhone)) ...[
                OutlinedButton.icon(
                  onPressed: () =>
                      PhoneHelper.launchCall(context, item.merchantPhone),
                  icon: const AppIcon(PhosphorIcons.phoneCallBold,
                      size: 14, color: kGreen),
                  label: Text(
                    isArabic ? 'اتصال بالمتجر' : 'Call Store',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kGreen,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: kGreen.withValues(alpha: 0.4)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      PhoneHelper.launchWhatsApp(context, item.merchantPhone),
                  icon: const AppIcon(PhosphorIcons.whatsappLogoBold,
                      size: 14, color: Color(0xFF25D366)),
                  label: Text(
                    'واتساب',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF25D366),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: const Color(0xFF25D366).withValues(alpha: 0.4)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
              if (navUrl != null)
                OutlinedButton.icon(
                  onPressed: () => GlobalVar.launchNavigationUrl(navUrl),
                  icon: const AppIcon(PhosphorIcons.navigationArrowBold,
                      size: 14, color: kBlue),
                  label: Text(
                    isArabic ? 'خريطة المتجر' : 'Store Map',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kBlue,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: kBlue.withValues(alpha: 0.4)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
            ],
          ),

          // In-card Pickup Button (If Ready for Pickup)
          if (showPickupAction && isReadyForPickup && !isPickedUp) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 42,
              child: ElevatedButton.icon(
                onPressed: isActionInFlight
                    ? null
                    : () async {
                        try {
                          await orderProv.startShipping(
                              orderId, item.merchantId!);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isArabic
                                      ? 'تم تأكيد استلام الطلب من المتجر بنجاح ✓'
                                      : 'Pickup confirmed successfully ✓',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                      fontWeight: FontWeight.w700),
                                ),
                                backgroundColor: kGreen,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e
                                      .toString()
                                      .replaceAll('Exception: ', '')
                                      .trim(),
                                  style: GoogleFonts.ibmPlexSansArabic(),
                                ),
                                backgroundColor: kRed,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                icon: isActionInFlight
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const AppIcon(PhosphorIcons.checkCircleBold,
                        size: 16, color: Colors.white),
                label: Text(
                  isActionInFlight
                      ? (isArabic ? 'جاري التأكيد...' : 'Confirming...')
                      : (isArabic
                          ? 'تأكيد استلام الطلب من هذا المتجر'
                          : 'Confirm Pickup from Store'),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isDarkStore ? const Color(0xFF6366F1) : kPrimaryOrange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, color: kBorderColor),
          const SizedBox(height: 10),

          // Items List inside this merchant
          if (item.orderDetails != null && item.orderDetails!.isNotEmpty)
            Column(
              children: item.orderDetails!
                  .map((product) => OrderDetailsSingleItem(product))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildMerchantStatusPill(
      OrderDetailsStatus? status, bool isDark, bool isArabic) {
    Color bg;
    Color fg;
    String text;

    switch (status) {
      case OrderDetailsStatus.delivered:
      case OrderDetailsStatus.shipping:
        bg = isDark ? const Color(0xFF064E3B) : kGreenLight;
        fg = isDark ? const Color(0xFF34D399) : kGreen;
        text = isArabic ? 'تم الاستلام ✓' : 'Picked Up ✓';
        break;
      case OrderDetailsStatus.readyForPickup:
        bg = isDark ? const Color(0xFF1E3A8A) : kBlueLight;
        fg = isDark ? const Color(0xFF60A5FA) : kBlue;
        text = isArabic ? 'جاهز للاستلام' : 'Ready for Pickup';
        break;
      case OrderDetailsStatus.merchantAccepted:
        bg = isDark ? const Color(0xFF78350F) : kAmberLight;
        fg = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
        text = isArabic ? 'قيد التجهيز' : 'Preparing';
        break;
      default:
        bg = isDark ? const Color(0xFF334155) : kGreyBackground;
        fg = isDark ? Colors.white : kCharcoalDark;
        text = status?.value ?? '';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 3. Customer Order Details Card (Dropoff Destination)
// -----------------------------------------------------------------------------
class CustomerOrderDetailsCard extends StatelessWidget {
  final OrderModel order;

  const CustomerOrderDetailsCard({required this.order, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final navUrl = GlobalVar.getCustomerNavigationUrl(
      lat: order.lat,
      lng: order.lng,
      address: order.address,
    );

    final customerName = GlobalVar.checkString(order.user)
        ? order.user!
        : (isArabic ? 'العميل' : 'Customer');

    final customerPhone = order.phonenumber;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : kCardBorderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child:
                      AppIcon(PhosphorIcons.userBold, size: 20, color: kGreen),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : kCharcoalDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.address ??
                          (isArabic
                              ? 'العنوان غير محدد'
                              : 'Address not specified'),
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12.5,
                        color:
                            isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (GlobalVar.checkString(order.description)) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : kSurfaceWarm,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppIcon(PhosphorIcons.notepadBold,
                      size: 14, color: kPrimaryOrange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.description!,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12,
                        color: kCharcoalDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Quick Contact & Navigation Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (PhoneHelper.isValidPhone(customerPhone)) ...[
                OutlinedButton.icon(
                  onPressed: () =>
                      PhoneHelper.launchCall(context, customerPhone),
                  icon: const AppIcon(PhosphorIcons.phoneCallBold,
                      size: 14, color: kGreen),
                  label: Text(
                    isArabic ? 'اتصال بالعميل' : 'Call Customer',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kGreen,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: kGreen.withValues(alpha: 0.4)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      PhoneHelper.launchWhatsApp(context, customerPhone),
                  icon: const AppIcon(PhosphorIcons.whatsappLogoBold,
                      size: 14, color: Color(0xFF25D366)),
                  label: Text(
                    'واتساب',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF25D366),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: const Color(0xFF25D366).withValues(alpha: 0.4)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => QuickChatSheet.show(
                    context,
                    customerPhone: customerPhone!,
                    customerName: customerName,
                  ),
                  icon: const AppIcon(PhosphorIcons.chatTeardropDotsBold,
                      size: 14, color: kPrimaryOrange),
                  label: Text(
                    isArabic ? 'رسائل سريعة' : 'Quick Chat',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kPrimaryOrange,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: kPrimaryOrange.withValues(alpha: 0.4)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
              if (navUrl != null)
                OutlinedButton.icon(
                  onPressed: () => GlobalVar.launchNavigationUrl(navUrl),
                  icon: const AppIcon(PhosphorIcons.navigationArrowBold,
                      size: 14, color: kPrimaryOrange),
                  label: Text(
                    isArabic ? 'خريطة العميل' : 'Customer Map',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kPrimaryOrange,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: kPrimaryOrange.withValues(alpha: 0.4)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 4. Product Item Component
// -----------------------------------------------------------------------------
class OrderDetailsSingleItem extends StatelessWidget {
  final OrderDetailsModel item;
  const OrderDetailsSingleItem(this.item, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _image(isDark),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  GlobalVar.checkString(item.productTitle)
                      ? item.productTitle!
                      : 'صنف #${item.productId ?? ""}',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : kCharcoalDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (GlobalVar.checkString(item.productUnit))
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      item.productUnit!,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11,
                        color:
                            isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: isDark ? const Color(0xFF334155) : kBorderColor,
                  width: 1),
            ),
            child: Text(
              '${item.quantity ?? 1} ×',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kPrimaryOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _image(bool isDark) {
    const double size = 40;
    final img = GlobalVar.getFirstPhoto(item.productImage);
    if (GlobalVar.checkString(img)) {
      return ImageView(img, height: size, width: size, fit: BoxFit.cover);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: AppIcon(
          PhosphorIcons.forkKnifeBold,
          size: 18,
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 5. Active Order Card for OrdersPage List
// -----------------------------------------------------------------------------
class DeliveryOrderCard extends StatelessWidget {
  final OrderModel order;
  final double? distanceKm;

  const DeliveryOrderCard({
    required this.order,
    this.distanceKm,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final status = order.deliveryStatus;
    final isShipping = order.canDeliverToCustomer;
    final isReadyForPickup = status == OrderDetailsStatus.readyForPickup;

    final merchantTitle = order.primaryMerchantTitle;
    final customerAddress = order.address ??
        (isArabic ? 'العنوان غير محدد' : 'Address not specified');
    final timeFormatted =
        GlobalVar.dateForamt(order.purchaseDate, 'HH:mm') ?? '--:--';
    final priceFormatted = GlobalVar.priceForamt(order.price);

    final distanceFormatted = distanceKm != null
        ? '${distanceKm!.toStringAsFixed(1)} ${isArabic ? 'كم' : 'km'}'
        : null;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrderDetailsPage(order)),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isShipping
                ? kPrimaryOrange.withValues(alpha: 0.4)
                : (isReadyForPickup
                    ? kBlue.withValues(alpha: 0.3)
                    : kCardBorderColor),
            width: isShipping ? 1.4 : 1.0,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header: Order ID + Status Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: kSurfaceWarm,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${order.id}',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: kPrimaryOrange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Payment Pill (COD vs Electronic)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: order.isCod
                            ? const Color(0xFFFFFBEB)
                            : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: order.isCod
                              ? const Color(0xFFFDE68A)
                              : const Color(0xFFA7F3D0),
                        ),
                      ),
                      child: Text(
                        order.isCod
                            ? (isArabic
                                ? 'تحصيل نقدي (COD)'
                                : 'Cash on Delivery')
                            : (isArabic ? 'مدفوع إلكترونياً' : 'Prepaid'),
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: order.isCod
                              ? const Color(0xFFB45309)
                              : const Color(0xFF047857),
                        ),
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(status, isDark, isArabic),
              ],
            ),

            const SizedBox(height: 12),

            // Middle: Pickup Store & Customer Destination
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon column
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDarkStore(order)
                            ? const Color(0xFFEEF2FF)
                            : kSurfaceWarm,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: HomeMirroredIcon(
                          isDarkStore(order)
                              ? PhosphorIcons.packageBold
                              : PhosphorIcons.storefrontBold,
                          size: 16,
                          color: isDarkStore(order)
                              ? const Color(0xFF6366F1)
                              : kPrimaryOrange,
                        ),
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 24,
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: HomeMirroredIcon(PhosphorIcons.mapPinBold,
                            size: 16, color: kGreen),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pickup from Store
                      Text(
                        isArabic ? 'الاستلام:' : 'Pickup:',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: kCharcoalMuted,
                        ),
                      ),
                      Text(
                        merchantTitle,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : kCharcoalDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      // Dropoff to Customer
                      Text(
                        isArabic ? 'التسليم:' : 'Dropoff:',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: kCharcoalMuted,
                        ),
                      ),
                      Text(
                        customerAddress,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : kCharcoalDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: kBorderColor),
            const SizedBox(height: 10),

            // Info Bar: Time, Distance, Cash to Collect
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const HomeMirroredIcon(PhosphorIcons.clockBold,
                        size: 14, color: kCharcoalMuted),
                    const SizedBox(width: 4),
                    Text(
                      timeFormatted,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kCharcoalDark,
                      ),
                    ),
                    if (distanceFormatted != null) ...[
                      const SizedBox(width: 12),
                      const HomeMirroredIcon(PhosphorIcons.mapPinBold,
                          size: 14, color: kCharcoalMuted),
                      const SizedBox(width: 4),
                      Text(
                        distanceFormatted,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kCharcoalDark,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  order.isCod
                      ? '$priceFormatted ${isArabic ? 'ل.س نقداً' : 'SYP cash'}'
                      : (isArabic ? 'مدفوع إلكترونياً' : 'Prepaid'),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: order.isCod ? kPrimaryOrange : kGreen,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Primary Workflow Action Button
            SizedBox(
              height: 42,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => OrderDetailsPage(order)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isShipping
                      ? kGreen
                      : (isReadyForPickup
                          ? kPrimaryOrange
                          : const Color(0xFFFFF0E8)),
                  foregroundColor: (isShipping || isReadyForPickup)
                      ? Colors.white
                      : kPrimaryOrange,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HomeMirroredIcon(
                      isShipping
                          ? PhosphorIcons.shieldCheckBold
                          : (isReadyForPickup
                              ? PhosphorIcons.storefrontBold
                              : PhosphorIcons.arrowRightBold),
                      size: 16,
                      color: (isShipping || isReadyForPickup)
                          ? Colors.white
                          : kPrimaryOrange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _primaryButtonLabel(order, isArabic),
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: (isShipping || isReadyForPickup)
                            ? Colors.white
                            : kPrimaryOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool isDarkStore(OrderModel o) {
    if (o.orderDetails != null && o.orderDetails!.isNotEmpty) {
      return o.orderDetails!.first.isDarkStore;
    }
    return false;
  }

  String _primaryButtonLabel(OrderModel o, bool isArabic) {
    if (o.isDelivered) {
      return isArabic ? 'عرض تفاصيل الطلب (مكتمل)' : 'View Details (Delivered)';
    }
    if (o.canDeliverToCustomer) {
      return isArabic
          ? 'تأكيد تسليم الطلب للعميل'
          : 'Confirm Delivery to Customer';
    }
    if (o.hasPendingPickups) {
      final next = o.nextPendingMerchant;
      if (next != null && GlobalVar.checkString(next.merchantTitle)) {
        return isArabic
            ? 'استلام الطلب من ${next.merchantTitle}'
            : 'Pickup from Store';
      }
      return isArabic ? 'استلام الطلب من المتجر' : 'Pickup from Store';
    }
    return isArabic ? 'عرض تفاصيل الطلب' : 'View Order Details';
  }

  Widget _buildStatusBadge(
      OrderDetailsStatus status, bool isDark, bool isArabic) {
    Color bg;
    Color fg;
    String text;
    IconData icon;

    switch (status) {
      case OrderDetailsStatus.delivered:
        bg = isDark ? const Color(0xFF064E3B) : kGreenLight;
        fg = isDark ? const Color(0xFF34D399) : kGreen;
        text = isArabic ? 'تم التسليم بنجاح ✓' : 'Delivered ✓';
        icon = PhosphorIcons.checkCircleBold;
        break;
      case OrderDetailsStatus.shipping:
        bg = isDark ? const Color(0xFF334155) : kSurfaceWarm;
        fg = kPrimaryOrange;
        text = isArabic ? 'قيد التوصيل للعميل' : 'Out for Delivery';
        icon = PhosphorIcons.mopedBold;
        break;
      case OrderDetailsStatus.readyForPickup:
        bg = isDark ? const Color(0xFF1E3A8A) : kBlueLight;
        fg = isDark ? const Color(0xFF60A5FA) : kBlue;
        text = isArabic ? 'جاهز للاستلام' : 'Ready for Pickup';
        icon = PhosphorIcons.storefrontBold;
        break;
      case OrderDetailsStatus.merchantAccepted:
        bg = isDark ? const Color(0xFF78350F) : kAmberLight;
        fg = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
        text = isArabic ? 'قيد التجهيز' : 'Preparing';
        icon = PhosphorIcons.clockBold;
        break;
      case OrderDetailsStatus.deliveryCanceled:
      case OrderDetailsStatus.customerCanceled:
      case OrderDetailsStatus.merchantRejected:
        bg = isDark ? const Color(0xFF450A0A) : kRedLight;
        fg = isDark ? const Color(0xFFF87171) : kRed;
        text = isArabic ? 'ملغي' : 'Canceled';
        icon = PhosphorIcons.xCircleBold;
        break;
      default:
        bg = isDark ? const Color(0xFF334155) : kGreyBackground;
        fg = isDark ? Colors.white : kCharcoalDark;
        text = status.value;
        icon = PhosphorIcons.infoBold;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HomeMirroredIcon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
