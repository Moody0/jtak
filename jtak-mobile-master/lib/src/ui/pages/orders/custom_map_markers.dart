import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// ---------------------------------------------------------------------------
/// Premium Live Navigation Markers for JTAK (Modern Tech / Navigation Style)
/// - Completely redesigned from scratch: High-contrast Slate & Orange styling
/// - Delivery Courier: Obsidian Slate Puck with pure white rim & Electric Orange Navigation Arrow
/// - Customer Destination: Floating White Badge with Dark Slate rim & Electric Orange Location Pin
/// - Ultra-compact (22x22 dp) with high-DPI rasterization (zero blur, zero bloat)
/// ---------------------------------------------------------------------------

class CustomMapMarkers {
  // Both markers are centered for exact coordinate alignment
  static const Offset courierAnchor = Offset(0.5, 0.5);
  static const Offset customerAnchor = Offset(0.5, 0.5);
  static const Offset pinAnchor = Offset(0.5, 0.5);

  /// Ultra-compact logical display size on screen (in dp)
  static const double markerDisplaySize = 22.0;

  /// 1. Delivery Driver Marker:
  /// Modern Obsidian Slate Navigation Puck with crisp white rim and Electric Orange Navigation Arrow
  static Future<BitmapDescriptor> getCourierMarker() async {
    try {
      const double canvasSize = 64.0;
      const double displaySize = markerDisplaySize;
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, canvasSize, canvasSize));

      const center = Offset(canvasSize / 2, canvasSize / 2);

      // 1. Subtle Dark Ambient Drop Shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5)
        ..isAntiAlias = true;
      canvas.drawCircle(center.translate(0, 1.2), 26.0, shadowPaint);

      // 2. Crisp Solid White Outer Rim
      final whiteRim = Paint()
        ..color = Colors.white
        ..isAntiAlias = true;
      canvas.drawCircle(center, 26.0, whiteRim);

      // 3. Deep Obsidian Slate Core Body
      final slateCore = Paint()
        ..shader = ui.Gradient.linear(
          Offset(center.dx, center.dy - 22),
          Offset(center.dx, center.dy + 22),
          [const Color(0xFF1E293B), const Color(0xFF0F172A)],
        )
        ..isAntiAlias = true;
      canvas.drawCircle(center, 22.0, slateCore);

      // 4. Electric Brand Orange Navigation Arrow in Center
      final iconPainter = TextPainter(textDirection: TextDirection.ltr);
      iconPainter.text = TextSpan(
        text: String.fromCharCode(Icons.navigation_rounded.codePoint),
        style: TextStyle(
          fontSize: 26.0,
          fontFamily: Icons.navigation_rounded.fontFamily,
          package: Icons.navigation_rounded.fontPackage,
          color: const Color(0xFFFF5400),
        ),
      );
      iconPainter.layout();
      iconPainter.paint(
        canvas,
        Offset(
          center.dx - iconPainter.width / 2,
          center.dy - iconPainter.height / 2,
        ),
      );

      final ui.Image image = await recorder.endRecording().toImage(canvasSize.toInt(), canvasSize.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return BitmapDescriptor.bytes(
        byteData!.buffer.asUint8List(),
        width: displaySize,
        height: displaySize,
        imagePixelRatio: canvasSize / displaySize,
      );
    } catch (_) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
  }

  /// 2. Customer Destination Marker:
  /// Modern Floating White Waypoint Badge with Dark Slate Rim and Electric Orange Location Pin
  static Future<BitmapDescriptor> getCustomerMarker() async {
    try {
      const double canvasSize = 64.0;
      const double displaySize = markerDisplaySize;
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, canvasSize, canvasSize));

      const center = Offset(canvasSize / 2, canvasSize / 2);

      // 1. Subtle Dark Ambient Drop Shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5)
        ..isAntiAlias = true;
      canvas.drawCircle(center.translate(0, 1.2), 26.0, shadowPaint);

      // 2. Deep Slate Dark Outer Rim
      final slateRim = Paint()
        ..color = const Color(0xFF0F172A)
        ..isAntiAlias = true;
      canvas.drawCircle(center, 26.0, slateRim);

      // 3. Crisp Pure White Core Disc
      final whiteDisc = Paint()
        ..color = Colors.white
        ..isAntiAlias = true;
      canvas.drawCircle(center, 22.0, whiteDisc);

      // 4. Electric Brand Orange Location Pin in Center
      final iconPainter = TextPainter(textDirection: TextDirection.ltr);
      iconPainter.text = TextSpan(
        text: String.fromCharCode(Icons.location_on_rounded.codePoint),
        style: TextStyle(
          fontSize: 25.0,
          fontFamily: Icons.location_on_rounded.fontFamily,
          package: Icons.location_on_rounded.fontPackage,
          color: const Color(0xFFFF5400),
        ),
      );
      iconPainter.layout();
      iconPainter.paint(
        canvas,
        Offset(
          center.dx - iconPainter.width / 2,
          center.dy - iconPainter.height / 2,
        ),
      );

      final ui.Image image = await recorder.endRecording().toImage(canvasSize.toInt(), canvasSize.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return BitmapDescriptor.bytes(
        byteData!.buffer.asUint8List(),
        width: displaySize,
        height: displaySize,
        imagePixelRatio: canvasSize / displaySize,
      );
    } catch (_) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
  }

  /// 3. Merchant Stop Marker
  static Future<BitmapDescriptor> getMerchantMarker() async {
    try {
      return await getCustomerMarker();
    } catch (_) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
  }
}
