import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../main_imports.dart';
import '../../config/themes/colors.dart';
import '../../core/controllers/app/app_state_manager.dart';
import '../../core/services/authentication_service.dart';
import '../../core/services/locator.dart';
import '../../utils/custom_widgets/messages.dart';
import '../../utils/utilities/global_var.dart';
import '../pages/account/login_page.dart';
import '../pages/account/profile_page.dart';
import '../pages/order/orders_page.dart';
import '../pages/setting_page.dart';
import '../pages/transaction/transaction_page.dart';

class HomeDrawer extends StatefulWidget {
  final Function drawerHandler;
  final String currentPage;

  const HomeDrawer(this.drawerHandler, {this.currentPage = 'الطلبات الحالية', Key? key}) : super(key: key);

  @override
  _HomeDrawerState createState() => _HomeDrawerState();
}

class _HomeDrawerState extends State<HomeDrawer> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 0,
      child: Column(
        children: [
          _buildDriverHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              children: [
                _buildNavItem(
                  context: context,
                  icon: PhosphorIcons.mopedBold,
                  text: str.main.home.isNotEmpty ? (Provider.of<AppStateManager>(context).appLanguageIsArabic ? 'الطلبات الحالية' : 'Current Orders') : 'الطلبات الحالية',
                  isSelected: widget.currentPage == 'الطلبات الحالية' || widget.currentPage == 'Current Orders' || widget.currentPage.contains('الطلبات') || widget.currentPage.contains('Orders'),
                  onTap: () {
                    Navigator.pop(context);
                    widget.drawerHandler(const OrdersPage(), Provider.of<AppStateManager>(context, listen: false).appLanguageIsArabic ? 'الطلبات الحالية' : 'Current Orders');
                  },
                ),
                _buildNavItem(
                  context: context,
                  icon: PhosphorIcons.receiptBold,
                  text: Provider.of<AppStateManager>(context).appLanguageIsArabic ? 'سجل الحركات المالية' : 'Transactions',
                  isSelected: widget.currentPage == 'سجل الحركات المالية' || widget.currentPage == 'Transactions' || widget.currentPage.contains('الحركات'),
                  onTap: () {
                    Navigator.pop(context);
                    widget.drawerHandler(const TransactionPage(), Provider.of<AppStateManager>(context, listen: false).appLanguageIsArabic ? 'سجل الحركات المالية' : 'Transactions');
                  },
                ),
                _buildNavItem(
                  context: context,
                  icon: PhosphorIcons.userCircleBold,
                  text: Provider.of<AppStateManager>(context).appLanguageIsArabic ? 'الملف الشخصي' : 'Profile',
                  isSelected: widget.currentPage == 'الملف الشخصي' || widget.currentPage == 'Profile' || widget.currentPage.contains('الملف'),
                  onTap: () {
                    Navigator.pop(context);
                    context.navigateName(ProfilePage.routeName);
                  },
                ),
                _buildNavItem(
                  context: context,
                  icon: PhosphorIcons.gearBold,
                  text: Provider.of<AppStateManager>(context).appLanguageIsArabic ? 'الإعدادات' : 'Settings',
                  isSelected: widget.currentPage == 'الإعدادات' || widget.currentPage == 'Settings' || widget.currentPage.contains('الإعدادات'),
                  onTap: () {
                    Navigator.pop(context);
                    context.navigateName(SettingPage.routeName);
                  },
                ),
              ],
            ),
          ),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildDriverHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<AuthenticationService>(
      builder: (context, auth, child) {
        final user = auth.user;
        final isArabic = Provider.of<AppStateManager>(context).appLanguageIsArabic;

        return Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 20,
            bottom: 20,
            left: 20,
            right: 20,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : kSurfaceWarm,
            border: Border(
              bottom: BorderSide(color: isDark ? const Color(0xFF334155) : kBorderColor, width: 1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: kPrimaryOrange, width: 2),
                ),
                child: const Center(
                  child: AppIcon(
                    PhosphorIcons.userBold,
                    color: kPrimaryOrange,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user?.fullName != null && user!.fullName!.isNotEmpty
                          ? user.fullName!
                          : (isArabic ? 'كابتن التوصيل' : 'Delivery Captain'),
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : kCharcoalDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (user?.phoneNumber != null && user!.phoneNumber!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        user.phoneNumber!,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : kCharcoalMuted,
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Provider.of<AppStateManager>(context).appLanguageIsArabic;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? const Color(0xFF334155) : kSurfaceWarm)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: kPrimaryOrange.withOpacity(0.35), width: 1.1)
            : Border.all(color: Colors.transparent, width: 1.1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                AppIcon(
                  icon,
                  size: 22,
                  color: isSelected ? kPrimaryOrange : (isDark ? const Color(0xFF94A3B8) : kCharcoalMedium),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    text,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? kPrimaryOrange : (isDark ? Colors.white : kCharcoalDark),
                    ),
                  ),
                ),
                AppIcon(
                  isArabic ? PhosphorIcons.caretLeftBold : PhosphorIcons.caretRightBold,
                  size: 14,
                  color: isSelected ? kPrimaryOrange : (isDark ? const Color(0xFF64748B) : kCharcoalLight),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Provider.of<AppStateManager>(context).appLanguageIsArabic;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 12,
        top: 12,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : kBorderColor, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              icon: const AppIcon(PhosphorIcons.signOutBold, size: 18, color: kRed),
              label: Text(
                isArabic ? 'تسجيل الخروج' : 'Logout',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: kRed,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              onPressed: () => _confirmLogout(context),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => CustomConfirmationDialog(
        title: Provider.of<AppStateManager>(context, listen: false).appLanguageIsArabic ? 'تسجيل الخروج' : 'Logout',
        message: Provider.of<AppStateManager>(context, listen: false).appLanguageIsArabic
            ? 'هل أنت متأكد من رغبتك في تسجيل الخروج من التطبيق؟'
            : 'Are you sure you want to logout from the app?',
        yesBTNCallBack: () async {
          Navigator.pop(context);
          await locator<AuthenticationService>().logOut();
          context.navigateToReset(LoginPage.routeName);
        },
      ),
    );
  }
}
