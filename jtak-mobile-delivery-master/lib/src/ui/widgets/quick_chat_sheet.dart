import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/themes/colors.dart';
import '../../ui/widgets/app_widgets.dart';
import '../../utils/custom_widgets/messages.dart';

class QuickChatSheet extends StatelessWidget {
  final String customerPhone;
  final String customerName;

  const QuickChatSheet({
    required this.customerPhone,
    required this.customerName,
    Key? key,
  }) : super(key: key);

  static void show(BuildContext context, {required String customerPhone, required String customerName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickChatSheet(
        customerPhone: customerPhone,
        customerName: customerName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final cannedMessages = [
      {
        'title': isArabic ? '📍 أنا في الأسفل' : '📍 Arrived Downstairs',
        'text': isArabic
            ? 'مرحباً، مندوب توصيل جيتك وصل وهو الآن في الأسفل عند البناء.'
            : 'Hello, your JTak delivery captain has arrived downstairs at your building.',
        'icon': PhosphorIcons.mapPinBold,
      },
      {
        'title': isArabic ? '🚪 اللقاء عند المدخل' : '🚪 Meet at Entrance',
        'text': isArabic
            ? 'مرحباً، أرجو اللقاء عند المدخل الرئيسي لاستلام الطلب وشكراً.'
            : 'Hello, please meet me at the main entrance to receive your order. Thank you.',
        'icon': PhosphorIcons.doorBold,
      },
      {
        'title': isArabic ? '⏳ تأخير 5 دقائق (ازدحام)' : '⏳ Traffic Delay (~5 mins)',
        'text': isArabic
            ? 'مرحباً، هناك ازدحام مروري بسيط وسأصل إليكم خلال 5 دقائق إن شاء الله.'
            : 'Hello, slight traffic delay on the route. Arriving in approximately 5 minutes.',
        'icon': PhosphorIcons.clockBold,
      },
      {
        'title': isArabic ? '📦 تم وضع الطلب عند الباب' : '📦 Left at Doorstep',
        'text': isArabic
            ? 'مرحباً، تم وضع طلبكم عند الباب كما تم الاتفاق. بالهناء والشفاء!'
            : 'Hello, your order has been safely placed at your doorstep as requested. Enjoy!',
        'icon': PhosphorIcons.packageBold,
      },
    ];

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF475569) : Colors.grey.shade300,
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
                  color: isDark ? const Color(0xFF334155) : kSurfaceWarm,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const AppIcon(PhosphorIcons.chatTeardropDotsBold, size: 22, color: kPrimaryOrange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'رسائل سريعة للعميل' : 'Quick Customer Messages',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : kCharcoalDark,
                      ),
                    ),
                    Text(
                      customerName,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Divider(height: 1, color: isDark ? const Color(0xFF334155) : kBorderColor),
          const SizedBox(height: 12),

          // List of canned messages
          ...cannedMessages.map((item) {
            final title = item['title'] as String;
            final text = item['text'] as String;
            final icon = item['icon'] as IconData;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : kPageBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF334155) : kBorderColor),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: AppIcon(icon, size: 20, color: kPrimaryOrange),
                title: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : kCharcoalDark,
                  ),
                ),
                subtitle: Text(
                  text,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                    height: 1.3,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // WhatsApp Button
                    IconButton(
                      icon: const AppIcon(PhosphorIcons.whatsappLogoBold, color: Color(0xFF25D366), size: 22),
                      tooltip: 'WhatsApp',
                      onPressed: () => _sendWhatsApp(context, text),
                    ),
                    // SMS Button
                    IconButton(
                      icon: const AppIcon(PhosphorIcons.paperPlaneTiltBold, color: kPrimaryOrange, size: 20),
                      tooltip: 'SMS',
                      onPressed: () => _sendSms(context, text),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  void _sendWhatsApp(BuildContext context, String message) async {
    Navigator.of(context).pop();
    final cleanPhone = customerPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _sendSms(context, message);
      }
    } catch (e) {
      showDialog(context: context, builder: (ctx) => CustomDialog(message: e.toString()));
    }
  }

  void _sendSms(BuildContext context, String message) async {
    Navigator.of(context).pop();
    final cleanPhone = customerPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('sms:$cleanPhone?body=${Uri.encodeComponent(message)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      showDialog(context: context, builder: (ctx) => CustomDialog(message: e.toString()));
    }
  }
}
