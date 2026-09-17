import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/app_parameters_provider.dart';
import '../../../core/controllers/order/order_provider.dart';
import '../../../core/enums/order_details_status_enum.dart';
import '../../../core/models/order/order_model.dart';
import '../../../core/services/locator.dart';
import 'custom_map_markers.dart';

/// ---------------------------------------------------------------------------
/// Dedicated Premium Live Delivery Tracking Page
/// - Live moving delivery driver icon smoothly navigating to the order address
/// - Pure, uncluttered map display (NO route polylines, NO text overlays on pins)
/// - ZERO shadow effects on buttons (flat, architectural, modern design)
/// - Symmetrical, perfectly sized icons (~26x26 dp)
/// ---------------------------------------------------------------------------

class LiveTrackingPage extends StatefulWidget {
  static const String routeName = '/LiveTrackingPage';
  final OrderModel order;

  const LiveTrackingPage({super.key, required this.order});

  @override
  State<LiveTrackingPage> createState() => _LiveTrackingPageState();
}

class _LiveTrackingPageState extends State<LiveTrackingPage>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  Timer? _liveSyncTimer;

  // Custom Markers
  BitmapDescriptor? _courierIcon;
  BitmapDescriptor? _customerIcon;

  // Smooth Driver Movement Animation
  AnimationController? _driverMoveController;
  LatLng? _currentDriverPos;
  LatLng? _fromDriverPos;
  LatLng? _targetDriverPos;
  bool _hasFittedInitialBounds = false;

  @override
  void initState() {
    super.initState();
    _loadCustomMarkers();

    // Smooth 1.4s animation between GPS location updates
    _driverMoveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..addListener(() {
        if (_fromDriverPos != null && _targetDriverPos != null) {
          final double t = Curves.easeInOut.transform(_driverMoveController!.value);
          final double lat = _fromDriverPos!.latitude +
              (_targetDriverPos!.latitude - _fromDriverPos!.latitude) * t;
          final double lng = _fromDriverPos!.longitude +
              (_targetDriverPos!.longitude - _fromDriverPos!.longitude) * t;
          setState(() {
            _currentDriverPos = LatLng(lat, lng);
          });
        }
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.order.id != null) {
        final p = Provider.of<OrderProvider>(context, listen: false);
        p.loadOrder(widget.order.id!, silent: true);
        p.loadLiveTrack(widget.order.id!);
        _startLiveSync();
      }
    });
  }

  void _loadCustomMarkers() async {
    final courier = await CustomMapMarkers.getCourierMarker();
    final customer = await CustomMapMarkers.getCustomerMarker();
    if (mounted) {
      setState(() {
        _courierIcon = courier;
        _customerIcon = customer;
      });
    }
  }

  void _startLiveSync() {
    _liveSyncTimer?.cancel();
    _liveSyncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final p = Provider.of<OrderProvider>(context, listen: false);
      if (widget.order.id != null) {
        p.loadLiveTrack(widget.order.id!);
      }
    });
  }

  @override
  void dispose() {
    _driverMoveController?.dispose();
    _liveSyncTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  /// Updates target driver position and smoothly glides marker
  void _updateMovingDriverPos(LatLng newPos) {
    if (_currentDriverPos == null) {
      _currentDriverPos = newPos;
      _targetDriverPos = newPos;
      return;
    }
    if (newPos != _targetDriverPos) {
      _fromDriverPos = _currentDriverPos;
      _targetDriverPos = newPos;
      _driverMoveController?.forward(from: 0.0);
    }
  }

  /// Accurately animates map camera to encompass driver and destination
  void _fitMapBounds(LatLng? driverPos, LatLng clientPos) {
    if (_mapController == null) return;

    if (driverPos == null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(clientPos, 15.5));
      return;
    }

    double minLat = math.min(driverPos.latitude, clientPos.latitude);
    double maxLat = math.max(driverPos.latitude, clientPos.latitude);
    double minLng = math.min(driverPos.longitude, clientPos.longitude);
    double maxLng = math.max(driverPos.longitude, clientPos.longitude);

    // Expand bounding box slightly if waypoints are very close to prevent over-zooming
    if ((maxLat - minLat).abs() < 0.005) {
      final centerLat = (maxLat + minLat) / 2;
      minLat = centerLat - 0.0035;
      maxLat = centerLat + 0.0035;
    }
    if ((maxLng - minLng).abs() < 0.005) {
      final centerLng = (maxLng + minLng) / 2;
      minLng = centerLng - 0.0035;
      maxLng = centerLng + 0.0035;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
  }

  int _calculateEtaMinutes(LatLng driverPos, LatLng clientPos) {
    const double p = 0.017453292519943295;
    final a = 0.5 -
        math.cos((clientPos.latitude - driverPos.latitude) * p) / 2 +
        math.cos(driverPos.latitude * p) *
            math.cos(clientPos.latitude * p) *
            (1 - math.cos((clientPos.longitude - driverPos.longitude) * p)) /
            2;
    final double distanceKm = 12742 * math.asin(math.sqrt(math.max(0, a)));
    final int mins = (distanceKm * 2.2).round() + 2;
    return mins.clamp(1, 45);
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final order = orderProvider.order ?? widget.order;
    final liveTrack = orderProvider.liveTrack;
    final status = orderProvider.getOrderStatus(order);

    // 100% Real Coordinates from Backend GPS
    final LatLng clientPos = _resolveClientCoordinates(order);

    final double? dLat = liveTrack?.driverLat ?? order.deliveryLat;
    final double? dLng = liveTrack?.driverLng ?? order.deliveryLng;
    final LatLng? backendDriverPos = (dLat != null && dLng != null && dLat != 0 && dLng != 0)
        ? LatLng(dLat, dLng)
        : null;

    if (backendDriverPos != null) {
      _updateMovingDriverPos(backendDriverPos);
    }

    final LatLng? activeDriverPos = _currentDriverPos ?? backendDriverPos;
    final bool hasDriver = activeDriverPos != null;
    final String restaurantName = _extractRestaurantName(order, liveTrack);
    final String driverName = _extractDriverName(order, liveTrack);

    final int etaMinutes = (liveTrack != null && liveTrack.etaMinutes > 0)
        ? liveTrack.etaMinutes
        : (backendDriverPos != null
            ? _calculateEtaMinutes(backendDriverPos, clientPos)
            : 8);

    // Initial camera fitting
    if (!_hasFittedInitialBounds && _mapController != null) {
      _hasFittedInitialBounds = true;
      _fitMapBounds(activeDriverPos, clientPos);
    }

    // 1. Clean, Modern Map Markers (NO route lines, NO huge halos, NO text overlays)
    final Set<Marker> markers = {
      // Customer Destination / Order Address Icon
      Marker(
        markerId: const MarkerId('client_dest'),
        position: clientPos,
        anchor: CustomMapMarkers.customerAnchor,
        consumeTapEvents: true,
        icon: _customerIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ),
    };

    // Moving Delivery Driver Icon
    if (hasDriver) {
      markers.add(
        Marker(
          markerId: const MarkerId('live_driver'),
          position: activeDriverPos,
          anchor: CustomMapMarkers.courierAnchor,
          consumeTapEvents: true,
          icon: _courierIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
      );
    }

    final double topSafe = MediaQuery.of(context).padding.top;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // 1. Fullscreen Interactive Google Map (Moving driver icon going to order address)
            Positioned.fill(
              child: GoogleMap(
                mapType: MapType.normal,
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                compassEnabled: false,
                mapToolbarEnabled: false,
                padding: EdgeInsets.only(
                  bottom: 230,
                  top: topSafe + 110,
                  left: 16,
                  right: 16,
                ),
                initialCameraPosition: CameraPosition(
                  target: activeDriverPos ?? clientPos,
                  zoom: 15.0,
                ),
                markers: markers,
                polylines: const <Polyline>{}, // NO route line per requirement
                onMapCreated: (controller) {
                  _mapController = controller;
                  _fitMapBounds(activeDriverPos, clientPos);
                },
              ),
            ),

            // 2. Floating Top Header & Centered ETA Pill (NO Shadow Effects)
            Positioned(
              top: topSafe + 10,
              left: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Row: Centered "تتبع الطلب" + RTL Back Button on Right (Flat, No Shadow)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Arrow on Right (facing opposite direction)
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.arrow_back_rounded,
                              size: 24,
                              color: kCharcoalDark,
                            ),
                          ),
                        ),
                      ),

                      // Centered Screen Title
                      Text(
                        'تتبع الطلب',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: kCharcoalDark,
                        ),
                      ),

                      // Balancer spacer for true centering
                      const SizedBox(width: 42),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Floating ETA Pill: Flat white rounded container (NO Shadow)
                  _buildEtaPill(etaMinutes),
                ],
              ),
            ),

            // 3. Floating Recenter / Crosshair Button (Flat, NO Shadow)
            Positioned(
              bottom: 258 + (MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 0),
              right: 18,
              child: GestureDetector(
                onTap: () => _fitMapBounds(activeDriverPos, clientPos),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.my_location_rounded,
                      size: 22,
                      color: kCharcoalDark,
                    ),
                  ),
                ),
              ),
            ),

            // 4. Floating Bottom Card (Sheet - Flat, NO Shadow)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomCard(
                context,
                order: order,
                status: status,
                driverName: driverName,
                restaurantName: restaurantName,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Floating ETA Pill Capsule (Flat, NO Shadow)
  // ---------------------------------------------------------------------------
  Widget _buildEtaPill(int etaMinutes) {
    final int displayEta = etaMinutes;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Clock icon on the right in RTL
          const Icon(
            Icons.access_time_rounded,
            color: kPrimaryOrange,
            size: 19,
          ),
          const SizedBox(width: 8),
          // Text on the left in RTL
          Text(
            _formatEtaText(displayEta),
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: kPrimaryOrange,
            ),
          ),
        ],
      ),
    );
  }

  String _formatEtaText(int minutes) {
    if (minutes <= 1) {
      return 'الوصول خلال دقيقة واحدة';
    } else if (minutes <= 10) {
      return 'الوصول خلال $minutes دقائق';
    } else {
      return 'الوصول خلال $minutes دقيقة';
    }
  }

  // ---------------------------------------------------------------------------
  // Bottom Order & Driver Tracking Card (Flat, NO Shadow)
  // ---------------------------------------------------------------------------
  Widget _buildBottomCard(
    BuildContext context, {
    required OrderModel order,
    required OrderDetailsStatus status,
    required String driverName,
    required String restaurantName,
  }) {
    final double bottomSafe = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        bottomSafe > 0 ? bottomSafe + 10 : 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Row: Driver Details (Right) + Large Orange Call Button (Left, Flat, NO Shadow)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Driver Information (Right in RTL)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'السائق',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      driverName,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'في الطريق إليك',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Large Flat Orange Call Button (NO Shadow)
              GestureDetector(
                onTap: () => _callDriver(context, order),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: kPrimaryOrange,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Phone Icon on the right in RTL
                      const Icon(
                        Icons.phone_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                      const SizedBox(width: 7),
                      // Text on the left in RTL
                      Text(
                        'اتصال بالسائق',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Divider
          Container(
            height: 1,
            color: const Color(0xFFF1F5F9),
            margin: const EdgeInsets.symmetric(vertical: 14),
          ),

          // 2. Row: Restaurant Name (Right) | Order Number (Left)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Right side: Orange Cutlery Icon + "طلب من مطعم [اسم المطعم]"
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.restaurant_rounded,
                      color: kPrimaryOrange,
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'طلب من مطعم $restaurantName',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Left side: Vertical Line + "رقم الطلب" + Order Number
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 1,
                    height: 16,
                    color: const Color(0xFFCBD5E1),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'رقم الطلب',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _toArabicNumerals(order.id),
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Delivery Confirmation PIN Banner (رمز تأكيد الاستلام)
          if (order.deliveryOtp != null && order.deliveryOtp!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Builder(
              builder: (ctx) {
                final cleanOtp = order.deliveryOtp!.replaceAll(RegExp(r'\s+'), '').trim();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFEDD5), width: 1.2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined, color: kPrimaryOrange, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'رمز تأكيد الاستلام:',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // LTR digit badges
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: cleanOtp.split('').map((digit) => Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFFFCCAA)),
                                ),
                                child: Text(
                                  digit,
                                  textDirection: TextDirection.ltr,
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: kPrimaryOrange,
                                  ),
                                ),
                              )).toList(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Clipboard.setData(ClipboardData(text: cleanOtp));
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'تم نسخ رمز التأكيد: \u200E$cleanOtp\u200E',
                                    style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
                                    textDirection: TextDirection.rtl,
                                  ),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: const Color(0xFF0F172A),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFFD8C2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.copy, size: 13, color: kPrimaryOrange),
                                  const SizedBox(width: 4),
                                  Text(
                                    'نسخ',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: kPrimaryOrange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ] else if (status != OrderDetailsStatus.delivered &&
                     status != OrderDetailsStatus.customerCanceled &&
                     status != OrderDetailsStatus.deliveryCanceled &&
                     status != OrderDetailsStatus.merchantRejected) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFEDD5), width: 1.2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: kPrimaryOrange, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'رمز تأكيد الاستلام:',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryOrange),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'جاري التحميل...',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // 3. Row: 3-Stage Stepper (Flat, NO Shadow, Clean Icons)
          _buildThreeStageStepper(status),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3-Stage Delivery Progress Stepper (Flat, NO Shadow, Clean Icons)
  // RTL Flow: [تم التأكيد] -> [جاري التوصيل] -> [تم التسليم]
  // ---------------------------------------------------------------------------
  Widget _buildThreeStageStepper(OrderDetailsStatus status) {
    int activeStage = 1; // Default for live map tracking is "جاري التوصيل"
    if (status == OrderDetailsStatus.delivered) {
      activeStage = 2;
    } else if (status == OrderDetailsStatus.pending) {
      activeStage = 0;
    }

    final bool stage1Done = activeStage >= 0;
    final bool line1Done = activeStage >= 1;
    final bool stage2Active = activeStage >= 1;
    final bool line2Done = activeStage >= 2;
    final bool stage3Done = activeStage >= 2;

    return Row(
      children: [
        // Stage 1 (Right): تم التأكيد
        _buildStepNode(
          label: 'تم التأكيد',
          isActive: stage1Done,
          isCurrent: activeStage == 0,
          child: const Icon(
            Icons.check_rounded,
            size: 17,
            color: Colors.white,
          ),
        ),

        // Connecting Line 1 (Between Stage 1 & Stage 2)
        Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.only(bottom: 22),
            decoration: BoxDecoration(
              color: line1Done ? kPrimaryOrange : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ),

        // Stage 2 (Middle): جاري التوصيل (Delivery Courier Icon)
        _buildStepNode(
          label: 'جاري التوصيل',
          isActive: stage2Active,
          isCurrent: activeStage == 1,
          child: const Icon(
            Icons.delivery_dining_rounded,
            size: 20,
            color: Colors.white,
          ),
        ),

        // Connecting Line 2 (Between Stage 2 & Stage 3)
        Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.only(bottom: 22),
            decoration: BoxDecoration(
              color: line2Done ? kPrimaryOrange : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ),

        // Stage 3 (Left): تم التسليم
        _buildStepNode(
          label: 'تم التسليم',
          isActive: stage3Done,
          isCurrent: activeStage == 2,
          child: Icon(
            Icons.check_rounded,
            size: 17,
            color: stage3Done ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildStepNode({
    required String label,
    required bool isActive,
    required bool isCurrent,
    required Widget child,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? kPrimaryOrange : const Color(0xFFE2E8F0),
          ),
          child: Center(child: child),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 11,
            fontWeight: isCurrent || isActive ? FontWeight.w800 : FontWeight.w600,
            color: isCurrent || isActive ? kPrimaryOrange : const Color(0xFF94A3B8),
          ),
          maxLines: 1,
          softWrap: false,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Data Extraction & Resolvers
  // ---------------------------------------------------------------------------
  String _extractRestaurantName(OrderModel order, dynamic liveTrack) {
    if (order.orderDetails != null && order.orderDetails!.isNotEmpty) {
      for (var d in order.orderDetails!) {
        if (d.merchantTitle != null && d.merchantTitle!.trim().isNotEmpty) {
          return d.merchantTitle!.trim();
        }
      }
    }
    final stops = liveTrack?.stops;
    if (stops != null && stops.isNotEmpty && stops.first.title != null) {
      return stops.first.title!.trim();
    }
    return 'المطعم';
  }

  String _extractDriverName(OrderModel order, dynamic liveTrack) {
    if (liveTrack?.driverName != null && liveTrack!.driverName!.trim().isNotEmpty) {
      return liveTrack.driverName!.trim();
    }
    if (order.deliveryUser != null && order.deliveryUser!.trim().isNotEmpty) {
      return order.deliveryUser!.trim();
    }
    return 'مندوب التوصيل';
  }

  String _toArabicNumerals(int? number) {
    if (number == null) return '';
    const englishToArabic = {
      '0': '٠',
      '1': '١',
      '2': '٢',
      '3': '٣',
      '4': '٤',
      '5': '٥',
      '6': '٦',
      '7': '٧',
      '8': '٨',
      '9': '٩',
    };
    return number
        .toString()
        .split('')
        .map((d) => englishToArabic[d] ?? d)
        .join('');
  }

  LatLng _resolveClientCoordinates(OrderModel order) {
    if (order.lat != null && order.lng != null && order.lat != 0 && order.lng != 0) {
      return LatLng(order.lat!.toDouble(), order.lng!.toDouble());
    }
    final mainAddress = locator<AppParametersProvider>().mainAddressService.mainAddress;
    if (mainAddress.lat != null && mainAddress.lng != null && mainAddress.lat != 0 && mainAddress.lng != 0) {
      return LatLng(mainAddress.lat!.toDouble(), mainAddress.lng!.toDouble());
    }
    return const LatLng(30.0444, 31.2357);
  }

  void _callDriver(BuildContext context, OrderModel order) async {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    final phone = (order.deliveryUserPhone?.trim().isNotEmpty == true)
        ? order.deliveryUserPhone!.trim()
        : provider.liveTrack?.driverPhoneNumber?.trim();

    if (phone == null || phone.isEmpty) {
      if (context.mounted) {
        final driverName = order.deliveryUser ?? 'المندوب';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'رقم هاتف $driverName غير متوفر حالياً',
              style: GoogleFonts.ibmPlexSansArabic(),
            ),
            backgroundColor: kPrimaryOrange,
          ),
        );
      }
      return;
    }

    // Clean phone number (keep digits and leading plus)
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri);
      }
    } catch (_) {
      try {
        await launchUrl(uri);
      } catch (e) {
        if (context.mounted) {
          final driverName = order.deliveryUser ?? 'المندوب';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تعذر فتح تطبيق الهاتف للاتصال بـ $driverName ($cleanPhone)',
                style: GoogleFonts.ibmPlexSansArabic(),
              ),
              backgroundColor: kPrimaryOrange,
            ),
          );
        }
      }
    }
  }
}
