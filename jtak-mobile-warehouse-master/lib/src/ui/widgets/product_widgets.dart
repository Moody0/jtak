import 'package:app_jtak_warehouse/src/config/themes/colors.dart';
import 'package:app_jtak_warehouse/src/core/controllers/products_provider.dart';
import 'package:app_jtak_warehouse/src/core/models/product_model.dart';
import 'package:app_jtak_warehouse/src/core/services/upload_service.dart';
import 'package:app_jtak_warehouse/src/ui/pages/catalog/product_edit_page.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/messages.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import 'package:app_jtak_warehouse/src/utils/custom_widgets/opposite_icon.dart';
export 'package:app_jtak_warehouse/src/utils/custom_widgets/opposite_icon.dart';

/// ---------------------------------------------------------------------------
/// Modern Merchant Product Card (Squircle Thumbnail, 1-Tap Stock Switch, Quick Price)
/// ---------------------------------------------------------------------------
class ProductSingleItem extends StatelessWidget {
  final ProductModel item;
  const ProductSingleItem(this.item, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProductsProvider>(context);
    final isActive = item.productActive;
    final isToggling = provider.isToggling(item.productId);
    final photo = item.productPhotos?.split(',').first.trim();
    final hasPhoto = photo != null && photo.isNotEmpty && photo != 'null';

    final price = item.finalPrice ?? (item.merchantPrice?.toDouble()) ?? 0.0;
    final formattedPrice = NumberFormat('#,###').format(price.toInt());

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isActive ? 1.0 : 0.78,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.pushNamed(
                context,
                ProductEditPage.routeName,
                arguments: item,
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Squircle Product Image with status dot
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 76,
                          height: 76,
                          color: const Color(0xFFF8FAFC),
                          child: hasPhoto
                              ? CachedNetworkImage(
                                  imageUrl: UploadService.resolveImageUrl(photo),
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => const Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: kPrimaryOrange,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => const Center(
                                    child: OppositeIcon(
                                      PhosphorIconsRegular.forkKnife,
                                      size: 28,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                )
                              : Container(
                                  color: const Color(0xFFFFF7ED),
                                  child: const Center(
                                    child: OppositeIcon(
                                      PhosphorIconsRegular.forkKnife,
                                      size: 30,
                                      color: Color(0xFFFB923C),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      // Availability Dot Indicator
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFF22C55E) : const Color(0xFF94A3B8),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // 2. Dish Details (Title, Category / Unit chips, Formatted Price)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title
                        Text(
                          item.product ?? 'صنف بدون اسم',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Chips row: Category & Unit
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            if (item.productCat1 != null && item.productCat1!.trim().isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.productCat1!.trim(),
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            if (item.productUnit != null && item.productUnit!.trim().isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFFFEDD5)),
                                ),
                                child: Text(
                                  item.productUnit!.trim(),
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFC2410C),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Interactive Formatted Price (Tap to Quick Edit)
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => _showQuickPriceDialog(context, provider),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  formattedPrice,
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    color: kPrimaryOrange,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'ل.س',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const OppositeIcon(
                                  PhosphorIconsRegular.pencilSimpleLine,
                                  size: 12,
                                  color: Color(0xFF94A3B8),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 3. Right Actions: 1-Tap Stock Switch & Quick Options Menu
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1-Tap In-Stock / Out-of-Stock Capsule
                      _buildAvailabilityToggle(context, provider, isToggling),
                      const SizedBox(height: 8),

                      // Quick Actions Row
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Quick Edit Pill Button
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.pushNamed(
                                context,
                                ProductEditPage.routeName,
                                arguments: item,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const OppositeIcon(
                                    PhosphorIconsRegular.pencilSimple,
                                    size: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'تعديل',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),

                          // Card Context Menu (Quick price / Delete)
                          PopupMenuButton<String>(
                            icon: const OppositeIcon(
                              PhosphorIconsRegular.dotsThreeVertical,
                              size: 18,
                              color: Color(0xFF94A3B8),
                            ),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (val) {
                              if (val == 'price') {
                                _showQuickPriceDialog(context, provider);
                              } else if (val == 'delete') {
                                _confirmDelete(context, provider);
                              }
                            },
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'price',
                                child: Row(
                                  children: [
                                    const OppositeIcon(
                                      PhosphorIconsRegular.currencyCircleDollar,
                                      size: 16,
                                      color: kPrimaryOrange,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'تعديل السعر السريع',
                                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const OppositeIcon(
                                      PhosphorIconsRegular.trash,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'حذف الصنف',
                                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
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

  /// 1-Tap In-Stock / Out-of-Stock Capsule with in-flight spinner
  Widget _buildAvailabilityToggle(BuildContext context, ProductsProvider provider, bool isToggling) {
    final isActive = item.productActive;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: isToggling
          ? null
          : () async {
              HapticFeedback.lightImpact();
              try {
                await provider.toggleProductAvailability(item);
                if (context.mounted) {
                  SnackBarWidget.showCustomSnackBar(
                    context,
                    item.productActive
                        ? 'تم تفعيل توفر "${item.product ?? ''}" للزبائن 🟢'
                        : 'تم تحويل "${item.product ?? ''}" إلى غير متوفر مؤقتاً ⚪',
                    backgroundColor: item.productActive ? const Color(0xFF065F46) : const Color(0xFF475569),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  SnackBarWidget.showCustomSnackBar(
                    context,
                    'تعذر تحديث حالة التوفر: $e',
                    backgroundColor: const Color(0xFFB91C1C),
                  );
                }
              }
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isToggling)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryOrange),
              )
            else
              OppositeIcon(
                isActive ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.prohibit,
                size: 14,
                color: isActive ? const Color(0xFF15803D) : const Color(0xFF64748B),
              ),
            const SizedBox(width: 4),
            Text(
              isActive ? 'متوفر' : 'غير متوفر',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isActive ? const Color(0xFF15803D) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Quick price change modal bottom sheet
  void _showQuickPriceDialog(BuildContext context, ProductsProvider provider) {
    final currentPrice = (item.finalPrice ?? item.merchantPrice?.toDouble() ?? 0.0).toInt();
    final controller = TextEditingController(text: currentPrice.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final bottomInset = MediaQuery.of(modalContext).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sheet Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const OppositeIcon(
                          PhosphorIconsRegular.currencyCircleDollar,
                          color: kPrimaryOrange,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تعديل السعر السريع',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              item.product ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 12.5,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Price Input
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: kPrimaryOrange,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'السعر الجديد',
                      suffixText: 'ل.س',
                      suffixStyle: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: kPrimaryOrange, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quick Step Adders
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [500, 1000, 2000, 5000].map((step) {
                      return OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        onPressed: () {
                          final cur = double.tryParse(controller.text.trim()) ?? 0.0;
                          final nextVal = (cur + step).toInt();
                          controller.text = nextVal.toString();
                          setModalState(() {});
                        },
                        child: Text(
                          '+$step',
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Save Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryOrange,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final newPrice = double.tryParse(controller.text.trim());
                      if (newPrice == null || newPrice <= 0) {
                        return;
                      }
                      Navigator.pop(modalContext);
                      HapticFeedback.mediumImpact();
                      try {
                        final ok = await provider.quickUpdatePrice(item, newPrice);
                        if (ok && context.mounted) {
                          SnackBarWidget.showCustomSnackBar(
                            context,
                            'تم تحديث سعر "${item.product ?? ''}" إلى ${NumberFormat('#,###').format(newPrice.toInt())} ل.س ✅',
                            backgroundColor: const Color(0xFF065F46),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          SnackBarWidget.showCustomSnackBar(
                            context,
                            'فشل تحديث السعر: $e',
                            backgroundColor: const Color(0xFFB91C1C),
                          );
                        }
                      }
                    },
                    child: Text(
                      'حفظ السعر الجديد',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Confirm delete dialog
  void _confirmDelete(BuildContext context, ProductsProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'حذف الصنف',
          style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Text(
          'هل أنت متأكد من حذف "${item.product ?? ''}" من قائمة المتجر؟',
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 13.5, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.ibmPlexSansArabic(color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'حذف',
              style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && item.productId != null) {
      HapticFeedback.heavyImpact();
      try {
        final success = await provider.deleteProduct(item.productId!);
        if (success && context.mounted) {
          SnackBarWidget.showCustomSnackBar(
            context,
            'تم حذف الصنف من القائمة',
            backgroundColor: const Color(0xFFB91C1C),
          );
        }
      } catch (e) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => CustomDialog(message: e.toString()),
          );
        }
      }
    }
  }
}

/// ---------------------------------------------------------------------------
/// Modern Shimmer Skeleton Card for fast, smooth loading states
/// ---------------------------------------------------------------------------
class ProductCardSkeleton extends StatefulWidget {
  const ProductCardSkeleton({Key? key}) : super(key: key);

  @override
  State<ProductCardSkeleton> createState() => _ProductCardSkeletonState();
}

class _ProductCardSkeletonState extends State<ProductCardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final opacity = 0.4 + (_anim.value * 0.4);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Row(
            children: [
              // Image skeleton
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0).withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 140,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0).withValues(alpha: opacity),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 70,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0).withValues(alpha: opacity),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 90,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0).withValues(alpha: opacity),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              // Toggle skeleton
              Container(
                width: 70,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0).withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
