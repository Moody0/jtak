import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../config/constants/constants.dart';
import '../../config/themes/colors.dart';
import '../utilities/global_var.dart';

/// ---------------------------------------------------------------------------
/// Full-Screen Expanded Image & Gallery Viewer
///
/// Provides interactive pinch-to-zoom, double-tap zoom, pan, hero transition,
/// swipe-down to dismiss, frosted navigation controls, and bulletproof support
/// for local assets, network URLs, and relative backend paths.
/// ---------------------------------------------------------------------------
class ImageViewPage extends StatefulWidget {
  static const String routeName = '/ImageViewPage';

  final dynamic image;
  final List<dynamic>? imageList;
  final int initialIndex;
  final String? title;
  final String? heroTag;
  final String? subtitle;

  const ImageViewPage({
    super.key,
    this.image,
    this.imageList,
    this.initialIndex = 0,
    this.title,
    this.heroTag,
    this.subtitle,
  });

  /// Open single image in full-screen expanded viewer
  static Future<void> open(
    BuildContext context, {
    required dynamic image,
    String? title,
    String? heroTag,
    String? subtitle,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.94),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: ImageViewPage(
              image: image,
              title: title,
              heroTag: heroTag,
              subtitle: subtitle,
            ),
          );
        },
      ),
    );
  }

  /// Open multiple images gallery in full-screen expanded viewer
  static Future<void> openGallery(
    BuildContext context, {
    required List<dynamic> images,
    int initialIndex = 0,
    String? title,
    String? heroTag,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.94),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: ImageViewPage(
              imageList: images,
              initialIndex: initialIndex,
              title: title,
              heroTag: heroTag,
            ),
          );
        },
      ),
    );
  }

  /// Resolves any image type safely into a Flutter ImageProvider
  static ImageProvider resolveImageProvider(dynamic image) {
    if (image == null) {
      return const AssetImage(kNoImage);
    }
    if (image is ImageProvider) {
      return image;
    }
    if (image is File) {
      return FileImage(image);
    }
    if (image is String) {
      final trimmed = image.trim();
      if (trimmed.isEmpty || trimmed == 'null') {
        return const AssetImage(kNoImage);
      }
      if (trimmed.startsWith('assets/') || trimmed.startsWith('assets')) {
        return AssetImage(trimmed);
      }
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return CachedNetworkImageProvider(trimmed);
      }
      final fullUrl = GlobalVar.getImageUrl(trimmed, width: 1200, height: 1200, crop: false);
      if (fullUrl.startsWith('assets/') || fullUrl.startsWith('assets')) {
        return AssetImage(fullUrl);
      }
      if (fullUrl.startsWith('http://') || fullUrl.startsWith('https://')) {
        return CachedNetworkImageProvider(fullUrl);
      }
    }
    return const AssetImage(kNoImage);
  }

  @override
  State<ImageViewPage> createState() => _ImageViewPageState();
}

class _ImageViewPageState extends State<ImageViewPage> {
  late List<dynamic> _items;
  late int _currentIndex;
  late PageController _pageController;
  late PhotoViewController _photoViewController;

  bool _controlsVisible = true;
  double _dragOffsetY = 0.0;
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    if (widget.imageList != null && widget.imageList!.isNotEmpty) {
      _items = widget.imageList!;
      _currentIndex = widget.initialIndex.clamp(0, _items.length - 1);
    } else if (widget.image != null) {
      _items = [widget.image];
      _currentIndex = 0;
    } else {
      _items = [];
      _currentIndex = 0;
    }

    _pageController = PageController(initialPage: _currentIndex);
    _photoViewController = PhotoViewController()
      ..outputStateStream.listen((state) {
        if (mounted) {
          _currentScale = state.scale ?? 1.0;
        }
      });

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _photoViewController.dispose();
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_currentScale > 1.05) return;
    setState(() {
      _dragOffsetY += details.delta.dy;
      if (_dragOffsetY < 0) _dragOffsetY = 0;
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_currentScale > 1.05) return;
    if (_dragOffsetY > 80 || (details.primaryVelocity ?? 0) > 400) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _dragOffsetY = 0.0;
      });
    }
  }

  void _zoomIn() {
    final current = _photoViewController.scale ?? 1.0;
    _photoViewController.scale = (current * 1.4).clamp(0.8, 4.0);
  }

  void _zoomOut() {
    final current = _photoViewController.scale ?? 1.0;
    _photoViewController.scale = (current / 1.4).clamp(0.8, 4.0);
  }

  void _resetZoom() {
    _photoViewController.scale = 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final bgOpacity = (1.0 - (_dragOffsetY / 300)).clamp(0.4, 1.0);

    return PopScope(
      canPop: true,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.black.withValues(alpha: 0.94 * bgOpacity),
          body: GestureDetector(
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Interactive Image Canvas
                Transform.translate(
                  offset: Offset(0, _dragOffsetY),
                  child: _buildImageViewer(),
                ),

                // 2. Top Header Bar (Close + Title + Counter)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  top: _controlsVisible ? 0 : -100,
                  left: 0,
                  right: 0,
                  child: _buildTopBar(),
                ),

                // 3. Bottom Footer Bar (Zoom controls & Hint)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  bottom: _controlsVisible ? 0 : -100,
                  left: 0,
                  right: 0,
                  child: _buildBottomBar(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageViewer() {
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_not_supported_outlined, color: Colors.white54, size: 60),
            const SizedBox(height: 12),
            Text(
              'لا توجد صورة متوفرة',
              style: GoogleFonts.ibmPlexSansArabic(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_items.length == 1) {
      return PhotoView(
        imageProvider: ImageViewPage.resolveImageProvider(_items[0]),
        controller: _photoViewController,
        minScale: PhotoViewComputedScale.contained * 0.8,
        maxScale: PhotoViewComputedScale.covered * 3.5,
        initialScale: PhotoViewComputedScale.contained,
        heroAttributes: widget.heroTag != null ? PhotoViewHeroAttributes(tag: widget.heroTag!) : null,
        backgroundDecoration: const BoxDecoration(color: Colors.transparent),
        loadingBuilder: (context, event) => const Center(
          child: SizedBox(
            width: 38,
            height: 38,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: kPrimaryOrange,
            ),
          ),
        ),
        errorBuilder: (context, error, stackTrace) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 54),
              const SizedBox(height: 12),
              Text(
                'تعذر تحميل الصورة',
                style: GoogleFonts.ibmPlexSansArabic(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        onTapUp: (context, details, controllerValue) {
          setState(() {
            _controlsVisible = !_controlsVisible;
          });
        },
      );
    }

    return PhotoViewGallery.builder(
      itemCount: _items.length,
      pageController: _pageController,
      scrollPhysics: const BouncingScrollPhysics(),
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      builder: (context, index) {
        final item = _items[index];
        final isCurrent = index == _currentIndex;
        return PhotoViewGalleryPageOptions(
          imageProvider: ImageViewPage.resolveImageProvider(item),
          minScale: PhotoViewComputedScale.contained * 0.8,
          maxScale: PhotoViewComputedScale.covered * 3.5,
          initialScale: PhotoViewComputedScale.contained,
          heroAttributes: (widget.heroTag != null && isCurrent)
              ? PhotoViewHeroAttributes(tag: widget.heroTag!)
              : null,
        );
      },
      loadingBuilder: (context, event) => const Center(
        child: SizedBox(
          width: 38,
          height: 38,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: kPrimaryOrange,
          ),
        ),
      ),
      backgroundDecoration: const BoxDecoration(color: Colors.transparent),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      top: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.75),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            // Close Button (Right side in RTL)
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.0,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    PhosphorIconsBold.x,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ),
            ),

            // Product Title (Center in RTL)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.title != null && widget.title!.isNotEmpty)
                      Text(
                        widget.title!,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
                      Text(
                        widget.subtitle!,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),

            // Counter Badge if multiple images
            if (_items.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${_items.length}',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      bottom: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.75),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Gesture Hint Capsule
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    PhosphorIconsRegular.magnifyingGlassPlus,
                    color: Colors.white70,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'قرّب بإصبعيك أو انقر مرتين',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: Colors.white70,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Quick Zoom Controls (Zoom in, Zoom out, Reset)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildZoomButton(
                  icon: PhosphorIconsBold.plus,
                  onTap: _zoomIn,
                  tooltip: 'تكبير',
                ),
                const SizedBox(width: 8),
                _buildZoomButton(
                  icon: PhosphorIconsBold.minus,
                  onTap: _zoomOut,
                  tooltip: 'تصغير',
                ),
                const SizedBox(width: 8),
                _buildZoomButton(
                  icon: PhosphorIconsBold.arrowsIn,
                  onTap: _resetZoom,
                  tooltip: 'إعادة الضبط',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.0,
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}
