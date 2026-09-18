import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../main_imports.dart';
import '../../config/constants/constants.dart';
import '../../config/themes/colors.dart';
import '../../core/services/app_global_initializer.dart';
import 'main_page.dart';

class SplashPage extends StatefulWidget {
  static const String routeName = '/SplashPage';
  const SplashPage({Key? key}) : super(key: key);
  @override
  _SplashPageState createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _animController.forward();
    _initAppState();
  }

  void _initAppState() async {
    try {
      await Future.wait([
        AppGlobalInitializer.appLoadMainData(context).timeout(const Duration(seconds: 4), onTimeout: () {}),
        Future.delayed(const Duration(milliseconds: 1200)),
      ]);
    } catch (_) {
      // Gracefully continue to main page on any timeout or network delay
    } finally {
      if (mounted) {
        context.pushReplacementNamed(MainPage.routeName);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Subtle warm glow in center
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kPrimaryOrange.withOpacity(0.04),
              ),
            ),
          ),

          Center(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacityAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          kLogo,
                          width: context.width * 0.45,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: kSurfaceWarm,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: kPrimaryOrange.withOpacity(0.3), width: 1),
                          ),
                          child: const Text(
                            'تطبيق السائقين و التوصيل',
                            style: TextStyle(
                              color: kPrimaryOrange,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          Positioned(
            bottom: 36,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(kPrimaryOrange.withOpacity(0.7)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
}
