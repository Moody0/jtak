import 'dart:io';

import 'package:app_jtak_warehouse/src/config/themes/colors.dart';
import 'package:app_jtak_warehouse/src/core/controllers/products_provider.dart';
import 'package:app_jtak_warehouse/src/core/models/product_model.dart';
import 'package:app_jtak_warehouse/src/core/services/locator.dart';
import 'package:app_jtak_warehouse/src/core/services/upload_service.dart';
import 'package:app_jtak_warehouse/src/ui/widgets/product_widgets.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/messages.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

class ProductEditPage extends StatefulWidget {
  static const String routeName = '/ProductEditPage';
  final ProductModel? product;
  final int? initialCategoryId;

  const ProductEditPage({
    Key? key,
    this.product,
    this.initialCategoryId,
  }) : super(key: key);

  @override
  _ProductEditPageState createState() => _ProductEditPageState();
}

class _ProductEditPageState extends State<ProductEditPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _priceController;
  late TextEditingController _unitController;
  late TextEditingController _descriptionController;

  int? _selectedCategoryId;
  bool _isActive = true;
  String? _photoUrl;
  String? _localPhotoPath;
  bool _isUploadingPhoto = false;
  bool _isSaving = false;

  final List<String> _commonUnits = ['وجبة', 'قطعة', 'سندويش', 'صحن', 'كغ', 'علبة', 'كأس'];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _titleController = TextEditingController(text: p?.product ?? '');
    _priceController = TextEditingController(
      text: p != null
          ? (p.finalPrice?.toInt() ?? p.merchantPrice ?? '').toString()
          : '',
    );
    _unitController = TextEditingController(text: p?.productUnit ?? 'وجبة');
    _descriptionController = TextEditingController(text: p?.productDescription ?? '');
    _selectedCategoryId = p?.productCategoryId ?? widget.initialCategoryId;
    _isActive = p?.productActive ?? true;
    _photoUrl = p?.productPhotos?.split(',').first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _unitController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final uploadService = locator<UploadService>();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'اختر مصدر صورة الصنف',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const OppositeIcon(PhosphorIconsRegular.image, color: kPrimaryOrange, size: 22),
                ),
                title: Text(
                  'المعرض (Gallery)',
                  style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const OppositeIcon(PhosphorIconsRegular.camera, color: kPrimaryOrange, size: 22),
                ),
                title: Text(
                  'الكاميرا (Camera)',
                  style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final localPath = await uploadService.pickImage(source: source);
    if (localPath == null) return;

    setState(() {
      _localPhotoPath = localPath;
      _isUploadingPhoto = true;
    });

    try {
      final serverPath = await uploadService.uploadImage(localPath);
      if (serverPath != null) {
        setState(() {
          _photoUrl = serverPath;
        });
        if (mounted) {
          SnackBarWidget.showCustomSnackBar(
            context,
            'تم رفع صورة الصنف بنجاح! 📸',
            backgroundColor: const Color(0xFF065F46),
          );
        }
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => const CustomDialog(message: 'فشل رفع الصورة، يرجى المحاولة لاحقاً.'),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(context: context, builder: (_) => CustomDialog(message: e.toString()));
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      showDialog(
        context: context,
        builder: (_) => const CustomDialog(message: 'يرجى إدخال سعر صالح للصنف أكبر من صفر.'),
      );
      return;
    }

    setState(() => _isSaving = true);
    final provider = Provider.of<ProductsProvider>(context, listen: false);

    final payload = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'price': price,
      'unit': _unitController.text.trim(),
      'productCategoryId': _selectedCategoryId,
      'photos': _photoUrl,
      'active': _isActive,
    };

    try {
      bool success;
      if (widget.product != null && widget.product!.productId != null) {
        success = await provider.updateProduct(widget.product!.productId!, payload);
      } else {
        success = await provider.createProduct(payload);
      }

      if (success && mounted) {
        Navigator.pop(context);
        SnackBarWidget.showCustomSnackBar(
          context,
          widget.product != null ? 'تم تحديث الصنف بنجاح! ✅' : 'تمت إضافة الصنف إلى القائمة بنجاح! 🎉',
          backgroundColor: const Color(0xFF065F46),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(context: context, builder: (_) => CustomDialog(message: e.toString()));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'حذف الصنف',
          style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Text(
          'هل أنت متأكد من حذف "${widget.product?.product}" من قائمة المتجر؟',
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

    if (confirm != true) return;

    setState(() => _isSaving = true);
    final provider = Provider.of<ProductsProvider>(context, listen: false);

    try {
      final success = await provider.deleteProduct(widget.product!.productId!);
      if (success && mounted) {
        Navigator.pop(context);
        SnackBarWidget.showCustomSnackBar(
          context,
          'تم حذف الصنف من القائمة',
          backgroundColor: const Color(0xFFB91C1C),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(context: context, builder: (_) => CustomDialog(message: e.toString()));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProductsProvider>(context);
    final isEditing = widget.product != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          isEditing ? 'تعديل الصنف' : 'إضافة صنف جديد',
          style: GoogleFonts.ibmPlexSansArabic(
            fontWeight: FontWeight.w800,
            fontSize: 16.5,
            color: const Color(0xFF1E293B),
          ),
        ),
        centerTitle: true,
        actions: [
          if (isEditing)
            IconButton(
              icon: const OppositeIcon(PhosphorIconsRegular.trash, color: Color(0xFFEF4444), size: 20),
              tooltip: 'حذف الصنف',
              onPressed: _isSaving ? null : _deleteProduct,
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildPhotoCard(),
              const SizedBox(height: 16),
              _buildBasicInfoCard(provider),
              const SizedBox(height: 16),
              _buildAvailabilityCard(),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: (_isSaving || _isUploadingPhoto) ? null : _saveProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        isEditing ? 'حفظ التعديلات' : 'إضافة الصنف للقائمة',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Center(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 130,
                    height: 130,
                    color: const Color(0xFFF8FAFC),
                    child: _isUploadingPhoto
                        ? const Center(
                            child: CircularProgressIndicator(color: kPrimaryOrange, strokeWidth: 2),
                          )
                        : (_localPhotoPath != null && File(_localPhotoPath!).existsSync()
                            ? Image.file(
                                File(_localPhotoPath!),
                                fit: BoxFit.cover,
                              )
                            : (_photoUrl != null && _photoUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: UploadService.resolveImageUrl(_photoUrl),
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryOrange),
                                    ),
                                    errorWidget: (_, __, ___) => const Center(
                                      child: OppositeIcon(PhosphorIconsRegular.forkKnife, size: 44, color: Color(0xFF94A3B8)),
                                    ),
                                  )
                                : const Center(
                                    child: OppositeIcon(PhosphorIconsRegular.cameraPlus, size: 44, color: Color(0xFF94A3B8)),
                                  ))),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: InkWell(
                    onTap: _isUploadingPhoto ? null : _pickAndUploadImage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: kPrimaryOrange,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: const OppositeIcon(PhosphorIconsFill.camera, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _photoUrl != null ? 'اضغط على الكاميرا لتغيير الصورة' : 'اضغط لإضافة صورة جذابة للوجبة',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoCard(ProductsProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تفاصيل الصنف',
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: const Color(0xFF1E293B),
            ),
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),

          // Product Title
          TextFormField(
            controller: _titleController,
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'اسم الصنف / الوجبة *',
              labelStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 13),
              hintText: 'مثال: برغر لحم كلاسيك، بيتزا خضار...',
              hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFF94A3B8)),
              prefixIcon: const OppositeIcon(PhosphorIconsRegular.forkKnife, size: 20, color: Color(0xFF64748B)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'اسم الصنف مطلوب' : null,
          ),
          const SizedBox(height: 14),

          // Price
          TextFormField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 15, fontWeight: FontWeight.w700),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'السعر بالليرة السورية (ل.س) *',
              labelStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 13),
              hintText: 'مثال: 35000',
              hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFF94A3B8)),
              prefixIcon: const OppositeIcon(PhosphorIconsRegular.currencyCircleDollar, size: 20, color: Color(0xFF64748B)),
              suffixText: _priceController.text.isNotEmpty
                  ? '${NumberFormat('#,###').format(double.tryParse(_priceController.text.trim())?.toInt() ?? 0)} ل.س'
                  : null,
              suffixStyle: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kPrimaryOrange,
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'السعر مطلوب';
              final n = double.tryParse(v.trim());
              if (n == null || n <= 0) return 'يرجى إدخال رقم صحيح أكبر من صفر';
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Category Selector
          DropdownButtonFormField<int?>(
            initialValue: (_selectedCategoryId == null || provider.categoriesForSelection.any((c) => c.id == _selectedCategoryId))
                ? _selectedCategoryId
                : null,
            decoration: InputDecoration(
              labelText: 'التصنيف في القائمة',
              labelStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 13),
              prefixIcon: const OppositeIcon(PhosphorIconsRegular.tag, size: 20, color: Color(0xFF64748B)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text('عام (بدون تصنيف خاص)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 13)),
              ),
              ...provider.categoriesForSelection.map((c) {
                return DropdownMenuItem<int?>(
                  value: c.id,
                  child: Text(c.title, style: GoogleFonts.ibmPlexSansArabic(fontSize: 13)),
                );
              }).toList(),
            ],
            onChanged: (val) => setState(() => _selectedCategoryId = val),
          ),
          const SizedBox(height: 14),

          // Unit
          TextFormField(
            controller: _unitController,
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'الوحدة / حجم التقديم',
              labelStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 13),
              hintText: 'وجبة، قطعة، كغ...',
              hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFF94A3B8)),
              prefixIcon: const OppositeIcon(PhosphorIconsRegular.scales, size: 20, color: Color(0xFF64748B)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 6,
            children: _commonUnits.map((u) {
              final isSelected = _unitController.text == u;
              return ActionChip(
                label: Text(
                  u,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? kPrimaryOrange : const Color(0xFF475569),
                  ),
                ),
                backgroundColor: isSelected ? const Color(0xFFFFF7ED) : const Color(0xFFF1F5F9),
                side: BorderSide(
                  color: isSelected ? const Color(0xFFFFD6C2) : const Color(0xFFE2E8F0),
                ),
                onPressed: () => setState(() => _unitController.text = u),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Description
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'الوصف والمكونات',
              labelStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 13),
              hintText: 'اكتب تفاصيل الوجبة والمكونات لإعلام الزبائن...',
              hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFF94A3B8)),
              prefixIcon: const OppositeIcon(PhosphorIconsRegular.note, size: 20, color: Color(0xFF64748B)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SwitchListTile(
        activeTrackColor: const Color(0xFF22C55E),
        title: Text(
          _isActive ? 'الصنف متوفر للطلب 🟢' : 'الصنف غير متوفر اليوم (نفد) ⚪',
          style: GoogleFonts.ibmPlexSansArabic(
            fontWeight: FontWeight.w700,
            color: _isActive ? const Color(0xFF15803D) : const Color(0xFF64748B),
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          'يمكنك إيقاف توفر الصنف مؤقتاً عند نفاد المكونات في المطبخ',
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: const Color(0xFF94A3B8)),
        ),
        value: _isActive,
        onChanged: (val) => setState(() => _isActive = val),
      ),
    );
  }
}
