import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../config/constants/constants.dart';
import '../../config/themes/app_theme.dart';
import '../utilities/global_var.dart';

class ImageSliderPage extends StatelessWidget {
  static const String routeName = '/ImageSliderPage';
  final List<dynamic> imageList;
  final dynamic cuurentActiveItem;
  const ImageSliderPage(
    this.imageList, {
    this.cuurentActiveItem,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    return WillPopScope(
      onWillPop: () async {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
        // SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        return true;
      },
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.black87,
          resizeToAvoidBottomInset: true,
          body: ImageSliderContent(imageList),
        ),
      ),
    );
  }
}

class ImageSliderContent extends StatefulWidget {
  final List<dynamic> imageList;
  final dynamic cuurentActiveItem;
  const ImageSliderContent(this.imageList, {this.cuurentActiveItem, Key? key}) : super(key: key);
  @override
  _ImageSliderContentState createState() => _ImageSliderContentState();
}

class _ImageSliderContentState extends State<ImageSliderContent> {
  late Size size;
  @override
  Widget build(BuildContext context) {
    size = MediaQuery.of(context).size;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _sliderView(),
        _buildTopBar(),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      right: 0,
      left: 0,
      child: Container(
        height: null,
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black26, Colors.black12, Colors.transparent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Row(
          children: <Widget>[
            const BackButton(color: Colors.white),
            const Spacer(),
            Text(
              "${activeImageIndex + 1} / ${widget.imageList.length}",
              style: AppTheme.numberStyle.copyWith(color: Colors.white, fontSize: 18),
            ),
            const Spacer(),
            const SizedBox(width: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    double boxWidth = 20;
    if ((boxWidth + 6) * widget.imageList.length > size.width) boxWidth = size.width / (widget.imageList.length * 2);
    return Positioned(
      bottom: 0,
      right: 0,
      left: 0,
      child: Container(
        height: 50,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black12, Colors.transparent],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.imageList.length,
            (index) {
              return Container(
                width: boxWidth,
                height: 3,
                margin: const EdgeInsets.all(3),
                color: activeImageIndex == index ? Colors.white : Colors.grey,
              );
            },
            growable: false,
          ),
        ),
      ),
    );
  }

  PageController controller = PageController();
  var currentPageValue = 0.0;
  var activeImageIndex = 0;
  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      setState(() {
        currentPageValue = controller.page!;
        if (controller.page!.round() < widget.imageList.length) activeImageIndex = controller.page!.round();
      });
    });
    Future.microtask(() {
      if (widget.cuurentActiveItem is int) {
        controller.jumpToPage(widget.cuurentActiveItem);
      } else {
        var index = widget.imageList.indexWhere((element) => element == widget.cuurentActiveItem);
        log(index.toString());
        if (index > 0) controller.jumpToPage(index);
      }
    });
  }

  Widget _sliderView() {
    return PhotoViewGallery.builder(
      scrollPhysics: const BouncingScrollPhysics(),
      builder: (BuildContext context, int index) {
        return PhotoViewGalleryPageOptions(
          imageProvider: _getImageProvider(widget.imageList[index]),
          initialScale: PhotoViewComputedScale.contained * 0.8,
          heroAttributes: PhotoViewHeroAttributes(tag: widget.imageList[index].toString()),
        );
      },
      itemCount: widget.imageList.length,
      loadingBuilder: (context, event) => Center(
        child: SizedBox(
          width: 20.0,
          height: 20.0,
          child: CircularProgressIndicator(
            value: event == null ? 0 : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 0),
          ),
        ),
      ),
      // backgroundDecoration: widget.backgroundDecoration,
      // pageController: widget.pageController,
      onPageChanged: (index) {
        setState(() => activeImageIndex = index);
      },
    );
    // return PageView.builder(
    //   controller: controller,
    //   itemCount: widget.imageList.length,
    //   itemBuilder: (context, position) {
    //     return PageViewTransition1(
    //       child: _imageView(widget.imageList[position]),
    //       currentPageValue: currentPageValue,
    //       position: position,
    //     );
    //   },
    // );
  }

  ImageProvider _getImageProvider(var image) {
    ImageProvider imageProvider;
    if (image == null) {
      imageProvider = const AssetImage(kNoImage);
    } else if (image is File) {
      imageProvider = FileImage(image);
    } else {
      imageProvider = NetworkImage(GlobalVar.getImageUrl(image, height: 1200, width: 1200, crop: false));
    }
    return imageProvider;
  }

  // Widget _imageView(var image) {
  //   var photoView = PhotoView(
  //     heroAttributes: PhotoViewHeroAttributes(tag: image is File ? image.path : image ?? DateTime.now().toString()),
  //     imageProvider: _getImageProvider(image),
  //   );
  //   return photoView;
  // }
}

class PageViewTransition1 extends StatelessWidget {
  final Widget child;
  final double? currentPageValue;
  final int? position;
  const PageViewTransition1({required this.child, this.currentPageValue, this.position, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    if (position == currentPageValue!.floor()) {
      return Transform(
        transform: Matrix4.identity()..rotateX(currentPageValue! - position!),
        child: child,
      );
    } else if (position == currentPageValue!.floor() + 1) {
      return Transform(
        transform: Matrix4.identity()..rotateX(currentPageValue! - position!),
        child: child,
      );
    } else {
      return Container(
        color: position! % 2 == 0 ? Colors.blue : Colors.pink,
        child: child,
      );
    }
  }
}

class PageViewTransition2 extends StatelessWidget {
  final Widget child;
  final double? currentPageValue;
  final int? position;
  const PageViewTransition2({required this.child, this.currentPageValue, this.position, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    if (position == currentPageValue!.floor()) {
      return Transform(
        transform: Matrix4.identity()
          ..rotateY(currentPageValue! - position!)
          ..rotateZ(currentPageValue! - position!),
        child: child,
      );
    } else if (position == currentPageValue!.floor() + 1) {
      return Transform(
        transform: Matrix4.identity()
          ..rotateY(currentPageValue! - position!)
          ..rotateZ(currentPageValue! - position!),
        child: child,
      );
    } else {
      return Container(
        color: position! % 2 == 0 ? Colors.blue : Colors.pink,
        child: child,
      );
    }
  }
}

class PageViewTransition3 extends StatelessWidget {
  final Widget child;
  final double? currentPageValue;
  final int? position;
  const PageViewTransition3({required this.child, this.currentPageValue, this.position, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    if (position == currentPageValue!.floor()) {
      return Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.004)
          ..rotateY(currentPageValue! - position!)
          ..rotateZ(currentPageValue! - position!),
        child: child,
      );
    } else if (position == currentPageValue!.floor() + 1) {
      return Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.004)
          ..rotateY(currentPageValue! - position!)
          ..rotateZ(currentPageValue! - position!),
        child: child,
      );
    } else {
      return Container(
        color: position! % 2 == 0 ? Colors.blue : Colors.pink,
        child: child,
      );
    }
  }
}

class PageViewTransition4 extends StatelessWidget {
  final Widget child;
  final double? currentPageValue;
  final int? position;
  const PageViewTransition4({required this.child, this.currentPageValue, this.position, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    if (position == currentPageValue?.floor()) {
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(currentPageValue! - position!)
          ..rotateY(currentPageValue! - position!)
          ..rotateZ(currentPageValue! - position!),
        child: child,
      );
    } else if (position == currentPageValue!.floor() + 1) {
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(currentPageValue! - position!)
          ..rotateY(currentPageValue! - position!)
          ..rotateZ(currentPageValue! - position!),
        child: child,
      );
    } else {
      return Container(
        color: position! % 2 == 0 ? Colors.blue : Colors.pink,
        child: child,
      );
    }
  }
}
