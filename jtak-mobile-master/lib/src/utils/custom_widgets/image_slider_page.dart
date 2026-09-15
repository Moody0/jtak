import 'package:flutter/material.dart';
import 'image_view_page.dart';

class ImageSliderPage extends StatelessWidget {
  static const String routeName = '/ImageSliderPage';
  final List<dynamic> imageList;
  final dynamic cuurentActiveItem;

  const ImageSliderPage(
    this.imageList, {
    this.cuurentActiveItem,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    int initialIndex = 0;
    if (cuurentActiveItem != null && imageList.contains(cuurentActiveItem)) {
      initialIndex = imageList.indexOf(cuurentActiveItem);
    }
    return ImageViewPage(
      imageList: imageList,
      initialIndex: initialIndex,
    );
  }
}

class ImageSliderContent extends StatelessWidget {
  final List<dynamic> imageList;
  final dynamic cuurentActiveItem;

  const ImageSliderContent(
    this.imageList, {
    this.cuurentActiveItem,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    int initialIndex = 0;
    if (cuurentActiveItem != null && imageList.contains(cuurentActiveItem)) {
      initialIndex = imageList.indexOf(cuurentActiveItem);
    }
    return ImageViewPage(
      imageList: imageList,
      initialIndex: initialIndex,
    );
  }
}
