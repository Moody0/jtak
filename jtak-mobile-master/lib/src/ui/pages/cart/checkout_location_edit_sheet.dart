import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/user/address_provider.dart';
import '../../../core/models/user/address_model.dart';
import '../../../core/services/location_service.dart';
import '../../../utils/custom_widgets/syrian_flag.dart';
import '../../../utils/utilities/phone_helper.dart';
import '../../widgets/header_circle_button.dart';
import '../address/choose_location_map_page.dart';
import '../address/search_address_page.dart';

/// ---------------------------------------------------------------------------
/// Dedicated Map Picker for Checkout
/// ---------------------------------------------------------------------------
class CheckoutMapPickerPage extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const CheckoutMapPickerPage({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<CheckoutMapPickerPage> createState() => _CheckoutMapPickerPageState();
}

class _CheckoutMapPickerPageState extends State<CheckoutMapPickerPage> {
  @override
  void initState() {
    super.initState();
    final prov = Provider.of<AddressProvider>(context, listen: false);
    if (widget.initialLat != null && widget.initialLng != null) {
      prov.cameraPosition = LatLng(widget.initialLat!, widget.initialLng!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      prov.resolveAddressName(
        prov.cameraPosition.latitude,
        prov.cameraPosition.longitude,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<AddressProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Center(
          child: HeaderCircleButton.back(
            onTap: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          'تحديد الموقع على الخريطة',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: kCharcoalDark,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchAddressPage(),
                ),
              );
              if (result is Map<String, dynamic> && context.mounted) {
                final double? lat = (result['lat'] as num?)?.toDouble();
                final double? lon = (result['lon'] as num?)?.toDouble();
                if (lat != null && lon != null && lat != 0.0 && lon != 0.0) {
                  prov.mapAnimateToPosision(LatLng(lat, lon));
                }
              }
            },
            icon: const Icon(
              PhosphorIconsRegular.magnifyingGlass,
              color: kCharcoalDark,
              size: 22,
            ),
            tooltip: 'بحث عن عنوان أو حي',
          ),
          const SizedBox(width: 6),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF1F5F9), thickness: 1),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Map Widget
            const Positioned.fill(
              child: ChooseLocationMapPage(),
            ),

            // Bottom Confirmation Floating Card
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0E8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(
                              PhosphorIconsFill.mapPin,
                              color: kPrimaryOrange,
                              size: 22,
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
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                prov.isGeocodingLocation
                                    ? 'جارٍ قراءة العنوان بدقة...'
                                    : (prov.locationAddressName?.isNotEmpty == true
                                        ? prov.locationAddressName!
                                        : 'حرّك الخريطة لتحديد موقع التوصيل بدقة'),
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: kCharcoalDark,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        final lat = prov.cameraPosition.latitude;
                        final lng = prov.cameraPosition.longitude;
                        final address = prov.locationAddressName ?? 'الموقع المحدد على الخريطة';
                        Navigator.pop(context, {
                          'lat': lat,
                          'lng': lng,
                          'address': address,
                        });
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: kPrimaryOrange,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                PhosphorIconsFill.checkCircle,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'تأكيد هذا الموقع للتوصيل',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
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
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Modern Checkout Location Edit Bottom Sheet
/// ---------------------------------------------------------------------------
class CheckoutLocationEditSheet extends StatefulWidget {
  final String initialAddress;
  final String initialPhone;
  final double? currentLat;
  final double? currentLng;
  final Function(String newAddress, double? newLat, double? newLng, String? newPhone) onSave;

  const CheckoutLocationEditSheet({
    super.key,
    required this.initialAddress,
    required this.initialPhone,
    this.currentLat,
    this.currentLng,
    required this.onSave,
  });

  @override
  State<CheckoutLocationEditSheet> createState() => _CheckoutLocationEditSheetState();
}

class _CheckoutLocationEditSheetState extends State<CheckoutLocationEditSheet> {
  late TextEditingController _addressController;
  late TextEditingController _notesController;
  late TextEditingController _phoneController;

  double? _selectedLat;
  double? _selectedLng;
  bool _isLocatingGps = false;

  @override
  void initState() {
    super.initState();
    String baseAddress = widget.initialAddress;
    String extraNotes = '';

    // Check if initial address already has notes in parentheses, e.g. "حمص، المحطة (بناء 2)"
    final match = RegExp(r'^(.*?)\s*\((.*?)\)\s*$').firstMatch(baseAddress);
    if (match != null) {
      baseAddress = match.group(1)?.trim() ?? baseAddress;
      extraNotes = match.group(2)?.trim() ?? '';
    }

    _addressController = TextEditingController(text: baseAddress);
    _notesController = TextEditingController(text: extraNotes);

    final cleanPhone = PhoneHelper.normalizeSyrianLocalPhone(widget.initialPhone);
    _phoneController = TextEditingController(text: cleanPhone);

    _selectedLat = widget.currentLat;
    _selectedLng = widget.currentLng;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<AddressProvider>(context, listen: false).loadData();
      }
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchGpsLocation() async {
    setState(() => _isLocatingGps = true);
    HapticFeedback.selectionClick();
    try {
      final LatLng? gpsLoc = await LocationService().getCurrentLocation();
      if (gpsLoc != null) {
        _selectedLat = gpsLoc.latitude;
        _selectedLng = gpsLoc.longitude;
        final String revAddress = await LocationService.reverseGeocodeCoordinates(
          gpsLoc.latitude,
          gpsLoc.longitude,
        );
        if (mounted) {
          _addressController.text = revAddress;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLocatingGps = false);
    }
  }

  Future<void> _pickOnMap() async {
    HapticFeedback.selectionClick();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutMapPickerPage(
          initialLat: _selectedLat,
          initialLng: _selectedLng,
        ),
      ),
    );
    if (result is Map<String, dynamic> && mounted) {
      final double? lat = (result['lat'] as num?)?.toDouble();
      final double? lng = (result['lng'] as num?)?.toDouble();
      final String? address = result['address'] as String?;
      setState(() {
        if (lat != null && lng != null) {
          _selectedLat = lat;
          _selectedLng = lng;
        }
        if (address != null && address.isNotEmpty) {
          _addressController.text = address;
        }
      });
    }
  }

  Future<void> _searchPlace() async {
    HapticFeedback.selectionClick();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SearchAddressPage(),
      ),
    );
    if (result is Map<String, dynamic> && mounted) {
      final double? lat = (result['lat'] as num?)?.toDouble();
      final double? lon = (result['lon'] as num?)?.toDouble();
      final String? name = result['display_name'] ?? result['name'];
      setState(() {
        if (lat != null && lon != null) {
          _selectedLat = lat;
          _selectedLng = lon;
        }
        if (name != null && name.isNotEmpty) {
          _addressController.text = name;
        }
      });
    }
  }

  void _selectSavedAddress(AddressModel item) {
    HapticFeedback.selectionClick();
    final String chosen = (item.fullAddress?.isNotEmpty == true)
        ? item.fullAddress!
        : (item.title?.isNotEmpty == true ? item.title! : '');
    setState(() {
      if (chosen.isNotEmpty) {
        _addressController.text = chosen;
      }
      if (item.lat != null && item.lng != null) {
        _selectedLat = item.lat;
        _selectedLng = item.lng;
      }
      if (item.phoneNumber?.isNotEmpty == true) {
        _phoneController.text = PhoneHelper.normalizeSyrianLocalPhone(item.phoneNumber);
      }
    });
  }

  void _confirmAndSave() {
    final addr = _addressController.text.trim();
    if (addr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يرجى إدخال أو تحديد عنوان التوصيل',
            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    final notes = _notesController.text.trim();
    final String fullAddress = notes.isNotEmpty ? '$addr ($notes)' : addr;
    final phone = PhoneHelper.normalizeSyrianLocalPhone(_phoneController.text);

    HapticFeedback.mediumImpact();
    widget.onSave(fullAddress, _selectedLat, _selectedLng, phone);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final addressProvider = Provider.of<AddressProvider>(context);
    final savedAddresses = addressProvider.dataList
        .where((a) => a.id != null && a.id != 0)
        .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Drag Handle
                Center(
                  child: Container(
                    width: 38,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'تعديل موقع وعنوان التوصيل',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: kCharcoalDark,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            PhosphorIconsRegular.x,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'حدد أو عدّل مكان استلام الطلب لضمان وصول المندوب لباب منزلك بدقة',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Quick Action Cards (GPS / Map / Search)
                Row(
                  children: [
                    // GPS
                    Expanded(
                      child: _buildActionTile(
                        icon: PhosphorIconsFill.navigationArrow,
                        title: 'موقعي (GPS)',
                        subtitle: 'تحديد فوري',
                        iconBg: const Color(0xFFDCFCE7),
                        iconColor: const Color(0xFF16A34A),
                        isLoading: _isLocatingGps,
                        onTap: _isLocatingGps ? null : _fetchGpsLocation,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Map Picker
                    Expanded(
                      child: _buildActionTile(
                        icon: PhosphorIconsFill.mapTrifold,
                        title: 'الخريطة',
                        subtitle: 'سحب الدبوس',
                        iconBg: const Color(0xFFFFF0E8),
                        iconColor: kPrimaryOrange,
                        onTap: _pickOnMap,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Search
                    Expanded(
                      child: _buildActionTile(
                        icon: PhosphorIconsFill.magnifyingGlass,
                        title: 'بحث الأماكن',
                        subtitle: 'بالاسم والحي',
                        iconBg: const Color(0xFFEFF6FF),
                        iconColor: const Color(0xFF2563EB),
                        onTap: _searchPlace,
                      ),
                    ),
                  ],
                ),

                // 4. Saved Addresses Chips (if available)
                if (savedAddresses.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'العناوين المحفوظة',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: savedAddresses.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final item = savedAddresses[index];
                        final String title = item.title?.isNotEmpty == true ? item.title! : 'عنوان محفوظ';
                        return InkWell(
                          onTap: () => _selectSavedAddress(item),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(PhosphorIconsFill.bookmarkSimple, size: 14, color: kPrimaryOrange),
                                const SizedBox(width: 6),
                                Text(
                                  title,
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: kCharcoalDark,
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

                const SizedBox(height: 18),

                // 5. Input Fields
                // Field 1: Main Address
                Text(
                  'العنوان والشارع الرئيسي',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _addressController,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kCharcoalDark,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(PhosphorIconsFill.mapPin, color: kPrimaryOrange, size: 20),
                    hintText: 'مثال: حمص، حي الإنشاءات، شارع العروبة',
                    hintStyle: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12.5,
                      color: const Color(0xFF94A3B8),
                    ),
                    suffixIcon: _addressController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(PhosphorIconsRegular.xCircle, color: Color(0xFF94A3B8), size: 18),
                            onPressed: () => setState(() => _addressController.clear()),
                          )
                        : null,
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
                ),
                const SizedBox(height: 14),

                // Field 2: Building / Notes
                Text(
                  'تفاصيل إضافية للمندوب (اختياري)',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesController,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: kCharcoalDark,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(PhosphorIconsRegular.buildings, color: Color(0xFF64748B), size: 20),
                    hintText: 'مثال: بناء النور، طابق 2، شقة 4، بجانب سوبرماركت...',
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
                ),
                const SizedBox(height: 14),

                // Field 3: Recipient Phone
                Text(
                  'رقم هاتف المستلم للتوصيل',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  inputFormatters: [
                    SyrianPhoneInputFormatter(),
                  ],
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kCharcoalDark,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SyrianFlag(width: 20, height: 13, borderRadius: 2),
                          SizedBox(width: 6),
                          Text(
                            '+963',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                    hintText: '980 906 630',
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
                ),
                const SizedBox(height: 22),

                // 6. Confirm CTA
                GestureDetector(
                  onTap: _confirmAndSave,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: kPrimaryOrange,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33FF5400),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          PhosphorIconsFill.checkCircle,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'تأكيد وحفظ موقع التوصيل',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 15.5,
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
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconBg,
    required Color iconColor,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(kPrimaryOrange)),
                      )
                    : Icon(icon, color: iconColor, size: 18),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: kCharcoalDark,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF94A3B8),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
