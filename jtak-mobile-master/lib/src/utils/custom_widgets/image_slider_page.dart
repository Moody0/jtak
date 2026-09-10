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
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
  var activeImageIndex = 0;

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

  Widget _sliderView() {
    return PhotoViewGallery.builder(
      scrollPhysics: const ClampingScrollPhysics(),
      builder: (BuildContext context, int index) {
        return PhotoViewGalleryPageOptions(
          imageProvider: _imageView(widget.imageList[index]),
          initialScale: PhotoViewComputedScale.contained * 0.8,
        );
      },
      itemCount: widget.imageList.length,
      loadingBuilder: (context, event) => const Center(
        child: SizedBox(
          width: 20.0,
          height: 20.0,
          child: CircularProgressIndicator(
              // value: event == null ? 0 : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 0),
              ),
        ),
      ),
      // backgroundDecoration: widget.backgroundDecoration,
      // pageController: widget.pageController,
      onPageChanged: (index) {
        setState(() => activeImageIndex = index);
      },
    );
  }

  ImageProvider _imageView(var image) {
    ImageProvider imageProvider;
    if (image == null) {
      imageProvider = const AssetImage(kNoImage);
    } else if (image is File) {
      imageProvider = FileImage(image);
    } else {
      imageProvider = NetworkImage(
        image.startsWith('http') ? image : GlobalVar.getImageUrl(image, height: 1200, width: 675, crop: false),
      );
    }
    return imageProvider;
  }
}
