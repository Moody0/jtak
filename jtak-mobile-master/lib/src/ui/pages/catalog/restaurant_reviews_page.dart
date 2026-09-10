import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../config/themes/colors.dart';
import '../../../core/data/mock_catalog_data.dart';
import '../../widgets/header_circle_button.dart';

class RestaurantReviewItem {
  final String author;
  final String date;
  final double rating;
  final String comment;

  const RestaurantReviewItem({
    required this.author,
    required this.date,
    required this.rating,
    required this.comment,
  });
}

class RestaurantReviewsPage extends StatelessWidget {
  static const String routeName = '/RestaurantReviewsPage';

  final MockRestaurantData restaurantData;

  const RestaurantReviewsPage({
    super.key,
    required this.restaurantData,
  });

  List<RestaurantReviewItem> get _restaurantReviews {
    final name = restaurantData.name.toLowerCase();
    final id = restaurantData.id;

    // 1. شاورما أنس الدمشقية
    if (id == 1 || id == 8 || name.contains('أنس') || name.contains('anas') || name.contains('شاورما')) {
      return const [
        RestaurantReviewItem(
          author: 'سامر الشامي',
          date: '28 أغسطس 2026',
          rating: 5.0,
          comment: 'وجبة العربي سوبر دجاج بتوصل سخنة وخبز الصاج مقمر تقمير، والثومية الشامية الأصلية لا يعلى عليها!',
        ),
        RestaurantReviewItem(
          author: 'باسل الجراح',
          date: '26 أغسطس 2026',
          rating: 5.0,
          comment: 'شاورما اللحمة بلدي طازجة بدبس الرمان والبيواز وطحينة موزونة صح بدون دهن زايد.',
        ),
        RestaurantReviewItem(
          author: 'ريما قدور',
          date: '24 أغسطس 2026',
          rating: 5.0,
          comment: 'وجبة العربي دبل عائلية ومشبعة جداً، والبطاطا مقلية ذهبية ومقرمشة مع مخلل اللفت البلدي.',
        ),
        RestaurantReviewItem(
          author: 'عمار الحمصي',
          date: '22 أغسطس 2026',
          rating: 5.0,
          comment: 'بروستد أنس مقرمش ونظيف وتتبيلته مميزة، وتوصيل جيتك وصل في أقل من ٢٠ دقيقة.',
        ),
        RestaurantReviewItem(
          author: 'دينا الصالح',
          date: '19 أغسطس 2026',
          rating: 4.0,
          comment: 'صحن شاورما الفرط كميته وفيرة وبتكفي العيلة، تغليف حراري نظيف ومحكم.',
        ),
        RestaurantReviewItem(
          author: 'فارس النعيمي',
          date: '15 أغسطس 2026',
          rating: 5.0,
          comment: 'أطيب شاورما بدمشق، طعم الشام الأصلي واللقمة طيبة ومتقنة.',
        ),
      ];
    }

    // 2. مشاوي وكباب بوابة دمشق
    if (id == 2 || id == 6 || name.contains('بوابة دمشق') || name.contains('مشاوي') || name.contains('كباب')) {
      return const [
        RestaurantReviewItem(
          author: 'م. حسان دمشقي',
          date: '27 أغسطس 2026',
          rating: 5.0,
          comment: 'كيلو الكباب الحلبي مشوي عالفحم الحجري على الأصول، اللحم غنم بلدي طري والخضار المشوية والخبز المحمر حكاية تانية.',
        ),
        RestaurantReviewItem(
          author: 'طارق الأيوبي',
          date: '25 أغسطس 2026',
          rating: 5.0,
          comment: 'الكبة المشوية بالجوز والرمان خرافية، وريحة الفحم واضحة والتسوية ممتازة.',
        ),
        RestaurantReviewItem(
          author: 'منى البيطار',
          date: '23 أغسطس 2026',
          rating: 5.0,
          comment: 'التبولة والفتوش فريش بدبس الرمان، والشيش طاووق طري ومتبل باللبن والثوم مظبوط.',
        ),
        RestaurantReviewItem(
          author: 'خالد الكردي',
          date: '20 أغسطس 2026',
          rating: 4.0,
          comment: 'مشاوي مشكلة ممتازة وتغليف القصدير حافظ على حرارة اللحمة حتى وصول المندوب.',
        ),
        RestaurantReviewItem(
          author: 'عمر العطار',
          date: '16 أغسطس 2026',
          rating: 5.0,
          comment: 'كباب الباذنجان على السيخ تحفة فنية، متبل الباذنجان المدخن كمان بنصح فيه بشدة.',
        ),
      ];
    }

    // 3. فطاير وفول بوز الجدي
    if (id == 3 || id == 10 || name.contains('بوز الجدي') || name.contains('فول') || name.contains('فلافل') || name.contains('فتات')) {
      return const [
        RestaurantReviewItem(
          author: 'أبو أحمد القيمري',
          date: '28 أغسطس 2026',
          rating: 5.0,
          comment: 'فتة الحمص بالسمنة البلدية المقداحة والصنوبر بتعدل الراس، طعم باب توما الأصيل من قلب دمشق.',
        ),
        RestaurantReviewItem(
          author: 'سليم البابا',
          date: '26 أغسطس 2026',
          rating: 5.0,
          comment: 'المسبحة بزيت الزيتون البكر مع أقراص الفلافل السخنة بالسمسم أحلى فطور جمعة مع العيلة.',
        ),
        RestaurantReviewItem(
          author: 'غادة المرادي',
          date: '24 أغسطس 2026',
          rating: 5.0,
          comment: 'الفول المدمس باللبن والطحينة ناعم ومتبل صح، وفطاير الجبنة المحمرة سخنة وطازة من الفرن.',
        ),
        RestaurantReviewItem(
          author: 'حمزة النحاس',
          date: '21 أغسطس 2026',
          rating: 4.0,
          comment: 'فلافل مقرمشة ونظيفة وما بتشرب زيت، مع الطراطور والمخلل وجبة فطور مثالية وسعر ممتاز.',
        ),
      ];
    }

    // 4. حلويات بكداش التراثية
    if (id == 4 || id == 7 || name.contains('بكداش') || name.contains('bakdash') || name.contains('بوظة')) {
      return const [
        RestaurantReviewItem(
          author: 'سارة ممدوح',
          date: '27 أغسطس 2026',
          rating: 5.0,
          comment: 'بوظة بكداش المدقوقة بالمستكة والسحلب مع طبقة الفستق الحلبي الأخضر بتوصل باردة تماماً بالبوكس الحراري!',
        ),
        RestaurantReviewItem(
          author: 'عمر الفاروق',
          date: '25 أغسطس 2026',
          rating: 5.0,
          comment: 'حلاوة الجبن الحمصية بالقشطة البلدية وقطر ماء الزهر بتدوب بالتم، طعم ولا أروع.',
        ),
        RestaurantReviewItem(
          author: 'رنا الدسوقي',
          date: '23 أغسطس 2026',
          rating: 5.0,
          comment: 'بوظة عربية مع غزل البنات الحريري فكرة خرافية، بنصح الكل يجربها بالصيف.',
        ),
        RestaurantReviewItem(
          author: 'كريم الهواري',
          date: '20 أغسطس 2026',
          rating: 5.0,
          comment: 'صحن القشطة العربية البلدية بالعسل والمكسرات فريش ولذيذ جداً، كواليتي بكداش التاريخي.',
        ),
      ];
    }

    // 5. مقهى النوفرة التراثي
    if (id == 5 || id == 11 || name.contains('نوفرة') || name.contains('النوفرة') || name.contains('مقهى')) {
      return const [
        RestaurantReviewItem(
          author: 'ليلى قاسم',
          date: '27 أغسطس 2026',
          rating: 5.0,
          comment: 'السحلب الشامي بالقرفة وجوز الهند والفستق بيسرسح عالقلب، وقوامه كثيف ومضبوط.',
        ),
        RestaurantReviewItem(
          author: 'رامي السعيد',
          date: '25 أغسطس 2026',
          rating: 5.0,
          comment: 'القهوة الشامية بالمستكة والهيل على الرمل ممتازة، وإبريق الشاي بالنعناع ريحته معبية المكان.',
        ),
        RestaurantReviewItem(
          author: 'نور الهدى',
          date: '23 أغسطس 2026',
          rating: 5.0,
          comment: 'الكركديه المثلج بالليمون منعش جداً بعد المشوار، وبليلة الحمص بالكمون بتدفي بالليل.',
        ),
        RestaurantReviewItem(
          author: 'زياد منصور',
          date: '21 أغسطس 2026',
          rating: 4.0,
          comment: 'تغليف المشروبات الساخنة ممتاز بدون أي تنقيط، أجواء النوفرة التراثية بتوصلك للبيت.',
        ),
      ];
    }

    // 6. كلاسيك برغر الشام
    if (id == 6 || id == 9 || name.contains('برغر الشام') || name.contains('برغر') || name.contains('burger')) {
      return const [
        RestaurantReviewItem(
          author: 'أحمد المصري',
          date: '27 أغسطس 2026',
          rating: 5.0,
          comment: 'برغر اللحم البلدي مع جبنة القشقوان السورية وصوص الشام نكهة مميزة جداً وتغيير عن البرغر التقليدي.',
        ),
        RestaurantReviewItem(
          author: 'ماجد العلي',
          date: '26 أغسطس 2026',
          rating: 5.0,
          comment: 'كرسبي تشيكن سوبريم مقرمش ونظيف جداً، تتبيلة سبايسي ممتازة والتغليف يحافظ على القرمشة.',
        ),
        RestaurantReviewItem(
          author: 'سلمى ناصر',
          date: '24 أغسطس 2026',
          rating: 4.0,
          comment: 'البطاطا اللوديد بجبنة القشقوان السايحة وصوص الشام كميتها كبيرة ومشبعة ولذيذة.',
        ),
      ];
    }

    // 7. حلويات داوود ومهنا
    if (id == 7 || name.contains('داوود') || name.contains('مهنا') || name.contains('بقلاوة') || name.contains('مبرومة')) {
      return const [
        RestaurantReviewItem(
          author: 'الحاج وفيق البزم',
          date: '28 أغسطس 2026',
          rating: 5.0,
          comment: 'المبرومة بالفستق الحلبي بالسمن الحيواني البلدي شغل أكابر، السمن ريحته بتشق القلب والفستق محشي حشو سخي.',
        ),
        RestaurantReviewItem(
          author: 'هند الشربجي',
          date: '26 أغسطس 2026',
          rating: 5.0,
          comment: 'صحن المدلوقة بالقشطة البلدية والوربات السخنة أرقى ضيافة لجمعات العيلة والضيوف.',
        ),
        RestaurantReviewItem(
          author: 'مأمون الحلبي',
          date: '22 أغسطس 2026',
          rating: 5.0,
          comment: 'البرازق والغريبة والمعمول متقنين لأبعد حد، السمن الأصلي باين والكرتونة مغلفة كهدية فخمة.',
        ),
      ];
    }

    // 8. أرت كافيه الشام
    if (id == 8 || name.contains('أرت') || name.contains('art') || name.contains('beans')) {
      return const [
        RestaurantReviewItem(
          author: 'سيرين الخازن',
          date: '27 أغسطس 2026',
          rating: 5.0,
          comment: 'سبانش لاتيه بارد ممتاز مع بن أرابيكا إثيوبي نكهته واضحة وسلسة، أفضل قهوة مختصة بدمشق.',
        ),
        RestaurantReviewItem(
          author: 'عماد الشامي',
          date: '25 أغسطس 2026',
          rating: 5.0,
          comment: 'تشيز كيك التوت الشامي خفيف ومش دسم، والوافل بالنوتيلا والفراولة بيوصل سخن ومقرمش.',
        ),
      ];
    }

    // Generic fallback for any other merchant
    return [
      RestaurantReviewItem(
        author: 'محمد الأحمد',
        date: '26 أغسطس 2026',
        rating: 5.0,
        comment: 'الطلب من ${restaurantData.name} وصل ساخن وسريع جداً، التغليف ممتاز والجودة عالية.',
      ),
      RestaurantReviewItem(
        author: 'سارة خليل',
        date: '24 أغسطس 2026',
        rating: 4.0,
        comment: 'الخدمة ممتازة والمنتجات طازجة ومطابقة للوصف، شكراً جيتك وفريق التوصيل.',
      ),
      RestaurantReviewItem(
        author: 'عبد الرحمن',
        date: '22 أغسطس 2026',
        rating: 5.0,
        comment: 'أفضل تجربة طلب، التوصيل دائماً في الموعد المحدد والتعامل راقي جداً.',
      ),
      RestaurantReviewItem(
        author: 'نور الهدى',
        date: '18 أغسطس 2026',
        rating: 5.0,
        comment: 'كل شيء كان مرتب ومغلف باحترافية، بنصح بالطلب من ${restaurantData.name}.',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final reviews = _restaurantReviews;
    final formattedCount = restaurantData.ratingCount > 999
        ? '+1k'
        : '+${restaurantData.ratingCount}';
    final formattedRating = '${restaurantData.rating}'.replaceAll('.', ',');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button (Circle with RTL-guaranteed Arrow)
                  HeaderCircleButton.back(
                    size: 42,
                    onTap: () => Navigator.pop(context),
                  ),

                  // Top-Right Store Badge (Logo + Rating Pill)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Rating Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '($formattedCount)',
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: const Color(0xFF6B7280),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formattedRating,
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: kCharcoalDark,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              PhosphorIconsFill.star,
                              color: Color(0xFFFFB800),
                              size: 16,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Store Logo Squircle
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: restaurantData.logoUrl.isNotEmpty
                              ? (restaurantData.logoUrl.startsWith('assets')
                                  ? Image.asset(
                                      restaurantData.logoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _buildFallbackLogo(),
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: restaurantData.logoUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => _buildFallbackLogo(),
                                    ))
                              : _buildFallbackLogo(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Heading: "التقييمات"
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'التقييمات',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: kCharcoalDark,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Reviews List
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
                child: ListView.separated(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: reviews.length,
                  separatorBuilder: (_, __) => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(
                      color: Color(0xFFF1F5F9),
                      height: 1,
                      thickness: 1,
                    ),
                  ),
                  itemBuilder: (context, index) {
                    final review = reviews[index];
                    return _buildReviewItem(review);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewItem(RestaurantReviewItem review) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rating Header Row (Right Aligned in RTL)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              review.rating.toStringAsFixed(1),
              style: GoogleFonts.ibmPlexSansArabic(
                color: kCharcoalDark,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              PhosphorIconsFill.star,
              color: Color(0xFFFFB800),
              size: 18,
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Comment Body
        Text(
          review.comment,
          style: GoogleFonts.ibmPlexSansArabic(
            color: const Color(0xFF374151),
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),

        const SizedBox(height: 8),

        // Author Name & Date
        Text(
          '${review.author}, ${review.date}',
          style: GoogleFonts.ibmPlexSansArabic(
            color: const Color(0xFF9CA3AF),
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackLogo() {
    return Container(
      color: const Color(0xFFF3F4F6),
      child: Center(
        child: Text(
          restaurantData.name.isNotEmpty ? restaurantData.name[0] : 'J',
          style: GoogleFonts.ibmPlexSansArabic(
            color: kPrimaryOrange,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}
