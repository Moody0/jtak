import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import 'package:cached_network_image/cached_network_image.dart';
import '../../../../main_imports.dart';
import '../../../config/constants/app_constant.dart';
import '../../../config/themes/colors.dart';
import '../../../core/controllers/app_parameters_provider.dart';
import '../../../core/controllers/app/home_navigation_provider.dart';
import '../../../core/controllers/order/cart_provider.dart';
import '../../../core/data/mock_catalog_data.dart';
import '../../../core/enums/payment_method_enum.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/services/locator.dart';
import '../../../ui/pages/account/login_page.dart';
import '../../../utils/custom_widgets/loading.dart';
import '../../../utils/custom_widgets/messages.dart';
import '../../../utils/custom_widgets/syrian_flag.dart';
import '../../../utils/providers/custom_exception.dart';
import '../../../utils/utilities/global_var.dart';
import '../../../core/models/phone_number_model.dart';
import '../../../core/models/user/address_model.dart';
import '../../widgets/header_circle_button.dart';
import 'checkout_location_edit_sheet.dart';
import 'order_confirmation_page.dart';

/// ---------------------------------------------------------------------------
/// JTAK Modern Payment Method Page (طريقة الدفع - Flat Shadow-Free Design)
/// ---------------------------------------------------------------------------

class OrderPaymentPage extends StatefulWidget {
  static const String routeName = '/OrderPaymentPage';

  const OrderPaymentPage({super.key});

  @override
  State<OrderPaymentPage> createState() => _OrderPaymentPageState();
}

class _OrderPaymentPageState extends State<OrderPaymentPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late CartProvider _cartProvider;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authService = locator<AuthenticationService>();
      if (!authService.isLogin()) {
        await authService.getAuthorizationData();
      }
      await locator<CartProvider>().cartInfo.initData();
      if (mounted) setState(() {});
    });
  }

  static String _formatPrice(double? price) {
    if (price == null) return '0';
    return price.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    _cartProvider = Provider.of<CartProvider>(context);
    final double subtotal = _cartProvider.order.price ??
        _cartProvider.localCartItems.fold(
          0.0,
          (sum, item) => sum + (item.singleFinalPrice * item.quantity),
        );
    final double deliveryFee = _cartProvider.deliveryFee;
    final double grandTotal = subtotal + deliveryFee;
    final int itemsCount = _cartProvider.totalQuantity;

    return FullScreenLoading(
      inAsyncCall: _cartProvider.isBusy,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: _buildAppBar(),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              physics: const ClampingScrollPhysics(),
              children: [
                // 1. Delivery Address Summary Card
                _buildDeliveryAddressCard(),
                const SizedBox(height: 16),

                // 2. Ordered Items Preview Thumbnail Strip
                _buildOrderItemsPreviewCard(),
                const SizedBox(height: 16),

                // 3. Payment Methods Selection
                Text(
                  'اختر طريقة الدفع',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: kCharcoalDark,
                  ),
                ),
                const SizedBox(height: 12),

                // Cash on Delivery Card (Active)
                _buildPaymentOptionCard(
                  method: PaymentMethod.payOnDelivery,
                  title: 'الدفع عند الاستلام (كاش)',
                  subtitle: 'ادفع نقداً لمندوب التوصيل فور استلام طلبك',
                  icon: PhosphorIconsFill.wallet,
                  iconBg: const Color(0xFFFFF0E8),
                  iconColor: kPrimaryOrange,
                  isEnabled: true,
                ),
                const SizedBox(height: 12),

                // Credit Card / Electronic Payment Card (Coming Soon)
                _buildPaymentOptionCard(
                  method: PaymentMethod.creditCardPayment,
                  title: 'الدفع الإلكتروني / البطاقات',
                  subtitle: 'سيريتل كاش، إم تي إن كاش، والبطاقات البنكية',
                  icon: PhosphorIconsFill.creditCard,
                  iconBg: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF2563EB),
                  isEnabled: false,
                  badgeText: 'قريباً',
                ),
                const SizedBox(height: 20),

                // 3. Bill & Payment Summary Card
                _buildInvoiceSummaryCard(
                    subtotal, deliveryFee, grandTotal, itemsCount),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _buildBottomCheckoutBar(grandTotal),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
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
        'طريقة الدفع',
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

  Widget _buildOrderItemsPreviewCard() {
    final items = _cartProvider.effectiveOrderDetails;
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الأصناف المطلوبة',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: kCharcoalDark,
                ),
              ),
              Text(
                '${_cartProvider.totalQuantity} أصناف',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                final mock =
                    MockCatalogData.getMenuItemById(item.productId ?? 0);
                final rawImg = (item.productImage != null &&
                        item.productImage!.trim().isNotEmpty)
                    ? item.productImage!
                    : (mock?.imageUrl ?? '');
                final imgUrl = GlobalVar.getImageUrl(rawImg);
                final title = (item.productTitle?.isNotEmpty == true)
                    ? item.productTitle!
                    : (mock?.title ?? 'وجبة خاصة');
                final qty = item.quantity ?? 1;

                return Tooltip(
                  message: title,
                  child: Container(
                    width: 74,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: const Color(0xFFE2E8F0), width: 1),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: SizedBox(
                            width: 74,
                            height: 74,
                            child: imgUrl.isNotEmpty
                                ? (imgUrl.startsWith('assets')
                                    ? Image.asset(
                                        imgUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Center(
                                          child: Icon(
                                              PhosphorIconsFill.hamburger,
                                              color: Color(0xFF94A3B8),
                                              size: 24),
                                        ),
                                      )
                                    : CachedNetworkImage(
                                        imageUrl: imgUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(
                                            color: const Color(0xFFF1F5F9)),
                                        errorWidget: (_, __, ___) =>
                                            const Center(
                                          child: Icon(
                                              PhosphorIconsFill.hamburger,
                                              color: Color(0xFF94A3B8),
                                              size: 24),
                                        ),
                                      ))
                                : const Center(
                                    child: Icon(PhosphorIconsFill.hamburger,
                                        color: Color(0xFF94A3B8), size: 24),
                                  ),
                          ),
                        ),
                        // Dark Gradient title overlay at bottom
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.75),
                                ],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(13)),
                            ),
                            child: Text(
                              title,
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        // Quantity Badge (Top-left in RTL)
                        if (qty > 1)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: kPrimaryOrange,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                '$qty×',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openLocationEditor({
    required String currentAddress,
    required String? rawPhone,
  }) {
    if (_isSubmitting || _cartProvider.isBusy) return;
    HapticFeedback.lightImpact();
    final mainAddress =
        locator<AppParametersProvider>().mainAddressService.mainAddress;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => CheckoutLocationEditSheet(
        initialAddress: currentAddress,
        initialPhone:
            rawPhone ?? _cartProvider.cartInfo.phoneNumber?.phoneNumber ?? '',
        currentLat: _cartProvider.cartInfo.lat ?? mainAddress.lat,
        currentLng: _cartProvider.cartInfo.lng ?? mainAddress.lng,
        onSave: (newAddress, newLat, newLng, newPhone) async {
          _cartProvider.cartInfo.address = newAddress;
          if (newLat != null && newLng != null) {
            _cartProvider.cartInfo.lat = newLat;
            _cartProvider.cartInfo.lng = newLng;
          }
          if (newPhone != null && newPhone.trim().isNotEmpty) {
            String cleanP = newPhone.replaceAll(RegExp(r'\s+'), '');
            _cartProvider.cartInfo.phoneNumber = PhoneNumberModel(
              isoCode: 'SY',
              dialCode: '+963',
              phoneNumber: cleanP,
            );
          }
          final updatedModel = AddressModel(
            title: newAddress,
            fullAddress: newAddress,
            lat: newLat ?? _cartProvider.cartInfo.lat,
            lng: newLng ?? _cartProvider.cartInfo.lng,
            phoneNumber: newPhone ?? rawPhone,
          );
          await locator<AppParametersProvider>()
              .mainAddressService
              .setMainAddress(updatedModel, resetCart: false);

          if (mounted) {
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(PhosphorIconsFill.checkCircle,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'تم تحديث موقع وعنوان التوصيل بنجاح',
                      style: GoogleFonts.ibmPlexSansArabic(
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF10B981),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildDeliveryAddressCard() {
    final mainAddress =
        locator<AppParametersProvider>().mainAddressService.mainAddress;
    final authUser = locator<AuthenticationService>().user;

    final String? rawAddress = _cartProvider.cartInfo.address;
    final String addressText = (rawAddress != null && rawAddress.isNotEmpty)
        ? rawAddress
        : ((mainAddress.fullAddress != null &&
                mainAddress.fullAddress!.isNotEmpty)
            ? mainAddress.fullAddress!
            : ((mainAddress.title != null && mainAddress.title!.isNotEmpty)
                ? mainAddress.title!
                : 'دمشق، سوريا'));

    final String? rawPhone = _cartProvider.cartInfo.phoneNumber?.phoneNumber ??
        authUser?.phoneNumber;
    String phoneText = '09xx xxx xxx';
    if (rawPhone != null && rawPhone.isNotEmpty) {
      String clean = rawPhone.replaceAll(RegExp(r'\s+'), '');
      if (clean.startsWith('+963') && clean.length >= 12) {
        clean = '0${clean.substring(4)}';
      }
      if (clean.length == 10 && clean.startsWith('09')) {
        phoneText =
            '${clean.substring(0, 4)} ${clean.substring(4, 7)} ${clean.substring(7)}';
      } else {
        phoneText = clean;
      }
    }

    final bool isEnglishAddress = addressText.contains(RegExp(r'[a-zA-Z]'));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: (_isSubmitting || _cartProvider.isBusy)
            ? null
            : () => _openLocationEditor(
                  currentAddress: addressText,
                  rawPhone: rawPhone,
                ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Icon(PhosphorIconsFill.mapPin,
                      color: kPrimaryOrange, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'التوصيل إلى',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0E8),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: const Color(0xFFFFD8C2), width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(PhosphorIconsBold.pencilSimple,
                                      size: 10, color: kPrimaryOrange),
                                  const SizedBox(width: 3),
                                  Text(
                                    'تعديل',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: kPrimaryOrange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SyrianFlag(
                                  width: 17, height: 11, borderRadius: 1.5),
                              const SizedBox(width: 5),
                              Text(
                                phoneText,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF475569),
                                ),
                                textDirection: TextDirection.ltr,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      addressText,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kCharcoalDark,
                        height: 1.35,
                      ),
                      textDirection: isEnglishAddress
                          ? TextDirection.ltr
                          : TextDirection.rtl,
                      textAlign: TextAlign.start,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Icon(
                  PhosphorIconsRegular.caretLeft,
                  size: 16,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOptionCard({
    required PaymentMethod method,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required bool isEnabled,
    String? badgeText,
  }) {
    final bool isSelected =
        _cartProvider.orderPayment.paymentMethod == method && isEnabled;

    return GestureDetector(
      onTap: isEnabled
          ? () {
              HapticFeedback.selectionClick();
              setState(() {
                _cartProvider.orderPayment.paymentMethod = method;
              });
            }
          : () {
              context.showSnakBar(
                  'سيتم تفعيل الدفع الإلكتروني قريباً في التحديث القادم');
            },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? kPrimaryOrange : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1.1,
          ),
        ),
        child: Row(
          children: [
            // Icon Squircle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Icon(icon, color: iconColor, size: 22),
              ),
            ),
            const SizedBox(width: 14),

            // Titles
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: isEnabled
                              ? kCharcoalDark
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            // Selection Radio Dot
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? kPrimaryOrange : const Color(0xFFCBD5E1),
                  width: isSelected ? 6.5 : 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceSummaryCard(
      double subtotal, double deliveryFee, double grandTotal, int itemsCount) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ملخص الفاتورة',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: kCharcoalDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$itemsCount وجبات',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildSummaryRow('المجموع الفرعي للوجبات',
              '${_formatPrice(subtotal)} $kMainCurrencySymbol'),
          const SizedBox(height: 8),
          _buildSummaryRow(
            'رسوم خدمة التوصيل',
            deliveryFee > 0
                ? '${_formatPrice(deliveryFee)} $kMainCurrencySymbol'
                : 'مجاناً',
            isHighlight: deliveryFee == 0,
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'المبلغ المستحق للدفع',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  color: kCharcoalDark,
                ),
              ),
              Text(
                '${_formatPrice(grandTotal)} $kMainCurrencySymbol',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: kPrimaryOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value,
      {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 13,
            fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w700,
            color: isHighlight ? const Color(0xFF059669) : kCharcoalDark,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomCheckoutBar(double grandTotal) {
    final bool isActionDisabled = _isSubmitting || _cartProvider.isBusy;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1.2),
        ),
      ),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: isActionDisabled ? null : _submitOrderFun,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: isActionDisabled
                  ? kPrimaryOrange.withValues(alpha: 0.65)
                  : kPrimaryOrange,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isActionDisabled) ...[
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'جاري تأكيد الطلب...',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ] else ...[
                  Transform.flip(
                    flipX: true,
                    child: const Icon(PhosphorIconsFill.checkCircle,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'تأكيد الطلب الآن (${_formatPrice(grandTotal)} $kMainCurrencySymbol)',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submitOrderFun() async {
    if (_isSubmitting || _cartProvider.isBusy) return;
    HapticFeedback.heavyImpact();

    if (!_cartProvider.reachesAllMinOrders) {
      final v = _cartProvider.primaryMinOrderViolation;
      final storeName = v?.merchantName ?? 'المتجر';
      final minAmt = v?.minOrder ?? 0;
      final remAmt = v?.remaining ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'الحد الأدنى للطلب من «$storeName» هو ${_formatPrice(minAmt.toDouble())} ل.س (متبقي ${_formatPrice(remAmt)} ل.س)',
            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
          ),
          backgroundColor: const Color(0xFF1F2937),
        ),
      );
      return;
    }

    final authService = locator<AuthenticationService>();

    if (!authService.isLogin() || !authService.hasCompletedProfile) {
      await authService.getAuthorizationData();
    }

    if (!authService.isLogin() || !authService.hasCompletedProfile) {
      if (!mounted) return;
      final shouldLogin = await _showLoginRequiredSheet(context);
      if (shouldLogin != true || !mounted) return;

      final loggedIn = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
      if (mounted) {
        await authService.getAuthorizationData();
        await _cartProvider.cartInfo.initData();
        setState(() {});
      }
      if (loggedIn != true ||
          !authService.isLogin() ||
          !authService.hasCompletedProfile ||
          !mounted) {
        return;
      }
    }

    if (mounted) {
      setState(() {
        _isSubmitting = true;
      });
    }

    try {
      if (_formKey.currentState?.validate() ?? true) {
        final placedOrder = await _cartProvider.submitOrder();
        if (!mounted) return;

        if (placedOrder != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OrderConfirmationPage(order: placedOrder),
            ),
          );
          return;
        } else {
          Navigator.of(context).popUntil((route) => route.isFirst);
          Provider.of<HomeNavigationProvider>(context, listen: false)
              .changePage(1);
          return;
        }
      }
    } catch (err) {
      if (mounted) {
        final cleanMsg = err
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('Exception:', '')
            .replaceAll('Error: ', '')
            .trim();

        final bool isAuthError = err is UnauthorisedException ||
            cleanMsg.contains('صلاحية الجلسة') ||
            cleanMsg.contains('غير مصرح') ||
            cleanMsg.toLowerCase().contains('unauthorized');

        if (isAuthError) {
          // Clear invalid tokens only while preserving user profile & full name
          await authService.clearAuthTokensOnly();
          if (!mounted) return;

          final shouldLogin = await _showLoginRequiredSheet(context);
          if (shouldLogin == true && mounted) {
            final res = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
            );
            if (mounted) {
              await authService.getAuthorizationData();
              await _cartProvider.cartInfo.initData();
              setState(() {});
              if (res is bool && res) {
                // If login succeeded, proceed with submitting the order
                _submitOrderFun();
              }
            }
          }
        } else {
          showDialog(
            context: context,
            builder: (context) => CustomDialog(
              title: 'تنبيه بخصوص الطلب',
              message: cleanMsg.isNotEmpty
                  ? cleanMsg
                  : 'حدث خطأ أثناء إرسال الطلب، يرجى المحاولة لاحقاً',
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<bool?> _showLoginRequiredSheet(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sheet Handle Bar
              Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 24),

              // Icon Avatar Squircle
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0E8),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    PhosphorIconsFill.signIn,
                    color: kPrimaryOrange,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                'تسجيل الدخول مطلوب',
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 18.5,
                  fontWeight: FontWeight.w800,
                  color: kCharcoalDark,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                'يرجى تسجيل الدخول أو إنشاء حساب جديد لإتمام عملية الطلب وحفظ عنوان التوصيل.',
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 26),

              // Action Button: Login Now
              GestureDetector(
                onTap: () => Navigator.pop(ctx, true),
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
                      'تسجيل الدخول الآن',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Cancel Button
              GestureDetector(
                onTap: () => Navigator.pop(ctx, false),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'إلغاء',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
