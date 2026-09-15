import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/app_parameters_provider.dart';
import '../../../core/controllers/catalog/markets_provider.dart';
import '../../../core/controllers/order/cart_provider.dart';
import '../../../core/models/user/address_model.dart';
import '../../../core/services/locator.dart';
import '../../../utils/custom_widgets/image_widgets.dart';
import '../../widgets/clean_shimmer_skeletons.dart';
import '../../widgets/header_circle_button.dart';
import '../../widgets/top_app_bar_widget.dart';
import '../cart/cart_page.dart';
import 'catalog_scope.dart';
import 'market_page.dart';
import 'search_page.dart';

class ProductMarketplacePage extends StatefulWidget {
  final CatalogScope scope;

  const ProductMarketplacePage({
    super.key,
    required this.scope,
  });

  @override
  State<ProductMarketplacePage> createState() => _ProductMarketplacePageState();
}

class _ProductMarketplacePageState extends State<ProductMarketplacePage> {
  final Map<int, Set<String>> _merchantCategories = {};
  final Map<String, String?> _categoryImages = {};
  final Set<int> _merchantsWithOffers = {};
  List<MarketStoreModel> _merchants = const [];
  String _selectedCategory = 'الكل';
  bool _offersOnly = false;
  bool _underThirtyMinutes = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!locator.isRegistered<MarketsProvider>()) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final provider = locator<MarketsProvider>();
    var merchants = await provider.fetchMerchantsForCategory(
      widget.scope.categoryId,
      widget.scope.merchantKind,
    );

    // Compatibility while the new typed endpoint is being deployed. This
    // fallback is intentionally strict and never mixes another merchant type.
    if (merchants.isEmpty) {
      merchants = _legacyTypedFallback(provider);
    }

    // Show the typed merchant list immediately. Product requests only enrich
    // the department tabs and offer filters in the background.
    if (mounted) {
      setState(() {
        _merchants = merchants;
        _loading = false;
      });
    }

    await Future.wait(merchants.map((merchant) async {
      final products = await provider.fetchMarketProducts(merchant.id);
      final categories = <String>{};
      for (final product in products) {
        final parentId = int.tryParse(
          (product['categoryParentId'] ?? '').toString(),
        );
        final parentTitle = (product['productCat2'] ?? '').toString().trim();
        if (parentId != widget.scope.categoryId &&
            !_sameCategory(parentTitle, widget.scope.title)) {
          continue;
        }

        final childTitle = (product['productCat1'] ?? '').toString().trim();
        if (childTitle.isNotEmpty) {
          categories.add(childTitle);
          _categoryImages.putIfAbsent(
            childTitle,
            () => _firstImage(product),
          );
        }

        final discount = num.tryParse(
              (product['discount'] ?? 0).toString(),
            ) ??
            0;
        if (discount > 0) _merchantsWithOffers.add(merchant.id);
      }
      _merchantCategories[merchant.id] = categories;
    }));

    if (!mounted) return;
    setState(() {
      _merchants = merchants;
    });
  }

  bool _sameCategory(String first, String second) {
    String normalize(String value) => value
        .trim()
        .toLowerCase()
        .replaceFirst(RegExp(r'^ال'), '')
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');
    final a = normalize(first);
    final b = normalize(second);
    return a.isNotEmpty &&
        b.isNotEmpty &&
        (a == b || a.contains(b) || b.contains(a));
  }

  List<MarketStoreModel> _legacyTypedFallback(MarketsProvider provider) {
    return provider.markets;
  }

  String? _firstImage(Map<String, dynamic> product) {
    final icon = (product['categoryIcon'] ?? '').toString().trim();
    if (icon.isNotEmpty) return icon;
    final photos = (product['productPhotos'] ?? '').toString().trim();
    return photos.isEmpty ? null : photos.split(',').first.trim();
  }

  List<MarketStoreModel> get _visibleMerchants {
    return _merchants.where((merchant) {
      if (_selectedCategory != 'الكل') {
        final categories = _merchantCategories[merchant.id] ?? const <String>{};
        if (!categories.contains(_selectedCategory)) return false;
      }
      if (_offersOnly && !_merchantsWithOffers.contains(merchant.id)) {
        return false;
      }
      if (_underThirtyMinutes && _etaMinutes(merchant.eta) > 30) {
        return false;
      }
      return true;
    }).toList();
  }

  int _etaMinutes(String eta) {
    final values = RegExp(r'\d+').allMatches(eta).map((m) {
      return int.tryParse(m.group(0) ?? '') ?? 999;
    }).toList();
    return values.isEmpty ? 999 : values.first;
  }

  String _etaLabel(MarketStoreModel merchant) {
    final eta = merchant.eta.trim();
    if (eta.contains('دقيقة')) return eta;
    return '$eta دقيقة';
  }

  void _openMerchant(MarketStoreModel merchant) {
    final image = merchant.assetPath ?? merchant.logoUrl;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarketPage(
          marketId: merchant.id,
          marketName: merchant.name,
          coverUrl: image,
          logoUrl: image,
        ),
      ),
    );
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchPage(
          catalogScope: widget.scope,
          scopedMerchantIds: _merchants.map((merchant) => merchant.id).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildSearch()),
            SliverToBoxAdapter(child: _buildCategoryTabs()),
            SliverToBoxAdapter(child: _buildNearbySection()),
            SliverToBoxAdapter(child: _buildDiscoverHeader()),
            _buildMerchantList(),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final addressService = locator<AppParametersProvider>().mainAddressService;
    final AddressModel address = addressService.mainAddress;
    final addressTitle = address.title?.isNotEmpty == true
        ? address.title!
        : address.fullAddress?.isNotEmpty == true
            ? address.fullAddress!
            : 'House';
    final cartCount = locator<CartProvider>().totalQuantity;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          HeaderCircleButton.back(
              onTap: () => Navigator.pop(context), size: 40),
          const SizedBox(width: 10),
          Flexible(
            child: GestureDetector(
              onTap: () => showJtakAddressBottomSheet(context),
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'التوصيل الى ',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: kCharcoalDark,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      addressTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        color: kCharcoalDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Stack(
            clipBehavior: Clip.none,
            children: [
              HeaderCircleButton(
                size: 40,
                iconData: PhosphorIconsFill.bag,
                onTap: () => Navigator.pushNamed(context, CartPage.routeName),
              ),
              if (cartCount > 0)
                PositionedDirectional(
                  start: -4,
                  bottom: -2,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: kPrimaryOrange,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$cartCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: GestureDetector(
        onTap: _openSearch,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F6),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE2E4E8)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.scope.searchHint,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: const Color(0xFF6B7280),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const JtakSearchIcon(size: 21, color: Color(0xFF4B5563)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    final categoryNames = _categoryImages.keys.take(5).toList();
    return SizedBox(
      height: 125,
      child: ListView.separated(
        reverse: false,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categoryNames.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final title = isAll ? 'كل المتاجر' : categoryNames[index - 1];
          final image = isAll
              ? widget.scope.fallbackImage
              : _categoryImages[title] ?? widget.scope.fallbackImage;
          final selected =
              isAll ? _selectedCategory == 'الكل' : _selectedCategory == title;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedCategory = isAll ? 'الكل' : title;
            }),
            child: SizedBox(
              width: 82,
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF222222)
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: ClipOval(
                      child: ImageView(
                        image,
                        width: 66,
                        height: 66,
                        fit: BoxFit.contain,
                        showLoader: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: selected ? kCharcoalDark : const Color(0xFF60636A),
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: GoogleFonts.ibmPlexSansArabic(
          color: kCharcoalDark,
          // Match the established restaurant-list section scale. The product
          // marketplaces previously used a display-sized heading which made
          // grocery, pharmacy and stores feel visually heavier than Home.
          fontSize: 20,
          fontWeight: FontWeight.w900,
          height: 1.25,
        ),
      ),
    );
  }

  Widget _buildNearbySection() {
    final nearby = _visibleMerchants.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        _sectionTitle('المتاجر الكبرى بالقرب منك'),
        const SizedBox(height: 18),
        if (_loading)
          SizedBox(
            height: 145,
            child: CleanShimmer(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, __) => const SkeletonBox(
                  width: 110,
                  height: 145,
                  borderRadius: 16,
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: nearby.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final merchant = nearby[index];
                final image = merchant.assetPath ?? merchant.logoUrl;
                return GestureDetector(
                  onTap: () => _openMerchant(merchant),
                  child: SizedBox(
                    width: 104,
                    child: Column(
                      children: [
                        Container(
                          width: 104,
                          height: 104,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFE7E7E7)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: ImageView(
                              image,
                              width: 88,
                              height: 88,
                              fit: BoxFit.contain,
                              showLoader: false,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _etaLabel(merchant),
                          maxLines: 1,
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: const Color(0xFF737373),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
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
    );
  }

  Widget _buildDiscoverHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('اكتشف كل المتاجر'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _filterChip(
                'العروض',
                _offersOnly,
                () => setState(() => _offersOnly = !_offersOnly),
              ),
              _filterChip(
                'أقل من 30 دقيقة',
                _underThirtyMinutes,
                () => setState(
                  () => _underThirtyMinutes = !_underThirtyMinutes,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF1E8) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? kPrimaryOrange : const Color(0xFFD8DADD),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            color: selected ? kPrimaryOrange : kCharcoalDark,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildMerchantList() {
    final merchants = _visibleMerchants;
    if (_loading) return const SliverRestaurantsListSkeleton(count: 3);
    if (merchants.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 24),
          child: Text(
            widget.scope.emptyMerchantsMessage,
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansArabic(
              color: const Color(0xFF777B83),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final merchant = merchants[index];
            final image = merchant.assetPath ?? merchant.logoUrl;
            return InkWell(
              onTap: () => _openMerchant(merchant),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 92,
                        height: 92,
                        color: const Color(0xFFF7F7F7),
                        padding: const EdgeInsets.all(6),
                        child: ImageView(
                          image,
                          width: 80,
                          height: 80,
                          fit: BoxFit.contain,
                          showLoader: false,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  merchant.localizedName('ar'),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    color: kCharcoalDark,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              if (_merchantsWithOffers
                                  .contains(merchant.id)) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF9B28D7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'pro',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  PhosphorIconsRegular.caretDown,
                                  color: kCharcoalDark,
                                  size: 14,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _etaLabel(merchant),
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: const Color(0xFF4B4B4B),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: merchants.length,
        ),
      ),
    );
  }
}
