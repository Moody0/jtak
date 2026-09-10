import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../config/themes/colors.dart';
import '../../../core/services/location_service.dart';
import '../../widgets/clean_shimmer_skeletons.dart';
import '../../widgets/header_circle_button.dart';

class SearchAddressPage extends StatefulWidget {
  static const String routeName = '/SearchAddressPage';

  const SearchAddressPage({super.key});

  @override
  State<SearchAddressPage> createState() => _SearchAddressPageState();
}

class _SearchAddressPageState extends State<SearchAddressPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await LocationService.searchPlaces(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  void _confirmSelection(Map<String, dynamic> result) async {
    HapticFeedback.selectionClick();
    if (result.containsKey('place_id') && result['place_id'] != null && result['place_id'].toString().isNotEmpty) {
      final placeId = result['place_id'].toString();
      final latLng = await LocationService.getPlaceCoordinates(placeId);
      if (latLng != null) {
        result['lat'] = latLng.latitude;
        result['lon'] = latLng.longitude;
      }
    }
    if (mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: _searchResults.isNotEmpty
            ? _buildSearchResultsList()
            : (_isSearching
                ? _buildLoadingState()
                : const SizedBox.shrink()),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      leading: Center(
        child: HeaderCircleButton.back(
          onTap: () => Navigator.pop(context),
        ),
      ),
      titleSpacing: 0,
      title: Container(
        height: 44,
        margin: const EdgeInsetsDirectional.only(end: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: _onSearchChanged,
          textDirection: TextDirection.rtl,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: kCharcoalDark,
          ),
          decoration: InputDecoration(
            hintText: 'ابحث عن منطقة، حي، أو شارع...',
            hintStyle: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13,
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: const JtakSearchIcon(
              color: kPrimaryOrange,
              size: 22,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() {
                        _searchResults = [];
                      });
                    },
                    child: const Icon(
                      PhosphorIconsRegular.xCircle,
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          ),
        ),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFFF1F5F9), thickness: 1),
      ),
    );
  }

  Widget _buildLoadingState() {
    return CleanShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, __) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const SkeletonBox.circle(size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: 140, height: 14, borderRadius: 4),
                    SizedBox(height: 6),
                    SkeletonBox(width: 200, height: 11, borderRadius: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultsList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(
                  PhosphorIconsFill.mapPin,
                  color: kPrimaryOrange,
                  size: 20,
                  textDirection: TextDirection.ltr,
                ),
              ),
            ),
            title: Text(
              item['display_name'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: kCharcoalDark,
              ),
            ),
            trailing: const Icon(
              PhosphorIconsRegular.caretLeft,
              color: Color(0xFF94A3B8),
              size: 16,
              textDirection: TextDirection.ltr,
            ),
            onTap: () => _confirmSelection(item),
          ),
        );
      },
    );
  }
}
