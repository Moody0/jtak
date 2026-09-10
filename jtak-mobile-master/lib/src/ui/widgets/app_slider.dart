import 'dart:developer';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:jtek_app/src/core/controllers/initial_data_provider.dart';
import 'package:jtek_app/src/utils/utilities/global_var.dart';
import 'package:provider/provider.dart';
import '../../utils/custom_widgets/image_widgets.dart';

class AppSlider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    InitialDataProvider provider = Provider.of<InitialDataProvider>(context);
    if (!GlobalVar.checkListNotEmpty(provider.bannerList)) {
      return const SizedBox();
    }
    return CarouselSlider(
      options: CarouselOptions(
        autoPlay: true,
        aspectRatio: 16 / 9,
        viewportFraction: 1.0,
        enlargeStrategy: CenterPageEnlargeStrategy.height,
      ),
      items: provider.bannerList.map((e) => AppSliderSingleItem(e.featuredImage)).toList(),
    );
  }
}

class AppSliderSingleItem extends StatelessWidget {
  final String? item;
  const AppSliderSingleItem(this.item);
  final double height = 125;
  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    var imageWidth = size.width;
    var imageHeight = imageWidth / (16 / 9);

    return GestureDetector(
      onTap: () {
        log('AppSliderSingleItem clicked ');
      },
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
        ),
        elevation: 2,
        child: ImageView(
          item,
          height: imageHeight,
          width: imageWidth,
          imageHeight: 450,
          imageWidth: 800,
          tapped: false,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
