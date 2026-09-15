import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/constants/constants.dart';
import '../../../config/themes/colors.dart';
import '../../../core/controllers/order_provider.dart';
import '../../../core/enums/order_details_status_enum.dart';
import '../../../core/models/merchant_order_details.dart';
import '../../../core/models/order_details_model.dart';
import '../../../core/models/order_model.dart';
import '../../../ui/widgets/app_widgets.dart';
import '../../../ui/widgets/price_widgets.dart';
import '../../../utils/custom_widgets/image_widgets.dart';
import '../../../utils/custom_widgets/messages.dart';
import '../../../utils/utilities/global_var.dart';

class OrderSingleItem extends StatelessWidget {
  final OrderModel item;
  const OrderSingleItem(this.item, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final status = orderProvider.getOrderStatus(item);
    final isDelivered = status == OrderDetailsStatus.delivered;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDelivered
              ? (isDark ? const Color(0xFF334155) : kBorderColor)
              : (isDark ? const Color(0xFF475569) : kPrimaryOrange.withValues(alpha: 0.25)),
          width: isDelivered ? 1 : 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Order Header (ID + Date + Price + Status Pill)
          _buildHeader(context, status, isDark, isArabic),

          Divider(height: 1, color: isDark ? const Color(0xFF334155) : kBorderColor),

          // 2. Merchant Store & Pickup Details
          if (item.orderDetails != null && item.orderDetails!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: item.orderDetails!
                    .map((merchant) => MerchentOrderDetails(merchant, item.id!))
                    .toList(),
              ),
            ),

          Divider(height: 1, color: isDark ? const Color(0xFF334155) : kBorderColor),

          // 3. Customer Destination & Action Section
          _buildCustomerSection(context, status, isDark, isArabic),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, OrderDetailsStatus status, bool isDark, bool isArabic) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Order Number Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : kSurfaceWarm,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppIcon(PhosphorIcons.hashBold, size: 14, color: kPrimaryOrange),
                    const SizedBox(width: 2),
                    Text(
                      '${item.id}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kPrimaryOrange,
                      ),
                    ),
                  ],
                ),
              ),

              // Status Pill
              _buildStatusPill(status, isDark, isArabic),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Timestamp
              Row(
                children: [
                  AppIcon(PhosphorIcons.clockBold, size: 14, color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted),
                  const SizedBox(width: 4),
                  Text(
                    GlobalVar.dateForamt(item.purchaseDate, kDateTimeFormat) ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              // Price
              PriceTextWidget.small(
                price: item.price,
                currencyString: isArabic ? 'ل.س' : 'SYP',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(OrderDetailsStatus status, bool isDark, bool isArabic) {
    Color bg;
    Color fg;
    String text;
    IconData icon;

    switch (status) {
      case OrderDetailsStatus.delivered:
        bg = isDark ? const Color(0xFF064E3B) : kGreenLight;
        fg = isDark ? const Color(0xFF34D399) : kGreen;
        text = isArabic ? 'تم التسليم بنجاح' : 'Delivered';
        icon = PhosphorIcons.checkCircleBold;
        break;
      case OrderDetailsStatus.shipping:
        bg = isDark ? const Color(0xFF334155) : kSurfaceWarm;
        fg = kPrimaryOrange;
        text = isArabic ? 'قيد التوصيل للعميل' : 'Out for Delivery';
        icon = PhosphorIcons.mopedBold;
        break;
      case OrderDetailsStatus.merchantAccepted:
      case OrderDetailsStatus.readyForPickup:
        bg = isDark ? const Color(0xFF1E3A8A) : kBlueLight;
        fg = isDark ? const Color(0xFF60A5FA) : kBlue;
        text = isArabic ? 'جاهز للاستلام من المتجر' : 'Ready for Pickup';
        icon = PhosphorIcons.storefrontBold;
        break;
      default:
        bg = isDark ? const Color(0xFF334155) : kGreyBackground;
        fg = isDark ? Colors.white : kCharcoalDark;
        text = status.value;
        icon = PhosphorIcons.infoBold;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSection(BuildContext context, OrderDetailsStatus status, bool isDark, bool isArabic) {
    final isDelivered = status == OrderDetailsStatus.delivered;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer Details Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : kGreyBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const AppIcon(PhosphorIcons.mapPinBold, size: 18, color: kPrimaryOrange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.user ?? (isArabic ? 'العميل' : 'Customer'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : kCharcoalDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.address ?? (isArabic ? 'لا يوجد عنوان محدد' : 'No specified address'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isDelivered && GlobalVar.checkString(item.phonenumber))
                InkWell(
                  onTap: () => launchUrl(Uri.parse('tel:${item.phonenumber}')),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF064E3B) : kGreenLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF047857) : kGreen.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: AppIcon(
                      PhosphorIcons.phoneCallBold,
                      size: 18,
                      color: isDark ? const Color(0xFF34D399) : kGreen,
                    ),
                  ),
                ),
            ],
          ),

          if (!isDelivered) ...[
            const SizedBox(height: 14),
            Builder(
              builder: (ctx) {
                final navUrl = GlobalVar.getCustomerNavigationUrl(
                  lat: item.lat,
                  lng: item.lng,
                  address: item.address,
                );

                return Row(
                  children: [
                    // 1. Open Google Maps Navigation Button
                    if (navUrl != null)
                      Expanded(
                        flex: 4,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            try {
                              launchUrl(Uri.parse(navUrl), mode: LaunchMode.externalApplication);
                            } catch (err) {
                              showDialog(context: context, builder: (ctx) => CustomDialog(message: err.toString()));
                            }
                          },
                          icon: const AppIcon(PhosphorIcons.navigationArrowBold, size: 16),
                          label: Text(isArabic ? 'تتبع الخريطة' : 'Navigation'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kPrimaryOrange,
                            side: const BorderSide(color: kPrimaryOrange, width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),

                    if (navUrl != null) const SizedBox(width: 10),

                    // 2. Deliver to Customer Action Button
                    Expanded(
                      flex: navUrl != null ? 6 : 10,
                      child: ElevatedButton.icon(
                        onPressed: status == OrderDetailsStatus.shipping
                            ? () => _confirmDelivery(context, isArabic)
                            : null,
                        icon: const AppIcon(PhosphorIcons.checkCircleBold, size: 18),
                        label: Text(isArabic ? 'تأكيد التسليم' : 'Confirm Delivery'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGreen,
                          disabledBackgroundColor: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  static String _cleanOtp(String raw) {
    String text = raw.replaceAll(RegExp(r'[\s\-_]'), '');
    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    const easternArabic = '۰۱۲۳۴۵۶۷۸۹';
    for (int i = 0; i < 10; i++) {
      text = text.replaceAll(arabicIndic[i], i.toString());
      text = text.replaceAll(easternArabic[i], i.toString());
    }
    return text.replaceAll(RegExp(r'[^0-9]'), '');
  }

  void _confirmDelivery(BuildContext context, bool isArabic) {
    final TextEditingController otpController = TextEditingController();
    final TextEditingController notesController = TextEditingController();
    final ImagePicker picker = ImagePicker();

    bool isPhotoMode = false;
    XFile? capturedPhoto;
    bool isSubmitting = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: Row(
              children: [
                const AppIcon(PhosphorIcons.shieldCheckBold, color: kGreen, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabic ? 'توثيق التسليم (PoD)' : 'Proof of Delivery (PoD)',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Verification Mode Switcher
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : kPageBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : kBorderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: isSubmitting ? null : () => setModalState(() => isPhotoMode = false),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: !isPhotoMode ? (isDark ? const Color(0xFF334155) : Colors.white) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: !isPhotoMode
                                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                                    : null,
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AppIcon(PhosphorIcons.keyBold, size: 14, color: !isPhotoMode ? kPrimaryOrange : kCharcoalMuted),
                                    const SizedBox(width: 6),
                                    Text(
                                      isArabic ? 'رمز العميل (OTP)' : 'Customer OTP',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: !isPhotoMode ? (isDark ? Colors.white : kCharcoalDark) : kCharcoalMuted,
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
                            onTap: isSubmitting ? null : () => setModalState(() => isPhotoMode = true),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isPhotoMode ? (isDark ? const Color(0xFF334155) : Colors.white) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: isPhotoMode
                                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                                    : null,
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AppIcon(PhosphorIcons.cameraBold, size: 14, color: isPhotoMode ? kPrimaryOrange : kCharcoalMuted),
                                    const SizedBox(width: 6),
                                    Text(
                                      isArabic ? 'صورة التسليم' : 'Photo PoD',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isPhotoMode ? (isDark ? Colors.white : kCharcoalDark) : kCharcoalMuted,
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

                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: kRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: kRed, fontSize: 12, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],

                  if (!isPhotoMode) ...[
                    // 1. Customer OTP Mode
                    Text(
                      isArabic
                          ? 'لتأكيد تسليم الطلب #${item.id}، يرجى إدخال رمز التحقق المستلم من العميل (4 أرقام):'
                          : 'To confirm delivery for order #${item.id}, enter the 4-digit PIN received from customer:',
                      style: const TextStyle(fontSize: 12.5, color: kCharcoalMuted),
                    ),
                    const SizedBox(height: 14),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: TextField(
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        maxLength: 10,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹\s\-]')),
                        ],
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 8,
                        ),
                        decoration: InputDecoration(
                          hintText: '----',
                          hintStyle: const TextStyle(letterSpacing: 8, color: Color(0xFFCBD5E1)),
                          counterText: '',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : kSurfaceWarm,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.paste_rounded, color: kPrimaryOrange, size: 20),
                            tooltip: isArabic ? 'لصق الرمز' : 'Paste PIN',
                            onPressed: () async {
                              final data = await Clipboard.getData(Clipboard.kTextPlain);
                              if (data != null && data.text != null) {
                                String clean = _cleanOtp(data.text!);
                                if (clean.isNotEmpty) {
                                  otpController.text = clean;
                                  setModalState(() {});
                                }
                              }
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: kPrimaryOrange, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: kPrimaryOrange, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // 2. Photo PoD Mode
                    Text(
                      isArabic
                          ? 'في حال تعذر استلام رمز OTP أو التسليم غير التلامسي، التقط صورة للطلب عند الباب:'
                          : 'For contactless or absent customer delivery, capture a photo of the package at doorstep:',
                      style: const TextStyle(fontSize: 12.5, color: kCharcoalMuted),
                    ),
                    const SizedBox(height: 12),

                    if (capturedPhoto == null) ...[
                      InkWell(
                        onTap: isSubmitting
                            ? null
                            : () async {
                                try {
                                  final photo = await picker.pickImage(
                                    source: ImageSource.camera,
                                    imageQuality: 75,
                                    maxWidth: 1280,
                                    maxHeight: 1280,
                                  );
                                  if (photo != null) {
                                    setModalState(() {
                                      capturedPhoto = photo;
                                      errorMessage = null;
                                    });
                                  }
                                } catch (e) {
                                  setModalState(() => errorMessage = e.toString());
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
                              const AppIcon(PhosphorIcons.cameraBold, size: 32, color: kPrimaryOrange),
                              const SizedBox(height: 6),
                              Text(
                                isArabic ? 'اضغط لفتح الكاميرا والتقاط صورة' : 'Tap to open camera & take photo',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kPrimaryOrange),
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
                              File(capturedPhoto!.path),
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
                                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        final photo = await picker.pickImage(
                                          source: ImageSource.camera,
                                          imageQuality: 75,
                                        );
                                        if (photo != null) {
                                          setModalState(() => capturedPhoto = photo);
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
                      controller: notesController,
                      decoration: InputDecoration(
                        hintText: isArabic
                            ? 'ملاحظات التسليم (مثال: تم ترك الطلب عند الباب بطلب العميل)'
                            : 'Delivery notes (e.g. Left at door as requested)',
                        hintStyle: const TextStyle(fontSize: 12),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : kPageBackground,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                child: Text(
                  isArabic ? 'إلغاء' : 'Cancel',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final orderProv = Provider.of<OrderProvider>(context, listen: false);

                        if (!isPhotoMode) {
                          // OTP Mode
                          final otp = _cleanOtp(otpController.text);
                          if (otp.length < 4) {
                            setModalState(() {
                              errorMessage = isArabic
                                  ? 'يرجى إدخال رمز التحقق (4 أرقام)'
                                  : 'Please enter the 4-digit verification PIN';
                            });
                            return;
                          }

                          setModalState(() {
                            isSubmitting = true;
                            errorMessage = null;
                          });

                          try {
                            await orderProv.deliverOrder(item.id!, otp: otp);
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(isArabic ? 'تم تأكيد تسليم الطلب بنجاح ✓' : 'Order delivered successfully ✓')),
                              );
                            }
                          } catch (err) {
                            setModalState(() {
                              isSubmitting = false;
                              errorMessage = err.toString().replaceAll('Exception: ', '').replaceAll('Error: ', '').trim();
                            });
                          }
                        } else {
                          // Photo PoD Mode
                          if (capturedPhoto == null) {
                            setModalState(() {
                              errorMessage = isArabic
                                  ? 'يرجى التقاط صورة للطلب أولاً لتوثيق التسليم'
                                  : 'Please capture a photo first to document delivery';
                            });
                            return;
                          }

                          setModalState(() {
                            isSubmitting = true;
                            errorMessage = null;
                          });

                          try {
                            final uploadedUrl = await orderProv.uploadPoDPhoto(capturedPhoto!);
                            if (uploadedUrl == null || uploadedUrl.isEmpty) {
                              setModalState(() {
                                isSubmitting = false;
                                errorMessage = isArabic
                                    ? 'فشل رفع صورة التسليم، يرجى المحاولة ثانية'
                                    : 'Failed to upload photo, please try again';
                              });
                              return;
                            }

                            await orderProv.deliverOrder(
                              item.id!,
                              notes: notesController.text.trim().isNotEmpty
                                  ? notesController.text.trim()
                                  : (isArabic ? 'توثيق التسليم عبر الصورة (PoD)' : 'Proof of delivery via photo'),
                              photoUrl: uploadedUrl,
                            );
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(isArabic ? 'تم توثيق وتسليم الطلب بالصورة بنجاح ✓' : 'Order delivered with photo PoD ✓')),
                              );
                            }
                          } catch (err) {
                            setModalState(() {
                              isSubmitting = false;
                              errorMessage = err.toString().replaceAll('Exception: ', '').replaceAll('Error: ', '').trim();
                            });
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        isArabic ? 'تأكيد وإتمام التسليم' : 'Verify & Deliver',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class MerchentOrderDetails extends StatelessWidget {
  final MerchentOrderDetailsModel item;
  final int orderId;
  const MerchentOrderDetails(this.item, this.orderId, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isAccepted = item.orderDetailStatus == OrderDetailsStatus.readyForPickup;
    final isPickedUp = item.orderDetailStatus == OrderDetailsStatus.shipping ||
        item.orderDetailStatus == OrderDetailsStatus.delivered;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDarkStore = item.isDarkStore;
    final hasCoords = item.lat != null && item.lng != null && item.lat != 0 && item.lng != 0;
    final mapNavUrl = hasCoords ? 'https://www.google.com/maps/dir/?api=1&destination=${item.lat},${item.lng}' : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkStore
              ? (isDark ? const Color(0xFF6366F1) : const Color(0xFF818CF8).withValues(alpha: 0.6))
              : (isDark ? const Color(0xFF334155) : kBorderColor),
          width: isDarkStore ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store Identity Header (Logo, Name, Address, Status Badge)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Restaurant Logo or Store Icon
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: GlobalVar.checkString(GlobalVar.getMerchantLogo(item.merchantLogo))
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
                              ? (isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF))
                              : (isDark ? const Color(0xFF334155) : kSurfaceWarm),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: AppIcon(
                            isDarkStore ? PhosphorIcons.packageBold : PhosphorIcons.storefrontBold,
                            size: 22,
                            color: isDarkStore ? const Color(0xFF6366F1) : kPrimaryOrange,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      GlobalVar.checkString(item.merchantTitle)
                          ? item.merchantTitle!
                          : (isArabic ? 'مطعم / متجر #${item.merchantId ?? ""}' : 'Restaurant #${item.merchantId ?? ""}'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : kCharcoalDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isDarkStore)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          isArabic ? '🏢 مستودع جيتك المركزي' : '🏢 Jitak Dark Store',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6366F1),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (GlobalVar.checkString(item.merchantAddress))
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            AppIcon(PhosphorIcons.mapPinBold, size: 12, color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item.merchantAddress!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
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
              if (isPickedUp) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF064E3B) : kGreenLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isArabic ? 'تم الاستلام ✓' : 'Picked Up ✓',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF34D399) : kGreen,
                    ),
                  ),
                ),
              ] else if (item.orderDetailStatus == OrderDetailsStatus.merchantAccepted) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isArabic ? 'قيد التجهيز' : 'Preparing',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Action Buttons Bar (Call, Map, Pickup Button)
          if (GlobalVar.checkString(item.merchantPhone) || mapNavUrl != null || isAccepted) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Call merchant button (if phone exists)
                if (GlobalVar.checkString(item.merchantPhone))
                  InkWell(
                    onTap: () => launchUrl(Uri.parse('tel:${item.merchantPhone}')),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF064E3B) : kGreenLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppIcon(PhosphorIcons.phoneCallBold, size: 14, color: kGreen),
                          const SizedBox(width: 4),
                          Text(
                            isArabic ? 'اتصال' : 'Call',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kGreen),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Map navigation to merchant button (if coords exist)
                if (mapNavUrl != null)
                  InkWell(
                    onTap: () async {
                      try {
                        await launchUrl(Uri.parse(mapNavUrl), mode: LaunchMode.externalApplication);
                      } catch (err) {
                        showDialog(context: context, builder: (ctx) => CustomDialog(message: err.toString()));
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppIcon(PhosphorIcons.navigationArrowBold, size: 14, color: Color(0xFF2563EB)),
                          const SizedBox(width: 4),
                          Text(
                            isArabic ? 'الخريطة' : 'Map',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Pickup status action button
                if (isAccepted)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkStore ? const Color(0xFF6366F1) : kPrimaryOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppIcon(PhosphorIcons.checkCircleBold, size: 14, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          isArabic ? 'استلام الطلب' : 'Pickup Order',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    onPressed: () async {
                      try {
                        await Provider.of<OrderProvider>(context, listen: false).startShipping(orderId, item.merchantId!);
                      } catch (err) {
                        showDialog(context: context, builder: (ctx) => CustomDialog(message: err.toString()));
                      }
                    },
                  ),
              ],
            ),
          ],

          const SizedBox(height: 10),
          Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : kBorderColor.withValues(alpha: 0.5)),
          const SizedBox(height: 8),

          // Items inside this merchant order
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
}

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
          // Product Thumbnail
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
                  GlobalVar.checkString(item.productTitle) ? item.productTitle! : 'Item #${item.productId ?? ""}',
                  style: TextStyle(
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
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Quantity Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? const Color(0xFF334155) : kBorderColor, width: 1),
            ),
            child: Text(
              '${item.quantity ?? 1} ×',
              style: const TextStyle(
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
    const double size = 44;
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
          size: 20,
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}

class AvailableOrderCard extends StatefulWidget {
  final OrderModel item;
  final VoidCallback onClaimed;

  const AvailableOrderCard({
    Key? key,
    required this.item,
    required this.onClaimed,
  }) : super(key: key);

  @override
  State<AvailableOrderCard> createState() => _AvailableOrderCardState();
}

class _AvailableOrderCardState extends State<AvailableOrderCard> {
  bool _isClaiming = false;

  Future<void> _handleClaim(BuildContext context) async {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (!provider.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'يجب بدء الوردية (الوضع متاح) أولاً لتتمكن من استلام الطلب.'
                : 'Please start your shift (go online) first to claim orders.',
          ),
          backgroundColor: kRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isClaiming = true);

    try {
      await provider.claimOrder(widget.item.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic
                      ? 'تم استلام الطلب #${widget.item.id} بنجاح! تم نقله إلى قائمة طلباتي.'
                      : 'Order #${widget.item.id} claimed successfully!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: kGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onClaimed();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تعذر استلام الطلب: ربما تم استلامه من قبل كابتن آخر.'
                : 'Failed to claim order: May have already been taken.',
          ),
          backgroundColor: kRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.35) : const Color(0xFF3B82F6).withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Order ID + Status pill ("متاح للاستلام")
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppIcon(PhosphorIcons.hashBold, size: 14, color: Color(0xFF2563EB)),
                          const SizedBox(width: 2),
                          Text(
                            '${item.id}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF064E3B) : kGreenLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppIcon(PhosphorIcons.mopedBold, size: 13, color: kGreen),
                          const SizedBox(width: 4),
                          Text(
                            isArabic ? 'متاح للاستلام' : 'Available',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: kGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        AppIcon(PhosphorIcons.clockBold, size: 14, color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted),
                        const SizedBox(width: 4),
                        Text(
                          GlobalVar.dateForamt(item.purchaseDate, kDateTimeFormat) ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    PriceTextWidget.small(
                      price: item.price,
                      currencyString: isArabic ? 'ل.س' : 'SYP',
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 1, color: isDark ? const Color(0xFF334155) : kBorderColor),

          // Merchant & Delivery Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Pickup store(s)
                if (item.orderDetails != null && item.orderDetails!.isNotEmpty)
                  ...item.orderDetails!.map((merchant) {
                    final hasMerchantCoords = merchant.lat != null && merchant.lng != null && merchant.lat != 0 && merchant.lng != 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : kSurfaceWarm.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : kBorderColor, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Restaurant Logo or Storefront Icon
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: GlobalVar.checkString(GlobalVar.getMerchantLogo(merchant.merchantLogo))
                                    ? ImageView(
                                        GlobalVar.getMerchantLogo(merchant.merchantLogo),
                                        width: 36,
                                        height: 36,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Center(
                                          child: AppIcon(PhosphorIcons.storefrontBold, size: 18, color: Color(0xFF2563EB)),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isArabic ? 'المطعم / نقطة الاستلام' : 'Restaurant / Pickup',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                                      ),
                                    ),
                                    Text(
                                      GlobalVar.checkString(merchant.merchantTitle)
                                          ? merchant.merchantTitle!
                                          : (isArabic ? 'مطعم #${merchant.merchantId ?? ""}' : 'Restaurant #${merchant.merchantId ?? ""}'),
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : kCharcoalDark,
                                      ),
                                    ),
                                    if (GlobalVar.checkString(merchant.merchantAddress))
                                      Text(
                                        merchant.merchantAddress!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              if (hasMerchantCoords)
                                InkWell(
                                  onTap: () => launchUrl(
                                    Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${merchant.lat},${merchant.lng}'),
                                    mode: LaunchMode.externalApplication,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const AppIcon(PhosphorIcons.navigationArrowBold, size: 13, color: Color(0xFF2563EB)),
                                        const SizedBox(width: 4),
                                        Text(
                                          isArabic ? 'الخريطة' : 'Map',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // Items Preview in this store
                          if (merchant.orderDetails != null && merchant.orderDetails!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...merchant.orderDetails!.map((product) => Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: GlobalVar.checkString(product.productImage)
                                        ? ImageView(product.productImage!.split(',').first.trim(), height: 26, width: 26, fit: BoxFit.cover)
                                        : Container(
                                            width: 26,
                                            height: 26,
                                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                            child: AppIcon(PhosphorIcons.forkKnifeBold, size: 13, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                          ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      product.productTitle ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white70 : kCharcoalDark,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${product.quantity ?? 1} ×',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kPrimaryOrange),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ],
                      ),
                    );
                  }).toList(),

                // Dropoff destination
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const AppIcon(PhosphorIcons.mapPinBold, size: 16, color: kGreen),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic ? 'وجهة التسليم (العميل)' : 'Dropoff Destination',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.address ?? (isArabic ? 'لا يوجد عنوان محدد' : 'No specified address'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : kCharcoalDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item.lat != null && item.lng != null && item.lat != 0 && item.lng != 0)
                      InkWell(
                        onTap: () => launchUrl(
                          Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${item.lat},${item.lng}'),
                          mode: LaunchMode.externalApplication,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: kGreen.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const AppIcon(PhosphorIcons.navigationArrowBold, size: 13, color: kGreen),
                              const SizedBox(width: 4),
                              Text(
                                isArabic ? 'الخريطة' : 'Map',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kGreen),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 1, color: isDark ? const Color(0xFF334155) : kBorderColor),

          // Big Claim Button
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isClaiming ? null : () => _handleClaim(context),
                icon: _isClaiming
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const AppIcon(PhosphorIcons.handGrabbingBold, size: 20, color: Colors.white),
                label: Text(
                  _isClaiming
                      ? (isArabic ? 'جاري الاستلام...' : 'Claiming...')
                      : (isArabic ? 'استلام هذا الطلب والتوصيل' : 'Accept & Claim Delivery'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
