import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/catalog/favorite_product_provider.dart';
import '../../../core/data/mock_catalog_data.dart';
import '../../widgets/catalog/item_customization_sheet.dart';
import '../../widgets/header_circle_button.dart';

/// ---------------------------------------------------------------------------
/// JTAK Restaurant Menu Dedicated Search Page
///
/// Features:
/// - Top Search Bar with back action, RTL search input with orange cursor,
///   "بحث في القائمة" placeholder, and instant clear (✕) button
/// - Search results displayed as clean horizontal menu dish rows (Screenshot 1)
/// - Custom pixel-perfect "لم نعثر على ما طلبت" empty state illustration (Screenshot 2)
/// - Instant tapping to open ItemCustomizationBottomSheet
/// ---------------------------------------------------------------------------

class RestaurantMenuSearchPage extends StatefulWidget {
  static const String routeName = '/RestaurantMenuSearchPage';

  final MockRestaurantData restaurantData;

  const RestaurantMenuSearchPage({
    super.key,
    required this.restaurantData,
  });

  @override
  State<RestaurantMenuSearchPage> createState() =>
      _RestaurantMenuSearchPageState();
}

class _RestaurantMenuSearchPageState extends State<RestaurantMenuSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field upon opening
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<MockMenuItemData> get _filteredItems {
    final items = widget.restaurantData.menuItems;
    if (_searchQuery.isEmpty) {
      return items;
    }
    final q = _searchQuery.toLowerCase();
    return items.where((item) {
      return item.title.toLowerCase().contains(q) ||
          item.description.toLowerCase().contains(q) ||
          item.category.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // 1. Top Navigation & Search Bar
            _buildTopSearchBar(context),

            const Divider(color: Color(0xFFF3F4F6), height: 1, thickness: 1),

            // 2. Search Results List or Empty State
            Expanded(
              child: filteredItems.isEmpty
                  ? _buildEmptyState()
                  : _buildResultsList(filteredItems),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top App Bar & Search Pill
  // ---------------------------------------------------------------------------
  Widget _buildTopSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          // Back Button (on the RIGHT in RTL)
          GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
              ),
              child: const Center(
                child: JtakBackIcon(size: 20),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Search Field Pill
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const JtakSearchIcon(
                    color: Color(0xFF6B7280),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      cursorColor: kPrimaryOrange,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: kCharcoalDark,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'بحث في القائمة',
                        hintStyle: GoogleFonts.ibmPlexSansArabic(
                          color: const Color(0xFF9CA3AF),
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                        });
                      },
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.close_rounded,
                          color: Color(0xFF1F2937),
                          size: 19,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Results List View (Exact Match to Screenshot 1)
  // ---------------------------------------------------------------------------
  Widget _buildResultsList(List<MockMenuItemData> items) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      physics: const ClampingScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(
        color: Color(0xFFF3F4F6),
        height: 1,
        thickness: 1,
      ),
      itemBuilder: (context, index) {
        final item = items[index];

        return InkWell(
          onTap: () {
            ItemCustomizationBottomSheet.show(
              context,
              item: item,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Column (Title, Description, Price) - Right side in RTL
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: kCharcoalDark,
                          fontSize: 16.0,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: const Color(0xFF6B7280),
                          fontSize: 13.0,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.price,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: kCharcoalDark,
                          fontSize: 15.0,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 14),

                // Food Image Box - Left side in RTL
                Stack(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: (item.imageUrl.isNotEmpty)
                            ? (item.imageUrl.startsWith('assets')
                                ? Image.asset(
                                    item.imageUrl,
                                    width: 96,
                                    height: 96,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(
                                        Icons.restaurant_rounded,
                                        color: kPrimaryOrange,
                                        size: 36,
                                      ),
                                    ),
                                  )
                                : CachedNetworkImage(
                                    imageUrl: item.imageUrl,
                                    width: 96,
                                    height: 96,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => const Center(
                                      child: Icon(
                                        Icons.restaurant_rounded,
                                        color: kPrimaryOrange,
                                        size: 36,
                                      ),
                                    ),
                                  ))
                            : const Center(
                                child: Icon(
                                  Icons.restaurant_rounded,
                                  color: kPrimaryOrange,
                                  size: 36,
                                ),
                              ),
                      ),
                    ),

                    // Top-Left Favorite Button
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Consumer<FavoriteProductProvider>(
                        builder: (context, favProvider, _) {
                          final isFav = favProvider.isMealFavorite(item.id);
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              favProvider.toggleMealFavorite(item.id, item);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                              ),
                              child: Center(
                                child: Icon(
                                  isFav ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
                                  color: isFav ? const Color(0xFFEF4444) : const Color(0xFF6B7280),
                                  size: 14,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Empty State View (Exact Match to Screenshot 2)
  // ---------------------------------------------------------------------------
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Custom Painted Empty State Illustration (Magnifier + "!" + Orange Accent Lines)
            const _SearchNotFoundIllustration(),

            const SizedBox(height: 26),

            // Heading: "لم نعثر على ما طلبت"
            Text(
              'لم نعثر على ما طلبت',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                color: kCharcoalDark,
                fontSize: 21.0,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),

            const SizedBox(height: 8),

            // Subtitle: "هلاً بحثت عن طلبك بكلمات أخرى أو ربما كتبت حرفًا زائدًا"
            Text(
              'هلاً بحثت عن طلبك بكلمات أخرى أو ربما كتبت حرفًا زائدًا',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                color: const Color(0xFF6B7280),
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Custom Painter for Search Not Found Illustration (Matches Reference Mockup)
/// ---------------------------------------------------------------------------
class _SearchNotFoundIllustration extends StatelessWidget {
  const _SearchNotFoundIllustration();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(140, 140),
      painter: _SearchNotFoundPainter(),
    );
  }
}

class _SearchNotFoundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.56, size.height * 0.44);
    final radius = size.width * 0.26;

    final darkPaint = Paint()
      ..color = const Color(0xFF351717)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round;

    final darkFillPaint = Paint()
      ..color = const Color(0xFF351717)
      ..style = PaintingStyle.fill;

    final orangeHandlePaint = Paint()
      ..color = const Color(0xFFFF5400)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14.0
      ..strokeCap = StrokeCap.round;

    final orangeRayPaint = Paint()
      ..color = const Color(0xFFFF5400)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round;

    // 1. Orange Handle pointing down-left at 45 degrees
    final handleStart = center + const Offset(-18, 18);
    final handleEnd = handleStart + const Offset(-24, 24);
    canvas.drawLine(handleStart, handleEnd, orangeHandlePaint);

    // 2. Dark Circular Rim
    canvas.drawCircle(center, radius, darkPaint);

    // 3. Exclamation Point "!" inside circle
    // Upper vertical stroke
    canvas.drawLine(
      center + const Offset(0, -13),
      center + const Offset(0, 3),
      Paint()
        ..color = const Color(0xFF351717)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7.5
        ..strokeCap = StrokeCap.round,
    );
    // Lower dot
    canvas.drawCircle(center + const Offset(0, 14), 3.8, darkFillPaint);

    // 4. Two Orange Alert Rays at top-left
    // Top-left ray 1
    canvas.drawLine(
      Offset(size.width * 0.32, size.height * 0.21),
      Offset(size.width * 0.39, size.height * 0.28),
      orangeRayPaint,
    );
    // Left ray 2
    canvas.drawLine(
      Offset(size.width * 0.22, size.height * 0.39),
      Offset(size.width * 0.30, size.height * 0.40),
      orangeRayPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
