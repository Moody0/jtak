import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/catalog/favorite_product_provider.dart';
import '../../../utils/custom_widgets/messages.dart';
import '../../../utils/custom_widgets/shimmer.dart';

/// ---------------------------------------------------------------------------
/// JTAK Restaurant Card Component (Exact Match to Reference Mockup with PhosphorIcons)
///
/// Features:
/// - 20px rounded container with distinct grey outline border (#E2E8F0, 1.5px)
/// - Cover photo with:
///   * Floating Merchant Logo at the BOTTOM-RIGHT (50x50 with 14px radius)
///   * Floating Distance Pill at the BOTTOM-LEFT (📍 5.8 كم)
/// - Spacious info body with large bold Arabic typography (17.5px name, 14px categories)
/// - Large Rating (15px) & ETA (14px) row
/// - Delivery fee pill with car icon and bold price
/// ---------------------------------------------------------------------------

class RestaurantItemData {
  final int id;
  final String name;
  final String coverUrl;
  final String logoUrl;
  final String category;
  final double rating;
  final int ratingCount;
  final String eta;
  final String distance;
  final String deliveryFee;
  final bool isVerified;
  final bool isOpen;

  const RestaurantItemData({
    required this.id,
    required this.name,
    required this.coverUrl,
    required this.logoUrl,
    required this.category,
    required this.rating,
    required this.ratingCount,
    required this.eta,
    required this.distance,
    required this.deliveryFee,
    this.isVerified = true,
    this.isOpen = true,
  });
}

class JtakRestaurantCard extends StatelessWidget {
  final RestaurantItemData data;
  final VoidCallback? onTap;
  final double width;

  const JtakRestaurantCard({
    super.key,
    required this.data,
    this.onTap,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kCardBorderColor, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Cover Photo with Floating Merchant Logo on TOP-RIGHT (in RTL)
            _buildCoverWithLogo(context),

            // 2. Restaurant Info Body (Enlarged Premium Typography & Breathing Room)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Row 1: Restaurant Name (Right in RTL) + Prime Badge (Left in RTL)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Name (20px bold authority)
                      Expanded(
                        child: Text(
                          data.name,
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: kCharcoalDark,
                            fontSize: 20.0,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Verified Badge (Consistent flipped sealCheck)
                      if (data.isVerified) ...[
                        const SizedBox(width: 6),
                        Transform.flip(
                          flipX: true,
                          child: const Icon(
                            PhosphorIconsFill.sealCheck,
                            color: kPrimaryOrange,
                            size: 20,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 5),

                  // Row 2: Cuisine Subtitle (Right in RTL) + Delivery Fee Pill (Left in RTL)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Cuisine
                      Expanded(
                        child: Text(
                          data.category,
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: const Color(0xFF4B5563),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Delivery Fee Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              data.deliveryFee,
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: kCharcoalDark,
                                fontSize: 13.0,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Icon(
                              PhosphorIconsFill.motorcycle,
                              color: kPrimaryOrange,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Row 3: Bottom Metadata Row (Rating • Time • Distance)
                  Row(
                    children: [
                      // Rating ⭐ 4.3 (229)
                      const Icon(
                        PhosphorIconsFill.star,
                        color: Color(0xFFFFB800),
                        size: 18,
                      ),
                      const SizedBox(width: 3.5),
                      Text(
                        '${data.rating}',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: kCharcoalDark,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 3.5),
                      Text(
                        '(${data.ratingCount})',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: const Color(0xFF6B7280),
                          fontSize: 13.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(width: 8),
                      Text(
                        '•',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      ),
                      const SizedBox(width: 8),

                      // ETA 🕒 30-40 دقيقة
                      const Icon(
                        PhosphorIconsRegular.clock,
                        color: Color(0xFF6B7280),
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        data.eta,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: const Color(0xFF374151),
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(width: 8),
                      Text(
                        '•',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      ),
                      const SizedBox(width: 8),

                      // Distance 📍 7 كم
                      const Icon(
                        PhosphorIconsRegular.mapPin,
                        color: Color(0xFF6B7280),
                        size: 16,
                      ),
                      const SizedBox(width: 3.5),
                      Text(
                        data.distance,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: const Color(0xFF374151),
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverWithLogo(BuildContext context) {
    return SizedBox(
      height: 135,
      width: double.infinity,
      child: Stack(
        children: [
          // 1. Cover Image with Full Border Radius (Top and Bottom Rounded)
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: data.coverUrl.isNotEmpty
                ? (data.coverUrl.startsWith('assets')
                    ? Image.asset(
                        data.coverUrl,
                        width: double.infinity,
                        height: 135,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildFallbackCover(),
                      )
                    : CachedNetworkImage(
                        imageUrl: data.coverUrl,
                        width: double.infinity,
                        height: 135,
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 220),
                        fadeOutDuration: const Duration(milliseconds: 150),
                        placeholder: (_, __) => Shimmer.fromColors(
                          baseColor: const Color(0xFFF1F5F9),
                          highlightColor: const Color(0xFFF8FAFC),
                          child: Container(
                            width: double.infinity,
                            height: 135,
                            color: const Color(0xFFF1F5F9),
                          ),
                        ),
                        errorWidget: (_, __, ___) => _buildFallbackCover(),
                      ))
                : _buildFallbackCover(),
          ),

          // 2. Floating Merchant Logo (Top-Right in RTL - 72x72 with Crisp White Border)
          Positioned(
            top: 10,
            right: 12,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white, width: 2.0),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: data.logoUrl.isNotEmpty
                      ? (data.logoUrl.startsWith('assets')
                          ? Image.asset(
                              data.logoUrl,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildFallbackLogo(),
                            )
                          : CachedNetworkImage(
                              imageUrl: data.logoUrl,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              fadeInDuration: const Duration(milliseconds: 220),
                              fadeOutDuration: const Duration(milliseconds: 150),
                              placeholder: (_, __) => Shimmer.fromColors(
                                baseColor: const Color(0xFFF1F5F9),
                                highlightColor: const Color(0xFFF8FAFC),
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  color: const Color(0xFFF1F5F9),
                                ),
                              ),
                              errorWidget: (_, __, ___) => _buildFallbackLogo(),
                            ))
                      : _buildFallbackLogo(),
                ),
              ),
            ),
          ),

          // 3. Floating Favorite Button (Top-Left in RTL - Clean hairline border, no slop shadow)
          Positioned(
            top: 10,
            left: 12,
            child: Consumer<FavoriteProductProvider>(
              builder: (context, favProvider, _) {
                final isFav = favProvider.isRestaurantFavorite(data.id);
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    favProvider.toggleRestaurantFavorite(data.id);
                    SnackBarWidget.showCustomSnackBar(
                      context,
                      isFav
                          ? 'تمت الإزالة من المفضلة'
                          : 'تمت إضافة ${data.name} إلى المفضلة ❤️',
                      backgroundColor: const Color(0xFF1E293B),
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                    ),
                    child: Center(
                      child: Icon(
                        isFav
                            ? PhosphorIconsFill.heart
                            : PhosphorIconsRegular.heart,
                        color: isFav
                            ? const Color(0xFFEF4444)
                            : kCharcoalDark,
                        size: 19,
                      ),
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

  Widget _buildFallbackCover() {
    return Container(
      color: const Color(0xFFF3F4F6),
      child: const Center(
        child: Icon(Icons.restaurant_rounded, color: Color(0xFFCBD5E1), size: 42),
      ),
    );
  }

  Widget _buildFallbackLogo() {
    return Container(
      color: kSurfaceWarm,
      child: Center(
        child: Text(
          data.name.isNotEmpty ? data.name[0] : 'J',
          style: GoogleFonts.ibmPlexSansArabic(
            color: kPrimaryOrange,
            fontWeight: FontWeight.w900,
            fontSize: 30,
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// JTAK Home Page Restaurant Card (Compact Horizontal Carousel Design)
///
/// Exact Match to Home Screen Reference:
/// - Floating Logo on BOTTOM-RIGHT (54x54)
/// - Floating Distance Badge on BOTTOM-LEFT (📍 5.8 كم)
/// - Verified Checkmark next to Restaurant Name
/// - Rating + ETA row (without distance overflow)
/// - Delivery Fee Pill on Bottom-Left
/// ---------------------------------------------------------------------------
class JtakHomeRestaurantCard extends StatelessWidget {
  final RestaurantItemData data;
  final VoidCallback? onTap;
  final double width;

  const JtakHomeRestaurantCard({
    super.key,
    required this.data,
    this.onTap,
    this.width = 250,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kCardBorderColor, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Cover Photo with Bottom-Right Logo and Bottom-Left Distance Badge
            _buildCoverWithBadges(context),

            // 2. Restaurant Info Body
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Row 1: Restaurant Name + Verified Red Badge (Directly adjacent to name)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          data.name,
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: kCharcoalDark,
                            fontSize: 17.0,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (data.isVerified) ...[
                        const SizedBox(width: 5),
                        Transform.flip(
                          flipX: true,
                          child: const Icon(
                            PhosphorIconsFill.sealCheck,
                            color: kPrimaryOrange,
                            size: 18,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 3),

                  // Row 2: Cuisine / Category Subtitle
                  Text(
                    data.category,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: const Color(0xFF6B7280),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // Row 3: Rating & ETA Row (RTL format, comfortably fits without overflow)
                  Row(
                    children: [
                      const Icon(
                        PhosphorIconsFill.star,
                        color: Color(0xFFFFB800),
                        size: 18,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${data.rating}',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: kCharcoalDark,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '(${data.ratingCount})',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: const Color(0xFF6B7280),
                          fontSize: 12.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '•',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        PhosphorIconsRegular.clock,
                        color: Color(0xFF6B7280),
                        size: 14,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        data.eta,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: const Color(0xFF4B5563),
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Row 4: Delivery Fee Pill on the Right (Icon on the Right in RTL)
                  SizedBox(
                    width: double.infinity,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              PhosphorIconsFill.motorcycle,
                              color: kPrimaryOrange,
                              size: 15,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              data.deliveryFee,
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: kCharcoalDark,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
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
          ],
        ),
      ),
    );
  }

  Widget _buildCoverWithBadges(BuildContext context) {
    return SizedBox(
      height: 130,
      width: double.infinity,
      child: Stack(
        children: [
          // 1. Cover Image with 17px Rounded Corners
          ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: data.coverUrl.isNotEmpty
                ? (data.coverUrl.startsWith('assets')
                    ? Image.asset(
                        data.coverUrl,
                        width: double.infinity,
                        height: 130,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildFallbackCover(),
                      )
                    : CachedNetworkImage(
                        imageUrl: data.coverUrl,
                        width: double.infinity,
                        height: 130,
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 220),
                        fadeOutDuration: const Duration(milliseconds: 150),
                        placeholder: (_, __) => Shimmer.fromColors(
                          baseColor: const Color(0xFFF1F5F9),
                          highlightColor: const Color(0xFFF8FAFC),
                          child: Container(
                            width: double.infinity,
                            height: 130,
                            color: const Color(0xFFF1F5F9),
                          ),
                        ),
                        errorWidget: (_, __, ___) => _buildFallbackCover(),
                      ))
                : _buildFallbackCover(),
          ),

          // 2. Floating Merchant Logo (Bottom-Right in RTL - 52x52 with Crisp White Border)
          Positioned(
            bottom: 8,
            right: 10,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white, width: 2.0),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: data.logoUrl.isNotEmpty
                      ? (data.logoUrl.startsWith('assets')
                          ? Image.asset(
                              data.logoUrl,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildFallbackLogo(),
                            )
                          : CachedNetworkImage(
                              imageUrl: data.logoUrl,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              fadeInDuration: const Duration(milliseconds: 220),
                              fadeOutDuration: const Duration(milliseconds: 150),
                              placeholder: (_, __) => Shimmer.fromColors(
                                baseColor: const Color(0xFFF1F5F9),
                                highlightColor: const Color(0xFFF8FAFC),
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  color: const Color(0xFFF1F5F9),
                                ),
                              ),
                              errorWidget: (_, __, ___) => _buildFallbackLogo(),
                            ))
                      : _buildFallbackLogo(),
                ),
              ),
            ),
          ),

          // 3. Floating Distance Badge (Bottom-Left in RTL - Crisp clean badge)
          Positioned(
            bottom: 8,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    PhosphorIconsRegular.mapPin,
                    color: kPrimaryOrange,
                    size: 13,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    data.distance,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: kCharcoalDark,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
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

  Widget _buildFallbackCover() {
    return Container(
      color: const Color(0xFFF3F4F6),
      child: const Center(
        child: Icon(Icons.restaurant_rounded, color: Color(0xFFCBD5E1), size: 40),
      ),
    );
  }

  Widget _buildFallbackLogo() {
    return Container(
      color: kSurfaceWarm,
      child: Center(
        child: Text(
          data.name.isNotEmpty ? data.name[0] : 'J',
          style: GoogleFonts.ibmPlexSansArabic(
            color: kPrimaryOrange,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
      ),
    );
  }
}
