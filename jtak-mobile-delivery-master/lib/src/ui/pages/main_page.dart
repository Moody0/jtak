import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import 'package:google_fonts/google_fonts.dart';
import '../../config/themes/colors.dart';
import '../../core/controllers/app_parameters_provider.dart';
import '../../core/controllers/order_provider.dart';
import '../../core/services/authentication_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/locator.dart';
import '../../utils/utilities/global_var.dart';
import '../pages/account/profile_page.dart';
import '../pages/order/orders_page.dart';
import '../pages/setting_page.dart';
import '../pages/transaction/transaction_page.dart';
import '../sections/delivery_bottom_navigation.dart';
import '../sections/drawer.dart';
import '../widgets/app_widgets.dart';
import '../widgets/incoming_order_modal.dart';

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);
  static const String routeName = '/MainPage';
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  Widget homeBody = const OrdersPage();
  String pageTitle = 'الطلبات الحالية';
  bool _checkingLocation = false;
  bool _locationReady = false;
  bool _servicesInitialized = false;
  bool _hasStartedLocationRequest = false;
  String? _locationError;
  LocationAccessIssue? _locationIssue;

  int _currentNavIndex = 0;

  void _onBottomNavChange(int index) {
    if (_currentNavIndex == index) return;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    setState(() {
      _currentNavIndex = index;
      switch (index) {
        case 0:
          homeBody = const OrdersPage();
          pageTitle = isArabic ? 'الطلبات الحالية' : 'Current Orders';
          break;
        case 1:
          homeBody = const TransactionPage();
          pageTitle = isArabic ? 'سجل الحركات المالية' : 'Transactions';
          break;
        case 2:
          homeBody = const ProfilePage();
          pageTitle = isArabic ? 'الملف الشخصي' : 'Profile';
          break;
        case 3:
          homeBody = const SettingPage();
          pageTitle = isArabic ? 'الإعدادات' : 'Settings';
          break;
      }
    });
  }

  void drawerHandler(Widget page, String title) {
    int index = 0;
    if (page is TransactionPage) {
      index = 1;
    } else if (page is ProfilePage) {
      index = 2;
    } else if (page is SettingPage) {
      index = 3;
    }
    setState(() {
      homeBody = page;
      pageTitle = title;
      _currentNavIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Intentionally NOT requested here: firing the OS permission dialog
    // before the driver understands why sinks the grant rate and, once
    // "While using the app" is granted, a raw retry can never reach
    // "Always" on Android 11+ (see requireAlwaysPermission). The rationale
    // screen below primes the request instead of ambushing the driver.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only auto-recheck once the driver has actually engaged with the flow
    // (e.g. they tabbed out to Settings and back) — never before they've
    // seen the rationale and chosen to start it themselves.
    if (state == AppLifecycleState.resumed &&
        _hasStartedLocationRequest &&
        !_locationReady &&
        !_checkingLocation) {
      _ensureLocationAccess();
    }
  }

  Future<void> _ensureLocationAccess() async {
    if (_checkingLocation || _locationReady) return;
    _checkingLocation = true;
    _hasStartedLocationRequest = true;
    if (mounted) {
      setState(() {
        _locationError = null;
        _locationIssue = null;
      });
    }

    try {
      await LocationService(isMandatory: true).requireAlwaysPermission();
      await locator<OrderProvider>().startLocationTracking();
      await locator<OrderProvider>().fetchShiftStatus();
      if (!_servicesInitialized && mounted) {
        _servicesInitialized = true;
        locator<AppParametersProvider>().initServices(context);
      }
      if (mounted) {
        setState(() {
          _locationReady = true;
          _locationError = null;
          _locationIssue = null;
        });
      }
    } on LocationAccessException catch (error) {
      if (mounted) {
        setState(() {
          _locationReady = false;
          _locationError = error.message;
          _locationIssue = error.issue;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _locationReady = false;
          _locationError = error.toString().replaceFirst('Exception: ', '');
          _locationIssue = null;
        });
      }
    } finally {
      _checkingLocation = false;
    }
  }


  @override
  Widget build(BuildContext context) {
    if (!_locationReady) return _locationGate(context);

    final orderProv = Provider.of<OrderProvider>(context);

    if (orderProv.incomingOrderAlert != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && orderProv.incomingOrderAlert != null) {
          final alertOrder = orderProv.incomingOrderAlert!;
          orderProv.dismissIncomingOrderAlert();
          IncomingOrderModal.show(context, alertOrder);
        }
      });
    }

    final isHome = _currentNavIndex == 0;
    return PopScope(
      canPop: isHome,
      onPopInvokedWithResult: (didPop, dynamic _) {
        if (didPop) return;
        if (!isHome) {
          _onBottomNavChange(0);
        }
      },
      child: Scaffold(
        appBar: _appBar(context),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: homeBody,
          ),
        ),
        drawer: HomeDrawer(drawerHandler, currentPage: pageTitle),
        bottomNavigationBar: DeliveryBottomNavigation(
          currentIndex: _currentNavIndex,
          onChange: _onBottomNavChange,
        ),
      ),
    );
  }

  Widget _locationGate(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: _hasStartedLocationRequest
                ? _locationStatusCard(isArabic)
                : _locationRationaleCard(isArabic),
          ),
        ),
      ),
    );
  }

  /// Shown once, before the OS permission dialog ever appears. Priming the
  /// driver with *why* the app needs continuous location — instead of
  /// ambushing them with a system prompt on first launch — measurably
  /// improves grant rates and avoids the driver reflexively tapping "Deny".
  Widget _locationRationaleCard(bool isArabic) {
    final reasons = <(IconData, String, String)>[
      (
        PhosphorIcons.packageBold,
        isArabic ? 'استلام الطلبات القريبة منك فوراً' : 'Get nearby orders the instant they open',
        isArabic
            ? 'نستخدم موقعك لعرض الطلبات القريبة منك أولاً.'
            : 'We use your position to surface the closest orders first.',
      ),
      (
        PhosphorIcons.navigationArrowBold,
        isArabic ? 'مشاركة موقعك الحي مع العميل' : 'Share live location with the customer',
        isArabic
            ? 'يتتبّع العميل توصيله لحظة بلحظة أثناء الطريق.'
            : 'Customers track their delivery in real time while it\'s on the way.',
      ),
      (
        PhosphorIcons.clockBold,
        isArabic ? 'مسافة ووقت وصول دقيقين' : 'Accurate distance & arrival estimates',
        isArabic
            ? 'حساب المسافة والوقت المتوقع يعتمد على موقعك الفعلي.'
            : 'Distance and ETA on every order are computed from your real position.',
      ),
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(
            color: Color(0xFFFFF0E8),
            shape: BoxShape.circle,
          ),
          child: const Icon(PhosphorIcons.mapPinBold, color: kPrimaryOrange, size: 40),
        ),
        const SizedBox(height: 24),
        Text(
          isArabic ? 'لماذا نحتاج موقعك؟' : 'Why we need your location',
          textAlign: TextAlign.center,
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 20),
        ...reasons.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0E8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(r.$1, color: kPrimaryOrange, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.$2,
                        textAlign: TextAlign.start,
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r.$3,
                        textAlign: TextAlign.start,
                        style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12.5, height: 1.4, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _checkingLocation ? null : _ensureLocationAccess,
            icon: _checkingLocation
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.location_on_rounded),
            label: Text(
              isArabic ? 'متابعة وتفعيل الموقع' : 'Continue & enable location',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  /// Shown after the driver has engaged with the flow at least once. The
  /// icon, message and — crucially — the single primary action are picked
  /// per [LocationAccessIssue] so the button always does something that can
  /// actually resolve the state, instead of one generic "try again" that
  /// silently does nothing once Android has already decided it won't show
  /// the "Allow all the time" dialog a second time.
  Widget _locationStatusCard(bool isArabic) {
    IconData icon = PhosphorIcons.mapPinBold;
    Color iconColor = kPrimaryOrange;
    Color iconBg = const Color(0xFFFFF0E8);
    String title = isArabic ? 'الموقع مطلوب للتوصيل' : 'Location is required';
    bool primaryOpensSettings = false;
    List<String> steps = const [];

    switch (_locationIssue) {
      case LocationAccessIssue.serviceDisabled:
        icon = Icons.location_off_rounded;
        iconColor = kRed;
        iconBg = const Color(0xFFFEE2E2);
        title = isArabic ? 'خدمة الموقع غير مفعّلة' : 'Location services are off';
        primaryOpensSettings = true;
        break;
      case LocationAccessIssue.permissionDenied:
        title = isArabic ? 'صلاحية الموقع مطلوبة' : 'Location permission needed';
        primaryOpensSettings = false;
        break;
      case LocationAccessIssue.permissionDeniedForever:
        icon = Icons.location_disabled_rounded;
        iconColor = kRed;
        iconBg = const Color(0xFFFEE2E2);
        title = isArabic ? 'تم حظر إذن الموقع' : 'Location permission blocked';
        primaryOpensSettings = true;
        break;
      case LocationAccessIssue.needsAlwaysUpgrade:
        icon = Icons.my_location_rounded;
        title = isArabic ? 'خطوة أخيرة لإكمال الإعداد' : 'One last step to finish setup';
        primaryOpensSettings = true;
        steps = isArabic
            ? [
                'افتح إعدادات التطبيق',
                'اذهب إلى الأذونات ثم الموقع',
                'اختر «السماح طوال الوقت»',
              ]
            : [
                'Open app settings',
                'Go to Permissions, then Location',
                'Select "Allow all the time"',
              ];
        break;
      case null:
        primaryOpensSettings = false;
        break;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 40),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(
          _locationError ??
              (isArabic
                  ? 'يجب السماح بالموقع دائماً وتشغيل GPS لاستلام الطلبات ومشاركة موقعك أثناء التوصيل.'
                  : 'Always-on location and GPS are required to receive orders and share your position during delivery.'),
          textAlign: TextAlign.center,
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 14, height: 1.5, color: const Color(0xFF64748B)),
        ),
        if (steps.isNotEmpty) ...[
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: steps.asMap().entries.map((e) {
                return Padding(
                  padding: EdgeInsets.only(bottom: e.key == steps.length - 1 ? 0 : 8),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(color: kPrimaryOrange, shape: BoxShape.circle),
                        child: Text(
                          '${e.key + 1}',
                          style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e.value,
                          textAlign: TextAlign.start,
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _checkingLocation
                ? null
                : (primaryOpensSettings
                    ? () => LocationService().openRequiredSettings()
                    : _ensureLocationAccess),
            icon: _checkingLocation
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(primaryOpensSettings ? Icons.settings_rounded : Icons.location_on_rounded),
            label: Text(
              primaryOpensSettings
                  ? (isArabic ? 'فتح إعدادات التطبيق' : 'Open app settings')
                  : (isArabic ? 'السماح بالموقع' : 'Allow location'),
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (primaryOpensSettings) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: _checkingLocation ? null : _ensureLocationAccess,
            child: Text(
              isArabic ? 'تحقق مرة أخرى' : 'Check again',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }

  AppBar _appBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isHomePage = pageTitle == 'الطلبات الحالية' || pageTitle == 'Current Orders';

    return AppBar(
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      titleSpacing: 0,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                  width: 1),
            ),
            child: AppIcon(PhosphorIcons.listBold,
                size: 20, color: isDark ? Colors.white : kCharcoalDark),
          ),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: isHomePage
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 32,
                  errorBuilder: (_, __, ___) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(PhosphorIcons.mopedBold, color: kPrimaryOrange, size: 24),
                      const SizedBox(width: 6),
                      Text(
                        'جيتك',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: kCharcoalDark,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: kSurfaceWarm,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isArabic ? 'سائق' : 'Driver',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: kPrimaryOrange,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            )
          : Text(
              pageTitle,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : kCharcoalDark,
              ),
            ),
      centerTitle: true,
      actions: [
        Consumer<AuthenticationService>(
          builder: (context, auth, _) {
            final user = auth.user;
            final photo = user?.profilePhoto;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: photo != null && photo.isNotEmpty
                        ? Image.network(
                            photo.startsWith('http') ? photo : GlobalVar.getImageUrl(photo),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildAvatarFallback(user?.fullName),
                          )
                        : _buildAvatarFallback(user?.fullName),
                  ),
                ),
              ),
            );
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), height: 1),
      ),
    );
  }

  Widget _buildAvatarFallback(String? name) {
    final initial = (name != null && name.trim().isNotEmpty)
        ? name.trim().substring(0, 1)
        : 'س';
    return Container(
      color: const Color(0xFFFFF0E8),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.ibmPlexSansArabic(
          color: kPrimaryOrange,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    );
  }
}
