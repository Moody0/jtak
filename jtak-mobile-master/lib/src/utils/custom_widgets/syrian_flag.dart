import 'dart:math';
import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// Syrian Independence / Revolution Flag Widget (علم الاستقلال السوري)
///
/// Features:
/// - Three horizontal stripes: Green (top), White (middle), Black (bottom)
/// - Three red 5-pointed stars in the middle white stripe
/// - Resolution-independent, vector-rendered CustomPaint (crisp on any screen)
/// ---------------------------------------------------------------------------
class SyrianFlag extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final bool withBorder;

  const SyrianFlag({
    super.key,
    this.width = 24.0,
    this.height = 16.0,
    this.borderRadius = 2.5,
    this.withBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: withBorder
            ? Border.all(color: const Color(0x1F000000), width: 0.6)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius > 0.6 ? borderRadius - 0.6 : 0),
        child: CustomPaint(
          size: Size(width, height),
          painter: const _SyrianFlagPainter(),
        ),
      ),
    );
  }
}

class _SyrianFlagPainter extends CustomPainter {
  const _SyrianFlagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double stripeHeight = size.height / 3.0;

    // 1. Top Stripe: Syrian Independence Green (#007A3D)
    final greenPaint = Paint()..color = const Color(0xFF007A3D);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, stripeHeight), greenPaint);

    // 2. Middle Stripe: Pure White (#FFFFFF)
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, stripeHeight, size.width, stripeHeight), whitePaint);

    // 3. Bottom Stripe: Black (#000000)
    final blackPaint = Paint()..color = const Color(0xFF111111);
    canvas.drawRect(Rect.fromLTWH(0, stripeHeight * 2, size.width, stripeHeight), blackPaint);

    // 4. Three 5-Pointed Red Stars (#D31411) in Middle White Band
    final redPaint = Paint()
      ..color = const Color(0xFFD31411)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final double centerY = stripeHeight * 1.5;
    // Outer radius is roughly 38% of stripe height so it fits comfortably
    final double outerR = stripeHeight * 0.38;
    final double innerR = outerR * sin(pi / 10) / cos(pi / 5);

    final double leftX = size.width * 0.27;
    final double midX = size.width * 0.50;
    final double rightX = size.width * 0.73;

    canvas.drawPath(_drawStar(leftX, centerY, outerR, innerR), redPaint);
    canvas.drawPath(_drawStar(midX, centerY, outerR, innerR), redPaint);
    canvas.drawPath(_drawStar(rightX, centerY, outerR, innerR), redPaint);
  }

  Path _drawStar(double cx, double cy, double outerRadius, double innerRadius) {
    final path = Path();
    const double step = pi / 5.0;
    // Pointing straight up (-pi / 2)
    double angle = -pi / 2.0;

    for (int i = 0; i < 5; i++) {
      final x1 = cx + outerRadius * cos(angle);
      final y1 = cy + outerRadius * sin(angle);
      if (i == 0) {
        path.moveTo(x1, y1);
      } else {
        path.lineTo(x1, y1);
      }
      angle += step;

      final x2 = cx + innerRadius * cos(angle);
      final y2 = cy + innerRadius * sin(angle);
      path.lineTo(x2, y2);
      angle += step;
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
