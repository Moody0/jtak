import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/controllers/app/home_navigation_provider.dart';
import '../../../core/controllers/catalog/categories_provider.dart';
import '../../../core/controllers/catalog/category_products_provider.dart';
import '../../../core/models/catalog/category_model.dart';
import '../../../utils/custom_widgets/custom_scroll_behavior.dart';
import '../../widgets/header_circle_button.dart';
import 'category_products_widget.dart';
import 'search_page.dart';

class CategoriesPage extends StatefulWidget {
  static const String routeName = '/CategoryPage';
  final int initCategoryIndex;
  final String? categoryTitle;

  const CategoriesPage(this.initCategoryIndex, {super.key, this.categoryTitle});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  static const List<String> _defaultCategoryTitles = [
    'عروض',
    'الفطور',
    'أجبان وألبان',
    'خضراوات',
    'لحوم ودواجن',
    'حلويات',
    'مخبوزات',
    'بقوليات',
    'مونة',
  ];

  CategoryModel _resolveCategory(CategoriesProvider categoriesProvider) {
    if (widget.categoryTitle != null && widget.categoryTitle!.isNotEmpty) {
      final found = categoriesProvider.dataList.firstWhere(
        (c) => c.title == widget.categoryTitle,
        orElse: () => CategoryModel(
            id: widget.initCategoryIndex + 1, title: widget.categoryTitle),
      );
      return found;
    }

    if (categoriesProvider.dataList.isNotEmpty) {
      final safeIndex = widget.initCategoryIndex
          .clamp(0, categoriesProvider.dataList.length - 1);
      return categoriesProvider.dataList[safeIndex];
    }

    // Fallback from default list
    final safeDefaultIndex =
        widget.initCategoryIndex.clamp(0, _defaultCategoryTitles.length - 1);
    final title = _defaultCategoryTitles[safeDefaultIndex];
    return CategoryModel(id: safeDefaultIndex + 1, title: title);
  }

  String? _getCategoryAsset(String title) {
    final t = title.trim();
    if (t.contains('عروض') || t.toLowerCase().contains('offer')) {
      return 'assets/images/categories/offers.png';
    }
    if (t.contains('فطور') ||
        t.toLowerCase().contains('breakfast') ||
        t.contains('ترويقة')) {
      return 'assets/images/categories/breakfast.png';
    }
    if (t.contains('أجبان') ||
        t.contains('ألبان') ||
        t.contains('جبن') ||
        t.toLowerCase().contains('dairy')) {
      return 'assets/images/categories/dairy_cheese.png';
    }
    if (t.contains('خضراوات') ||
        t.contains('خضار') ||
        t.toLowerCase().contains('vegetable')) {
      return 'assets/images/categories/vegetables.png';
    }
    if (t.contains('لحوم') ||
        t.contains('دواجن') ||
        t.contains('دجاج') ||
        t.toLowerCase().contains('meat')) {
      return 'assets/images/categories/meat_poultry.png';
    }
    if (t.contains('حلويات') ||
        t.contains('حلو') ||
        t.toLowerCase().contains('sweet')) {
      return 'assets/images/categories/sweets_desserts.png';
    }
    if (t.contains('مخبوزات') ||
        t.contains('خبز') ||
        t.toLowerCase().contains('bakery')) {
      return 'assets/images/categories/bakery.png';
    }
    if (t.contains('بقوليات') ||
        t.contains('حبوب') ||
        t.toLowerCase().contains('legume')) {
      return 'assets/images/categories/legumes_grains.png';
    }
    if (t.contains('مونة') || t.toLowerCase().contains('mouneh')) {
      return 'assets/images/categories/mouneh.png';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final categoriesProvider = Provider.of<CategoriesProvider>(context);
    final selectedCategory = _resolveCategory(categoriesProvider);
    final title = selectedCategory.title ?? 'الأقسام';

    return ScrollConfiguration(
      behavior: CustomScrollBehavior(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: _buildAppBar(title, selectedCategory.id),
        body: SafeArea(
          child: ChangeNotifierProvider(
            key: ValueKey('category_provider_${selectedCategory.id}_$title'),
            create: (context) => CategoryProductsProvider(selectedCategory),
            child: CategoryProductsWidget(
              categoryTitle: title,
              assetPath: _getCategoryAsset(title),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    String categoryTitle,
    int? categoryId,
  ) {
    final searchHint = 'ابحث في $categoryTitle (وجبات، منتجات ومتاجر)...';

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      toolbarHeight: 64,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // 1. Right-oriented Standard Back Button
            HeaderCircleButton.back(
              size: 40,
              onTap: () {
                final navProvider =
                    Provider.of<HomeNavigationProvider>(context, listen: false);
                if (navProvider.homePage is! CategoriesPage) {
                  Navigator.pop(context);
                } else {
                  navProvider.categoryBack();
                }
              },
            ),

            const SizedBox(width: 10),

            // 2. Search Bar Pill with Quick Access
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SearchPage(
                        productCategoryId: categoryId,
                        categoryTitle: categoryTitle,
                      ),
                    ),
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(21),
                    border:
                        Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const JtakSearchIcon(
                        color: Color(0xFF64748B),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          searchHint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: const Color(0xFF94A3B8),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
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
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFFF1F5F9), thickness: 1),
      ),
    );
  }
}
