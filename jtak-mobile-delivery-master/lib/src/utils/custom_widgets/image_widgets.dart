import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../config/constants/constants.dart';
import '../utilities/global_var.dart';
import 'image_view_page.dart';

class ImageView extends StatelessWidget {
  final dynamic image;
  final double width;
  final double height;
  final double imageWidth;
  final double imageHeight;
  final BoxFit fit;
  final Function()? onTap;
  final bool tapped;

  void onTapFun(BuildContext context) {}

  const ImageView(this.image,
      {this.width = 100,
      this.height = 150,
      this.imageWidth = 300,
      this.imageHeight = 400,
      this.fit = BoxFit.cover,
      this.onTap,
      this.tapped = false,
      Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // child: FadeInImage(
      //   alignment: Alignment.center,
      //   height: height,
      //   width: width,
      //   image: getImageProviderWidget(),
      //   fit: fit,
      //   placeholder: AssetImage(GlobalVar.logo),
      //   imageErrorBuilder: (context, error, stackTrace) {
      //     // log('///////////////////imageErrorBuilder');
      //     // print(error.toString());
      //     // print(stackTrace.toString());
      //     // log(GlobalVar.getImageUrl(image.toString(), width: width, height: height));
      //     return Image.asset(GlobalVar.noImage, width: width, height: height, color: Colors.black45);
      //   },
      // ),
      child: getImageWidget(),
      onTap: tapped && image != null
          ? onTap ??
              () {
                Navigator.pushNamed(context, ImageViewPage.routeName, arguments: image);
              }
          : null,
    );
  }

  Widget getImageWidget() {
    if (image != null) {
      if (image is File) {
        return Image.file(image, height: height, width: width, fit: fit);
      } else if (image is String && image.isNotEmpty) {
        String url;
        if (image.startsWith('http')) {
          url = image;
        } else {
          url = GlobalVar.getImageUrl(image, width: imageWidth.toInt(), height: imageHeight.toInt(), crop: false);
        }
        return Hero(
          tag: image?.toString() ?? DateTime.now().toString(),
          child: CachedNetworkImage(
            width: width,
            height: height,
            imageUrl: url,
            placeholder: (context, url) =>
                Container(color: Colors.grey.shade200, width: width, height: height, child: const Center(child: CircularProgressIndicator())),
            errorWidget: (context, url, error) => Image.asset(kNoImage, width: width, height: height),
            imageBuilder: (context, imageProvider) {
              return Container(
                width: width,
                height: height,
                decoration: BoxDecoration(image: DecorationImage(image: imageProvider)),
              );
            },
          ),
        );
      }
    }

    return Image.asset(kNoImage, width: width, height: height);
  }

  ImageProvider<dynamic> getImageProviderWidget() {
    if (image != null) {
      if (image is File) {
        return FileImage(image);
      } else if (image is String && image.isNotEmpty) {
        return NetworkImage(
          image.startsWith('http') ? image : GlobalVar.getImageUrl(image, width: imageWidth.toInt(), height: imageHeight.toInt()),
        );
      }
    }
    return const AssetImage(kNoImage);
  }
}

class CircularImageView extends StatelessWidget {
  final dynamic image;
  final double dimension;
  final int imageDimension;
  final BoxBorder? border;
  final Function()? onTap;
  final bool tapped;
  final BoxFit fit;
  final EdgeInsets margin;
  final ImageProvider? defaultImage;

  void onTapFun(BuildContext context) {}

  const CircularImageView(
    this.image, {
    this.dimension = 50,
    this.imageDimension = 150,
    this.onTap,
    this.tapped = true,
    this.fit = BoxFit.cover,
    this.border,
    this.margin = const EdgeInsets.all(2),
    this.defaultImage,
    Key? key,
  }) : super(key: key);

  ImageProvider<Object> getImageWidget() {
    if (image != null) {
      if (image is File) {
        return FileImage(image);
      } else if (image is String && image.isNotEmpty) {
        return NetworkImage(
          image.startsWith('http') ? image : GlobalVar.getImageUrl(image, width: imageDimension, height: imageDimension),
        );
      }
    }
    return defaultImage ?? const AssetImage(kPerson);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Container(
        height: dimension,
        width: dimension,
        margin: margin,
        decoration: BoxDecoration(
          border: border,
          shape: BoxShape.circle,
          image: DecorationImage(
            fit: fit,
            image: getImageWidget(),
          ),
        ),
      ),
      onTap: tapped && image != null
          ? onTap ??
              () {
                Navigator.pushNamed(context, ImageViewPage.routeName, arguments: image);
              }
          : null,
    );
  }
}
