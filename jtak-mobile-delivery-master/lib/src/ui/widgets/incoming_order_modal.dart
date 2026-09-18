import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../config/themes/colors.dart';
import '../../core/controllers/order_provider.dart';
import '../../core/enums/payment_method_enum.dart';
import '../../core/models/lat_lng_model.dart';
import '../../core/models/order_model.dart';
import '../../core/services/location_service.dart';

class IncomingOrderModal extends StatefulWidget {
  final OrderModel order;
  final Future<void> Function() onAccept;
  final VoidCallback onDismiss;

  const IncomingOrderModal({
    required this.order,
    required this.onAccept,
    required this.onDismiss,
    Key? key,
  }) : super(key: key);

  static Future<void> show(BuildContext context, OrderModel order) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'IncomingOrder',
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, anim1, anim2) {
        return IncomingOrderModal(
          order: order,
          onAccept: () async {
            final prov = Provider.of<OrderProvider>(context, listen: false);
            final isAvailable =
                prov.availableOrders.any((a) => a.id == order.id);
            if (isAvailable && order.id != null) {
              await prov.claimOrder(order.id!);
            }
            prov.dismissIncomingOrderAlert();
            if (Navigator.of(ctx).canPop()) {
              Navigator.of(ctx).pop();
            }
          },
          onDismiss: () {
            Provider.of<OrderProvider>(context, listen: false)
                .dismissIncomingOrderAlert();
            if (Navigator.of(ctx).canPop()) {
              Navigator.of(ctx).pop();
            }
          },
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: child,
        );
      },
    );
  }

  @override
  _IncomingOrderModalState createState() => _IncomingOrderModalState();
}

class _IncomingOrderModalState extends State<IncomingOrderModal>
    with SingleTickerProviderStateMixin {
  static const int kTotalSeconds = 30;
  int _remainingSeconds = kTotalSeconds;
  Timer? _timer;
  late AnimationController _pulseController;
  LatLng? _driverLocation;
  bool _isAccepting = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _loadDriverLocation();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        if (mounted) {
          setState(() {
            _remainingSeconds--;
          });
          if (_remainingSeconds <= 5) {
            HapticFeedback.mediumImpact();
          }
        }
      } else {
        _timer?.cancel();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatCurrency(double? amount) {
    if (amount == null) return '0';
    final rounded =
        amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2);
    return rounded.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  Future<void> _loadDriverLocation() async {
    try {
      final loc = await LocationService().getCurrentLocation();
      if (loc != null && mounted) {
        setState(() => _driverLocation = loc);
      }
    } catch (_) {
      // Best-effort only: falls back to showing no distance/ETA.
    }
  }

  Future<void> _acceptOrder() async {
    if (_isAccepting) return;
    setState(() => _isAccepting = true);
    try {
      await widget.onAccept();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', '').trim(),
            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
          ),
          backgroundColor: kRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  /// Real distance from the driver's live GPS fix to the pickup merchant,
  /// in kilometers. Null when either point is unavailable.
  double? _distanceToPickupKm() {
    final driver = _driverLocation;
    final details = widget.order.orderDetails;
    if (driver == null || details == null || details.isEmpty) return null;
    final destLat = details.first.lat;
    final destLng = details.first.lng;
    if (destLat == null || destLng == null) return null;
    return Geolocator.distanceBetween(
          driver.latitude,
          driver.longitude,
          destLat,
          destLng,
        ) /
        1000;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final progress = _remainingSeconds / kTotalSeconds;
    final isUrgent = _remainingSeconds <= 7;

    final details = widget.order.orderDetails ?? [];
    final firstMerchant = details.isNotEmpty ? details.first : null;
    final merchantTitle = (firstMerchant?.merchantTitle?.isNotEmpty ?? false)
        ? firstMerchant!.merchantTitle!
        : (isArabic ? 'متجر غير معروف' : 'Unknown merchant');
    final merchantAddress =
        (firstMerchant?.merchantAddress?.isNotEmpty ?? false)
            ? firstMerchant!.merchantAddress!
            : (isArabic ? 'العنوان غير متوفر' : 'Address unavailable');
    final customerAddress = (widget.order.address?.isNotEmpty ?? false)
        ? widget.order.address!
        : (isArabic ? 'العنوان غير متوفر' : 'Address unavailable');

    // Extract product preview items
    final List<String> itemNames = [];
    int totalItemCount = 0;
    for (final m in details) {
      if (m.orderDetails != null) {
        for (final item in m.orderDetails!) {
          final qty = item.quantity ?? 1;
          totalItemCount += qty;
          if (item.productTitle != null && item.productTitle!.isNotEmpty) {
            itemNames.add('${qty}x ${item.productTitle}');
          }
        }
      }
    }

    final priceFormatted = _formatCurrency(widget.order.price);
    final distanceKm = _distanceToPickupKm();
    final distanceFormatted = distanceKm != null
        ? '${distanceKm.toStringAsFixed(1)} ${isArabic ? 'كم' : 'km'}'
        : '-- ${isArabic ? 'كم' : 'km'}';
    // Estimated at a conservative average moped speed (no routing/ETA backend exists yet).
    const averageSpeedKmh = 25;
    final etaMinutes = distanceKm != null
        ? (distanceKm / averageSpeedKmh * 60).ceil().clamp(1, 999)
        : null;
    final etaFormatted = etaMinutes != null
        ? (isArabic ? '$etaMinutes دقيقة' : '$etaMinutes mins')
        : (isArabic ? '-- دقيقة' : '-- mins');

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.92,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color:
                    (isUrgent ? kRed : kPrimaryOrange).withValues(alpha: 0.22),
                blurRadius: 36,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
              const BoxShadow(
                color: Color(0x14000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: (isUrgent ? kRed : kPrimaryOrange).withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Top Header: Pulsing Icon & Countdown Timer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Pulsing Alert Badge
                      Row(
                        children: [
                          ScaleTransition(
                            scale: Tween<double>(begin: 0.92, end: 1.08)
                                .animate(_pulseController),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isUrgent
                                    ? (isDark
                                        ? const Color(0xFF7F1D1D)
                                        : const Color(0xFFFEE2E2))
                                    : (isDark
                                        ? const Color(0xFF2A1C12)
                                        : const Color(0xFFFFF0E8)),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isUrgent
                                    ? PhosphorIcons.warningBold
                                    : PhosphorIcons.mopedBold,
                                color: isUrgent ? kRed : kPrimaryOrange,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isArabic ? 'طلب جديد!' : 'New Order!',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : kCharcoalDark,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              Text(
                                widget.order.id != null
                                    ? '#${widget.order.id}'
                                    : '',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: kPrimaryOrange,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Countdown Circle Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isUrgent
                              ? (isDark
                                  ? const Color(0xFF450A0A)
                                  : const Color(0xFFFEF2F2))
                              : (isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isUrgent
                                ? (isDark
                                    ? const Color(0xFF991B1B)
                                    : const Color(0xFFFECACA))
                                : (isDark
                                    ? const Color(0xFF475569)
                                    : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 2.5,
                                backgroundColor: isDark
                                    ? const Color(0xFF475569)
                                    : const Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isUrgent ? kRed : kPrimaryOrange,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              '${_remainingSeconds}s',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isUrgent
                                    ? (isDark
                                        ? const Color(0xFFF87171)
                                        : kRed)
                                    : (isDark ? Colors.white : kCharcoalDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 2. Route Stepper Card (Pickup Store -> Customer Dropoff)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Pickup Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Store Icon
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF2A1C12)
                                    : const Color(0xFFFFF0E8),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF7C2D12)
                                      : const Color(0xFFFFD4C0),
                                ),
                              ),
                              child: const Icon(
                                PhosphorIcons.storefrontBold,
                                color: kPrimaryOrange,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        isArabic ? 'نقطة الاستلام' : 'Pickup',
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: kPrimaryOrange,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          merchantTitle,
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? Colors.white
                                                : kCharcoalDark,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    merchantAddress,
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 12,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : kCharcoalMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Route Connecting Line
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 2),
                          child: Align(
                            alignment: isArabic
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: EdgeInsets.only(
                                right: isArabic ? 1 : 0,
                                left: isArabic ? 0 : 1,
                              ),
                              height: 16,
                              width: 2,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),
                        ),

                        // Dropoff Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Dropoff Pin Icon
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF064E3B)
                                    : const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF047857)
                                      : const Color(0xFFA7F3D0),
                                ),
                              ),
                              child: const Icon(
                                PhosphorIcons.mapPinBold,
                                color: kGreen,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        isArabic ? 'نقطة التسليم' : 'Dropoff',
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: kGreen,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          widget.order.user != null &&
                                                  widget.order.user!.isNotEmpty
                                              ? widget.order.user!
                                              : (isArabic
                                                  ? 'العميل'
                                                  : 'Customer'),
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? Colors.white
                                                : kCharcoalDark,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    customerAddress,
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 12,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : kCharcoalMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 3. 3-Card Metrics Row (Reward / Distance / Est. Time)
                  Row(
                    children: [
                      // Earning / Total Price
                      Expanded(
                        child: _buildMetricPill(
                          icon: PhosphorIcons.walletBold,
                          label: isArabic ? 'قيمة الطلب' : 'Order Value',
                          value: '$priceFormatted ${isArabic ? 'ل.س' : 'SYP'}',
                          iconColor: kPrimaryOrange,
                          bgColor: const Color(0xFFFFF4EE),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Distance
                      Expanded(
                        child: _buildMetricPill(
                          icon: PhosphorIcons.pathBold,
                          label: isArabic ? 'المسافة' : 'Distance',
                          value: distanceFormatted,
                          iconColor: const Color(0xFF0284C7),
                          bgColor: const Color(0xFFF0F9FF),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Est. Time
                      Expanded(
                        child: _buildMetricPill(
                          icon: PhosphorIcons.clockBold,
                          label: isArabic ? 'الوقت التقريبي' : 'Est. Time',
                          value: etaFormatted,
                          iconColor: const Color(0xFF16A34A),
                          bgColor: const Color(0xFFF0FDF4),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // 4. Products / Items Preview & Payment Method Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(PhosphorIcons.receiptBold,
                            size: 16,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : kCharcoalMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            itemNames.isNotEmpty
                                ? '${totalItemCount > 0 ? '$totalItemCount منتجات: ' : ''}${itemNames.take(2).join('، ')}${itemNames.length > 2 ? ' ...' : ''}'
                                : (isArabic
                                    ? 'مجموعة منتجات طازجة'
                                    : 'Fresh items bundle'),
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFCBD5E1)
                                  : kCharcoalDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2A1C12)
                                : const Color(0xFFFFF0E8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.order.paymentMethod ==
                                        PaymentMethod.payOnDelivery ||
                                    widget.order.paymentMethod == null
                                ? (isArabic
                                    ? 'الدفع نقداً'
                                    : 'Cash on Delivery')
                                : (isArabic
                                    ? 'محفظة إلكترونية'
                                    : 'Digital Wallet'),
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: kPrimaryOrange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 5. Dual Action Buttons: Reject / Accept Order
                  Row(
                    children: [
                      // Reject Button
                      Expanded(
                        flex: 3,
                        child: OutlinedButton(
                          onPressed: _isAccepting ? null : widget.onDismiss,
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                isDark ? Colors.white70 : kCharcoalMuted,
                            side: BorderSide(
                              color: isDark
                                  ? const Color(0xFF475569)
                                  : const Color(0xFFCBD5E1),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            isArabic ? 'رفض' : 'Decline',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : kCharcoalMedium,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Accept Order Button
                      Expanded(
                        flex: 7,
                        child: ElevatedButton.icon(
                          onPressed: _isAccepting ? null : _acceptOrder,
                          icon: _isAccepting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  PhosphorIcons.checkCircleBold,
                                  size: 20,
                                  color: Colors.white,
                                ),
                          label: Text(
                            _isAccepting
                                ? (isArabic
                                    ? 'جارٍ استلام الطلب...'
                                    : 'Receiving order...')
                                : (isArabic ? 'استلام الطلب' : 'Receive order'),
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryOrange,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: kPrimaryOrange.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricPill({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    required Color bgColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : kCharcoalDark,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
