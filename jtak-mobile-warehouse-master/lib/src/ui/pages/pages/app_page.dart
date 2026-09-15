import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/app_pages_provider.dart';
import '../../../utils/custom_widgets/base_view.dart';
import '../../../utils/utilities/global_var.dart';

/// ---------------------------------------------------------------------------
/// Merchant Legal & Informational Content Page (Terms, Privacy & Policies)
/// Renders server HTML content or rich pre-built merchant partner terms.
/// ---------------------------------------------------------------------------

class AppPage extends StatelessWidget {
  final String pageType;
  final String pageTitle;

  const AppPage({
    super.key,
    required this.pageType,
    required this.pageTitle,
  });

  @override
  Widget build(BuildContext context) {
    return BaseView<AppPagesProvider>(
      modelProvider: AppPagesProvider(pageType: pageType),
      onModelReady: (modelProvider) {
        modelProvider.title = pageTitle;
        modelProvider.loadData();
      },
      builder: (context, modelProvider) {
        final hasServerContent = GlobalVar.checkString(modelProvider.body);

        return Scaffold(
          backgroundColor: kPageBackground,
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: Colors.white,
            title: Text(
              modelProvider.title ?? pageTitle,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: kCharcoalDark,
              ),
            ),
            leading: IconButton(
              icon: const Icon(PhosphorIconsRegular.arrowRight, color: kCharcoalDark),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(PhosphorIconsRegular.arrowClockwise, size: 20, color: kCharcoalMedium),
                tooltip: 'تحديث المحتوى',
                onPressed: () => modelProvider.loadData(),
              ),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: Color(0xFFE2E8F0)),
            ),
          ),
          body: modelProvider.isBusy
              ? const Center(
                  child: CircularProgressIndicator(color: kPrimaryOrange),
                )
              : RefreshIndicator(
                  color: kPrimaryOrange,
                  onRefresh: () => modelProvider.loadData(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.all(16),
                    child: hasServerContent
                        ? Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: kCardBorderColor, width: 1.0),
                            ),
                            child: HtmlWidget(
                              modelProvider.body!,
                              textStyle: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 13.5,
                                color: kCharcoalDark,
                                height: 1.6,
                              ),
                            ),
                          )
                        : _buildFallbackTermsContent(context),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildFallbackTermsContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Document Header Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kCardBorderColor, width: 1.0),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3EB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(PhosphorIconsRegular.fileText, color: kPrimaryOrange, size: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'شروط وسياسة استخدام منصة جيتك',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: kCharcoalDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'اتفاقية مستوى الخدمة وحقوق والتزامات المتاجر الشريكة',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11.5,
                        color: kCharcoalMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        _buildSectionCard(
          number: '١',
          title: 'شروط الانضمام والاعتماد كمتجر شريك',
          content:
              'يقر المتجر الشريك بمسؤوليته الكاملة عن صحة ودقة البيانات المدخلة في حسابه (الاسم، السجل التجاري أو المهني، العنوان الدقيق، وأرقام التواصل). وتعتبر موافقة إدارة جيتك شرطاً أساسياً لتفعيل المتجر واستقبال الطلبات.',
        ),

        const SizedBox(height: 12),

        _buildSectionCard(
          number: '٢',
          title: 'معايير جودة الوجبات والمنتجات والأسعار',
          content:
              'يلتزم المتجر بتقديم المنتجات والأطعمة وفق أعلى معايير الجودة والسلامة الصحية المعتمدة. كما يلتزم بأن تكون الأسعار المعروضة في التطبيق مطابقة للأسعار الفعلية دون أي زيادات غير مصرح بها، مع الالتزام بصور وأوصاف حقيقية تعكس المنتج بدقة.',
        ),

        const SizedBox(height: 12),

        _buildSectionCard(
          number: '٣',
          title: 'قبول وتجهيز الطلبات في الوقت المحدد',
          content:
              'يلتزم المتجر بالاستجابة الفورية للإشعارات والتنبيهات الواردة وقبول الطلبات خلال الوقت القياسي، والبدء في تجهيزها فوراً لتسليمها لمندوب التوصيل في الموعد المحدد تفادياً لأي تأخير يمس رضا العملاء.',
        ),

        const SizedBox(height: 12),

        _buildSectionCard(
          number: '٤',
          title: 'نطاق التغطية والتوصيل وساعات العمل',
          content:
              'يحدد المتجر نطاق التغطية الجغرافية بدقة عبر الإعدادات، ويتحمل مسؤولية تحديث حالة المتجر (مفتوح / مغلق) وفقاً لأوقات عمله الفعلية لضمان عدم وصول طلبات أثناء فترات الإغلاق.',
        ),

        const SizedBox(height: 12),

        _buildSectionCard(
          number: '٥',
          title: 'العمولات والتسويات المالية',
          content:
              'تتم التسويات المالية للمبيعات والأرباح والمستحقات دورياً وفق نسب العمولة المتفق عليها في عقد الشراكة، وتظهر كافة الحركات المالية بشفافية في تبويب "المالية" داخل التطبيق.',
        ),

        const SizedBox(height: 12),

        _buildSectionCard(
          number: '٦',
          title: 'حماية الخصوصية وسرية البيانات',
          content:
              'يلتزم المتجر بالحفاظ التام على سرية بيانات الزبائن وأرقام هواتفهم وعناوينهم وعدم استخدامها لأي غرض تجاري أو إعلاني خارج إطار تنفيذ الطلب المحدد.',
        ),

        const SizedBox(height: 20),

        Center(
          child: Text(
            'آخر تحديث: سبتمبر 2026 • منصة جيتك للخدمات اللوجستية',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 11.5,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionCard({
    required String number,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCardBorderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3EB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    number,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: kPrimaryOrange,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: kCharcoalDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12.5,
              color: kCharcoalMedium,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
