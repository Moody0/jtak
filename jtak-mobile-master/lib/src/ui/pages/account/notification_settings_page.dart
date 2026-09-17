import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/themes/colors.dart';
import '../../../core/controllers/app_parameters_provider.dart';
import '../../../core/services/locator.dart';
import '../../widgets/header_circle_button.dart';

/// ---------------------------------------------------------------------------
/// JTAK Notification Settings Page (إعدادات الإشعارات والتنبيهات)
/// Allows user to toggle and persist preferences for:
/// - Order status updates
/// - Promotional offers & discounts
/// - System & service announcements
/// ---------------------------------------------------------------------------

class NotificationSettingsPage extends StatefulWidget {
  static const String routeName = '/NotificationSettingsPage';

  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  static const String _keyOrders = 'pref_notify_orders';
  static const String _keyPromotions = 'pref_notify_promotions';
  static const String _keySystem = 'pref_notify_system';

  bool _notifyOrders = true;
  bool _notifyPromotions = true;
  bool _notifySystem = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notifyOrders = prefs.getBool(_keyOrders) ?? true;
        _notifyPromotions = prefs.getBool(_keyPromotions) ?? true;
        _notifySystem = prefs.getBool(_keySystem) ?? true;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _setPreference(String key, bool value) async {
    HapticFeedback.lightImpact();
    setState(() {
      if (key == _keyOrders) _notifyOrders = value;
      if (key == _keyPromotions) _notifyPromotions = value;
      if (key == _keySystem) _notifySystem = value;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);

      // Manage topic subscription if applicable
      if (locator.isRegistered<AppParametersProvider>()) {
        final notifService = locator<AppParametersProvider>().notificationServices;
        if (key == _keyPromotions) {
          if (value) {
            notifService.subscribeToTopic('promotions');
          } else {
            notifService.unsubscribeFromTopic('promotions');
          }
        } else if (key == _keySystem) {
          if (value) {
            notifService.subscribeToTopic('all');
          } else {
            notifService.unsubscribeFromTopic('all');
          }
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          'إعدادات الإشعارات',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: kCharcoalDark,
          ),
        ),
        leading: HeaderCircleButton.back(
          onTap: () => Navigator.pop(context),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF1F5F9), thickness: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryOrange))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              physics: const ClampingScrollPhysics(),
              children: [
                // Info description banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0E8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFD8C2), width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          PhosphorIconsFill.bellRinging,
                          color: kPrimaryOrange,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'تحكّم بالتنبيهات التي ترغب باستلامها للبقاء على اطلاع بطلباتك وأحدث العروض.',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF7C2D12),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Settings Group
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                  ),
                  child: Column(
                    children: [
                      _buildSwitchTile(
                        icon: PhosphorIconsFill.shoppingBagOpen,
                        iconColor: const Color(0xFF3B82F6),
                        iconBg: const Color(0xFFEFF6FF),
                        title: 'تحديثات الطلبات والتوصيل',
                        subtitle: 'إشعارات مباشرة عند تأكيد الطلب، تحضيره، ووصول المندوب',
                        value: _notifyOrders,
                        onChanged: (val) => _setPreference(_keyOrders, val),
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 56),
                      _buildSwitchTile(
                        icon: PhosphorIconsFill.tag,
                        iconColor: const Color(0xFF10B981),
                        iconBg: const Color(0xFFECFDF5),
                        title: 'العروض والخصومات الحصرية',
                        subtitle: 'تنبيهات بالعروض اليومية وأكواد الخصم الجديدة',
                        value: _notifyPromotions,
                        onChanged: (val) => _setPreference(_keyPromotions, val),
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 56),
                      _buildSwitchTile(
                        icon: PhosphorIconsFill.megaphone,
                        iconColor: const Color(0xFFF59E0B),
                        iconBg: const Color(0xFFFFFBEB),
                        title: 'تنبيهات النظام والخدمة',
                        subtitle: 'إشعارات الصيانة الدورية وتحديثات التطبيق الهامة',
                        value: _notifySystem,
                        onChanged: (val) => _setPreference(_keySystem, val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kCharcoalDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            activeColor: kPrimaryOrange,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
