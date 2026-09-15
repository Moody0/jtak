import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../../../main_imports.dart';
import '../../../config/constants/constants.dart';
import '../../../config/constants/app_constant.dart';
import '../../../utils/utilities/lunch_url.dart';
import '../../../config/themes/colors.dart';
import '../../../core/controllers/app_pages_provider.dart';
import '../../widgets/header_circle_button.dart';
import '../../../utils/custom_widgets/base_view.dart';
import '../../../utils/custom_widgets/loading.dart';
import '../../../utils/utilities/global_var.dart';
import '../../../core/services/locator.dart';
import '../../../core/services/authentication_service.dart';
import '../../../utils/providers/sol_api.dart';

/// ---------------------------------------------------------------------------
/// JTAK Help & Support Page (المساعدة والدعم الفني)
/// Clean, Unified, Shadow-Free Design Strictly Following JTAK Theme Guidelines
/// ---------------------------------------------------------------------------

class AppPage extends StatefulWidget {
  final String pageType;
  final String pageTitle;

  const AppPage({
    super.key,
    required this.pageType,
    required this.pageTitle,
  });

  @override
  State<AppPage> createState() => _AppPageState();
}

class _AppPageState extends State<AppPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedCategoryIndex = 0;
  final Set<int> _expandedIndices = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  final List<String> _categories = [
    'الكل',
    'الطلبات والتوصيل',
    'طرق الدفع',
    'الحساب والعناوين',
  ];

  final List<Map<String, dynamic>> _faqs = [
    {
      'category': 'الطلبات والتوصيل',
      'icon': PhosphorIconsFill.motorcycle,
      'iconColor': kPrimaryOrange,
      'iconBg': const Color(0xFFFFF3EB),
      'question': 'كيف يمكنني تتبع طلبي في الوقت الفعلي؟',
      'answer':
          'يمكنك متابعة حالة طلبك مباشرة من صفحة "طلباتي" في الشريط السفلي، حيث تظهر لك مراحل التحضير، استلام المندوب، والوصول إلى موقعك بدقة.',
    },
    {
      'category': 'الطلبات والتوصيل',
      'icon': PhosphorIconsFill.clock,
      'iconColor': const Color(0xFF2563EB),
      'iconBg': const Color(0xFFEFF6FF),
      'question': 'ما هي مدة التوصيل المتوقعة لوجباتي؟',
      'answer':
          'تتراوح مدة التوصيل التقديرية بين 25 إلى 45 دقيقة بحسب بُعد المطعم أو المتجر عن عنوان التوصيل المحدد على الخريطة.',
    },
    {
      'category': 'الطلبات والتوصيل',
      'icon': PhosphorIconsFill.xCircle,
      'iconColor': const Color(0xFFDC2626),
      'iconBg': const Color(0xFFFEF2F2),
      'question': 'هل يمكنني إلغاء الطلب بعد تأكيده؟',
      'answer':
          'نعم، يمكنك إلغاء الطلب طالما أنه في حالة "قيد التحضير" من شاشة تفاصيل الطلب، أو التواصل مباشرة مع خدمة العملاء عبر واتساب.',
    },
    {
      'category': 'طرق الدفع',
      'icon': PhosphorIconsFill.wallet,
      'iconColor': const Color(0xFF059669),
      'iconBg': const Color(0xFFECFDF5),
      'question': 'ما هي خيارات الدفع المتاحة؟',
      'answer':
          'الدفع عند الاستلام (كاش) متاح حالياً لكافة الطلبات، وسيتم إطلاق الدفع الإلكتروني عبر البطاقات والمحافظ الرقمية في التحديث القادم.',
    },
    {
      'category': 'طرق الدفع',
      'icon': PhosphorIconsFill.receipt,
      'iconColor': const Color(0xFF7C3AED),
      'iconBg': const Color(0xFFF5F3FF),
      'question': 'هل توجد أي رسوم إضافية غير موضحة بالفاتورة؟',
      'answer':
          'لا توجد أي رسوم مخفية؛ يتم توضيح سعر الوجبات ورسوم التوصيل والمجموع النهائي بدقة قبل تأكيد طلبك.',
    },
    {
      'category': 'الحساب والعناوين',
      'icon': PhosphorIconsFill.mapPin,
      'iconColor': const Color(0xFFD97706),
      'iconBg': const Color(0xFFFFFBEB),
      'question': 'كيف أقوم بتغيير عنوان التوصيل؟',
      'answer':
          'انقر على شريط العنوان في أعلى الصفحة الرئيسية لتحديد موقعك الجغرافي الدقيق على الخريطة وحفظ عناوينك المفضلة (المنزل، العمل).',
    },
    {
      'category': 'الحساب والعناوين',
      'icon': PhosphorIconsFill.shieldCheck,
      'iconColor': const Color(0xFF0D9488),
      'iconBg': const Color(0xFFF0FDFA),
      'question': 'ماذا أفعل في حال وصول طلب غير مطابق أو صنف ناقص؟',
      'answer':
          'تواصل معنا مباشرة عبر محادثة واتساب مع تزويدنا برقم الطلب، وسيقوم فريق الدعم بحل المشكلة وتعويضك فوراً.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return BaseView<AppPagesProvider>(
      modelProvider: AppPagesProvider(pageType: widget.pageType),
      onModelReady: (modelProvider) {
        modelProvider.title = widget.pageTitle;
        modelProvider.loadData();
      },
      builder: (context, modelProvider) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: _buildAppBar(modelProvider.title ?? widget.pageTitle),
          body: SafeArea(
            child: FullScreenLoading(
              inAsyncCall: modelProvider.isBusy,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  overscroll: false,
                  physics: const ClampingScrollPhysics(),
                ),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: _buildContent(modelProvider),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(String title) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      leading: Center(
        child: HeaderCircleButton(
          onTap: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: kCharcoalDark,
            size: 20,
          ),
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: kCharcoalDark,
        ),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFFF1F5F9), thickness: 1),
      ),
    );
  }

  Widget _buildContent(AppPagesProvider modelProvider) {
    if (GlobalVar.checkString(modelProvider.body)) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        ),
        child: HtmlWidget(
          modelProvider.body ?? '',
          textStyle: GoogleFonts.ibmPlexSansArabic(
            fontSize: 14,
            height: 1.6,
            color: kCharcoalDark,
          ),
        ),
      );
    }

    final isHelp = widget.pageType.toLowerCase().contains('help') ||
        widget.pageTitle.contains('المساعدة') ||
        widget.pageTitle.contains('الدعم');

    if (isHelp) {
      return _buildHelpCenter();
    } else {
      return _buildTermsPage();
    }
  }

  // ---------------------------------------------------------------------------
  // 1. HELP & SUPPORT CENTER (متناسق تماماً مع هوية وتصميم جيتك)
  // ---------------------------------------------------------------------------
  Widget _buildHelpCenter() {
    final filtered = _faqs.where((faq) {
      final matchCat = _selectedCategoryIndex == 0 ||
          faq['category'] == _categories[_selectedCategoryIndex];
      final matchQuery = _searchQuery.isEmpty ||
          faq['question'].toString().contains(_searchQuery) ||
          faq['answer'].toString().contains(_searchQuery);
      return matchCat && matchQuery;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. WhatsApp Support Card
        _buildWhatsAppCard(),

        const SizedBox(height: 12),

        // 2. Phone Call Hotline Card
        _buildHotlineCard(),

        const SizedBox(height: 22),

        // 3. Search Bar
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              const JtakSearchIcon(color: Color(0xFF94A3B8), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kCharcoalDark,
                  ),
                  decoration: InputDecoration(
                    hintText: 'ابحث في الأسئلة الشائعة...',
                    hintStyle: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty || _searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear,
                      size: 18, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 4. Category Filter Chips (JTAK Orange Theme)
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            overscroll: false,
            physics: const ClampingScrollPhysics(),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: Row(
              children: List.generate(_categories.length, (idx) {
                final isSelected = _selectedCategoryIndex == idx;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategoryIndex = idx);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? kPrimaryOrange : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? kPrimaryOrange
                              : const Color(0xFFE2E8F0),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        _categories[idx],
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),

        const SizedBox(height: 18),

        // Section Title
        Text(
          'الأسئلة الشائعة',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: kCharcoalDark,
          ),
        ),
        const SizedBox(height: 10),

        // 5. FAQ Accordions with Distinct Category Icons
        if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      PhosphorIconsRegular.magnifyingGlass,
                      size: 26,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'لا توجد نتائج مطابقة لبحثك',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: kCharcoalDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'جرّب البحث بكلمات أخرى أو اختر قسماً مختلفاً',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          )
        else
          ...List.generate(filtered.length, (idx) {
            final faq = filtered[idx];
            final isExpanded = _expandedIndices.contains(idx);

            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isExpanded ? const Color(0xFFFCFDFD) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isExpanded ? kPrimaryOrange : const Color(0xFFE2E8F0),
                  width: isExpanded ? 1.4 : 1.0,
                ),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (isExpanded) {
                          _expandedIndices.remove(idx);
                        } else {
                          _expandedIndices.add(idx);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isExpanded
                                  ? kPrimaryOrange
                                  : const Color(0xFFFFF3EB),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.help_outline_rounded,
                                size: 19,
                                color:
                                    isExpanded ? Colors.white : kPrimaryOrange,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              faq['question'],
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 13.8,
                                fontWeight: FontWeight.w700,
                                color:
                                    isExpanded ? kPrimaryOrange : kCharcoalDark,
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          AnimatedRotation(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOutCubic,
                            turns: isExpanded ? 0.5 : 0.0,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isExpanded
                                    ? const Color(0xFFFFF3EB)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: isExpanded
                                      ? kPrimaryOrange
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOutCubic,
                    alignment: Alignment.topCenter,
                    child: isExpanded
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(
                                  height: 1,
                                  color: Color(0xFFF1F5F9),
                                  thickness: 1),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 6),
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: kPrimaryOrange,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        faq['answer'],
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 13.2,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF475569),
                                          height: 1.6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          }),

        const SizedBox(height: 16),

        // 6. Direct Support Message Card
        _buildMessageTicketCard(),

        const SizedBox(height: 24),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // WhatsApp Support Card (Official Full-Color WhatsApp SVG Logo)
  // ---------------------------------------------------------------------------
  Widget _buildWhatsAppCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Row(
        children: [
          // Authentic WhatsApp Logo in Squircle Frame
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFEBFBF0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: SvgPicture.asset(
                '${kAssetSvgBase}whatsapp.svg',
                width: 28,
                height: 28,
                errorBuilder: (_, __, ___) => const Icon(
                  PhosphorIconsFill.chatCircleDots,
                  color: Color(0xFF25D366),
                  size: 26,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'واتساب الدعم الفني',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: kCharcoalDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'محادثة مباشرة لحل مشكلات الطلبات',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              LunchUrl.openWhatsApp(
                phone: kSupportWhatsAppNumber,
                message: 'مرحباً خدمة عملاء جيتك، أحتاج مساعدة بخصوص التطبيق.',
                context: context,
              );
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEBFBF0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF25D366).withValues(alpha: 0.3),
                    width: 1.0),
              ),
              child: Text(
                'تواصل الآن',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF16A34A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hotline Call Card (Orange Theme)
  // ---------------------------------------------------------------------------
  Widget _buildHotlineCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3EB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: SvgPicture.asset(
                '${kAssetSvgBase}call.svg',
                width: 22,
                height: 22,
                errorBuilder: (_, __, ___) => const Icon(
                  PhosphorIconsFill.phoneCall,
                  size: 22,
                  color: kPrimaryOrange,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    LunchUrl.makeCall(kSupportPhoneNumber, context: context);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'الخط الساخن: ',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: kCharcoalDark,
                        ),
                      ),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          '\u202A$kSupportPhoneFormatted\u202C',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: kCharcoalDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'يومياً 9:00 ص - 12:00 منتصف الليل',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    LunchUrl.makeCall(kSupportPhoneNumber, context: context);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                    decoration: BoxDecoration(
                      color: kPrimaryOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          PhosphorIconsBold.phoneCall,
                          size: 15,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'اتصال',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12.5,
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
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Message Ticket Card (JTAK Theme)
  // ---------------------------------------------------------------------------
  Widget _buildMessageTicketCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Icon(PhosphorIconsFill.notePencil,
                  size: 22, color: kCharcoalDark),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'لديك استفسار أو اقتراح؟',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13.8,
                    fontWeight: FontWeight.w800,
                    color: kCharcoalDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'أرسل رسالة خطية لفريق الإدارة',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _showSupportMessageDialog,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3EB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: kPrimaryOrange.withValues(alpha: 0.3), width: 1.0),
              ),
              child: Text(
                'كتابة رسالة',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: kPrimaryOrange,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSupportMessageDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final messageController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    if (locator.isRegistered<AuthenticationService>()) {
      final user = locator<AuthenticationService>().user;
      final savedName = user?.fullName?.trim();
      if (savedName != null &&
          savedName.isNotEmpty &&
          savedName != 'عميل جيتك' &&
          savedName != 'مستخدم جيتك') {
        nameController.text = savedName;
      }
      phoneController.text = user?.phoneNumber?.trim() ?? '';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (sbContext, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'رسالة إلى الدعم الفني',
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: kCharcoalDark,
            ),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'أدخل بياناتك واكتب استفسارك أو مشكلتك وسنقوم بمتابعتها بأسرع وقت:',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameController,
                    enabled: !isSubmitting,
                    textInputAction: TextInputAction.next,
                    style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'الاسم الكامل',
                      hintText: 'أدخل اسمك الكامل',
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                      hintStyle: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13, color: const Color(0xFF94A3B8)),
                      labelStyle: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13, color: const Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
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
                        borderSide:
                            const BorderSide(color: kPrimaryOrange, width: 1.5),
                      ),
                    ),
                    validator: (val) => (val == null || val.trim().length < 2)
                        ? 'يرجى إدخال الاسم'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: phoneController,
                    enabled: !isSubmitting,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    textInputAction: TextInputAction.next,
                    style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'رقم الهاتف',
                      hintText: 'أدخل رقم الهاتف للتواصل معك',
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                      hintStyle: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13, color: const Color(0xFF94A3B8)),
                      labelStyle: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13, color: const Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
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
                        borderSide:
                            const BorderSide(color: kPrimaryOrange, width: 1.5),
                      ),
                    ),
                    validator: (val) {
                      final digits =
                          val?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                      return digits.length < 7
                          ? 'يرجى إدخال رقم هاتف صحيح'
                          : null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: messageController,
                    maxLines: 4,
                    enabled: !isSubmitting,
                    style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'الرسالة',
                      hintText: 'اكتب رسالتك هنا بالتفصيل...',
                      hintStyle: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13, color: const Color(0xFF94A3B8)),
                      labelStyle: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13, color: const Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
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
                        borderSide:
                            const BorderSide(color: kPrimaryOrange, width: 1.5),
                      ),
                    ),
                    validator: (val) => (val == null || val.trim().length < 5)
                        ? 'يرجى كتابة رسالة واضحة'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: Text(
                'إلغاء',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryOrange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;

                      setDialogState(() {
                        isSubmitting = true;
                      });

                      try {
                        String? senderEmail;

                        if (locator.isRegistered<AuthenticationService>()) {
                          final auth = locator<AuthenticationService>();
                          final user = auth.user;
                          if (user != null) {
                            senderEmail = user.email;
                          }
                        }

                        final body = {
                          'DisplayName': nameController.text.trim(),
                          'PhoneNumber': phoneController.text.trim(),
                          'Email': senderEmail,
                          'Title': 'رسالة إلى الدعم الفني',
                          'Message': messageController.text.trim(),
                        };

                        final api = locator<SolApi>();
                        await api.postRequest('/Contact', body);

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        if (mounted) {
                          context.showSnakBar(
                              'تم استلام رسالتك بنجاح وسيقوم فريق الإدارة بمتابعتها');
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          setDialogState(() {
                            isSubmitting = false;
                          });
                        }
                        if (mounted) {
                          context.showSnakBar(
                              'حدث خطأ أثناء إرسال الرسالة، يرجى المحاولة لاحقاً');
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.2,
                      ),
                    )
                  : Text(
                      'إرسال الرسالة',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. TERMS & CONDITIONS (الشروط والأحكام وسياسة الخصوصية)
  // ---------------------------------------------------------------------------
  Widget _buildTermsPage() {
    final sections = [
      {
        'number': '٠١',
        'title': 'مقدمة وقبول الشروط',
        'icon': PhosphorIconsFill.fileText,
        'iconColor': kPrimaryOrange,
        'iconBg': const Color(0xFFFFF3EB),
        'content':
            'أهلاً بك في تطبيق جيتك (JTAK). باستخدامك للتطبيق أو إنشاء حساب جديد، فإنك تقر وتوافق على الالتزام بكافة الشروط والأحكام وسياسات الخدمة الموضحة هنا لضمان تجربة آمنة وموثوقة.',
      },
      {
        'number': '٠٢',
        'title': 'حساب المستخدم والأمان',
        'icon': PhosphorIconsFill.user,
        'iconColor': const Color(0xFF3B82F6),
        'iconBg': const Color(0xFFEFF6FF),
        'content':
            'يلتزم المستخدم بتقديم رقم هاتف صحيح وتأكيده عبر رمز التحقق (OTP). يتحمل المستخدم مسؤولية الحفاظ على سرية حسابه وكافة الأنشطة والطلبات التي تتم من خلاله.',
      },
      {
        'number': '٠٣',
        'title': 'آلية الطلب وتحديد المواقع',
        'icon': PhosphorIconsFill.motorcycle,
        'iconColor': kPrimaryOrange,
        'iconBg': const Color(0xFFFFF3EB),
        'content':
            'يلتزم تطبيق جيتك بتوصيل الطلبات من المطاعم والمتاجر المعتمدة إلى موقعك الجغرافي المحدد بدقة. يرجى التأكد من صحة العنوان ورقم التواصل لتفادي أي تأخير في استلام الوجبات.',
      },
      {
        'number': '٠٤',
        'title': 'سياسة الخصوصية وحماية البيانات',
        'icon': PhosphorIconsFill.shieldCheck,
        'iconColor': const Color(0xFF10B981),
        'iconBg': const Color(0xFFECFDF5),
        'content':
            'نحن نحرص على حماية بياناتك الشخصية بأعلى معايير الأمان. يتم استخدام موقعك ورقم هاتفك فقط لمعالجة الطلبات وإتمام التوصيل، ولا يتم بيع أو مشاركة بياناتك مع أي أطراف إعلانية خارجية.',
      },
      {
        'number': '٠٥',
        'title': 'الإلغاء وحقوق التعويض',
        'icon': PhosphorIconsFill.arrowCounterClockwise,
        'iconColor': const Color(0xFFF59E0B),
        'iconBg': const Color(0xFFFFFBEB),
        'content':
            'يحق للعميل إلغاء الطلب طالما أنه لا يزال في مرحلة "قيد التحضير". في حال استلام صنف ناقص أو غير مطابق، يرجى إبلاغ الدعم الفني خلال ٣٠ دقيقة ليتم التعويض فوراً.',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Hero Overview Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3EB),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Transform.flip(
                        flipX: true,
                        child: const Icon(PhosphorIconsFill.fileText,
                            color: kPrimaryOrange, size: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'اتفاقية الاستخدام والخصوصية',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: kCharcoalDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'حقوقك والتزاماتك عند استخدام منصة جيتك',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.flip(
                      flipX: true,
                      child: const Icon(PhosphorIconsFill.shieldCheck,
                          size: 14, color: Color(0xFF10B981)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'سارية ومحدثة لعام 2026',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Structured Section Cards
        ...sections.map((sec) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: sec['iconBg'] as Color,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Center(
                        child: Transform.flip(
                          flipX: true,
                          child: Icon(
                            sec['icon'] as IconData,
                            size: 18,
                            color: sec['iconColor'] as Color,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        sec['title'] as String,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: kCharcoalDark,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        sec['number'] as String,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  sec['content'] as String,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13.2,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF475569),
                    height: 1.65,
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 24),
      ],
    );
  }
}
