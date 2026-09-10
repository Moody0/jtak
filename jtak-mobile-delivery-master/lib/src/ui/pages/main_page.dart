import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../config/themes/colors.dart';
import '../../core/controllers/app_parameters_provider.dart';
import '../../core/controllers/order_provider.dart';
import '../../core/services/location_service.dart';
import '../../core/services/locator.dart';
import '../pages/order/orders_page.dart';
import '../sections/drawer.dart';
import '../widgets/app_widgets.dart';

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
  String? _locationError;

  void drawerHandler(Widget page, String title) {
    setState(() {
      homeBody = page;
      pageTitle = title;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureLocationAccess();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_locationReady && !_checkingLocation) {
      _ensureLocationAccess();
    }
  }

  Future<void> _ensureLocationAccess() async {
    if (_checkingLocation || _locationReady) return;
    _checkingLocation = true;
    if (mounted) {
      setState(() {
        _locationError = null;
      });
    }

    try {
      await LocationService(isMandatory: true).requireAlwaysPermission();
      await locator<OrderProvider>().startLocationTracking();
      if (!_servicesInitialized && mounted) {
        _servicesInitialized = true;
        locator<AppParametersProvider>().initServices(context);
      }
      if (mounted) {
        setState(() {
          _locationReady = true;
          _locationError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _locationReady = false;
          _locationError = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      _checkingLocation = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_locationReady) return _locationGate(context);

    return WillPopScope(
      onWillPop: () {
        if (pageTitle != 'الطلبات الحالية' && pageTitle != 'Current Orders') {
          setState(() {
            homeBody = const OrdersPage();
            pageTitle = 'الطلبات الحالية';
          });
          return Future.value(false);
        }
        return Future.value(true);
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF0E8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    PhosphorIcons.mapPinBold,
                    color: kPrimaryOrange,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isArabic ? 'الموقع مطلوب للتوصيل' : 'Location is required',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text(
                  _locationError ??
                      (isArabic
                          ? 'يجب السماح بالموقع دائماً وتشغيل GPS لاستلام الطلبات ومشاركة موقعك أثناء التوصيل.'
                          : 'Always-on location and GPS are required to receive orders and share your position during delivery.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, height: 1.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _checkingLocation ? null : _ensureLocationAccess,
                    icon: _checkingLocation
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.location_on_rounded),
                    label: Text(isArabic ? 'السماح بالموقع' : 'Allow location'),
                  ),
                ),
                if (_locationError != null) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => LocationService().openRequiredSettings(),
                    child: Text(isArabic ? 'فتح الإعدادات' : 'Open settings'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  AppBar _appBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    String displayTitle = pageTitle;
    if (!isArabic) {
      if (pageTitle == 'الطلبات الحالية') displayTitle = 'Current Orders';
      if (pageTitle == 'سجل الحركات المالية') displayTitle = 'Transactions';
    } else {
      if (pageTitle == 'Current Orders') displayTitle = 'الطلبات الحالية';
      if (pageTitle == 'Transactions') displayTitle = 'سجل الحركات المالية';
    }

    return AppBar(
      elevation: 0,
      titleSpacing: 0,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : kPageBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isDark ? const Color(0xFF475569) : kBorderColor,
                  width: 1),
            ),
            child: AppIcon(PhosphorIcons.listBold,
                size: 20, color: isDark ? Colors.white : kCharcoalDark),
          ),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Text(
        displayTitle,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : kCharcoalDark,
        ),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
            color: isDark ? const Color(0xFF334155) : kBorderColor, height: 1),
      ),
    );
  }
}
