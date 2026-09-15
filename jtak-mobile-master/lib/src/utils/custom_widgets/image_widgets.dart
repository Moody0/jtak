import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../config/constants/constants.dart';
import '../utilities/global_var.dart';
import 'image_view_page.dart';
import 'shimmer.dart';

class ImageView extends StatelessWidget {
  final dynamic image;
  final double width;
  final double height;
  final double imageWidth;
  final double imageHeight;
  final BoxFit? fit;
  final String? heroTag;
  final Function()? onTap;
  final bool tapped;
  final bool crop;
  final bool showLoader;
  final AlignmentGeometry alignment;

  void onTapFun(BuildContext context) {}

  const ImageView(
    this.image, {
    this.width = 100,
    this.height = 150,
    this.imageWidth = 200,
    this.imageHeight = 200,
    this.fit,
    this.onTap,
    this.tapped = false,
    this.crop = false,
    this.showLoader = true,
    this.heroTag,
    this.alignment = Alignment.center,
    Key? key,
  }) : super(key: key);

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
        if (image.startsWith('assets')) {
          return _heroTag(
            child: Image.asset(
              image,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (_, __, ___) => Image.asset(kNoImage, width: width, height: height),
            ),
          );
        }
        String url;
        if (image.startsWith('http')) {
          url = image;
        } else {
          url = GlobalVar.getImageUrl(image, width: imageWidth.toInt(), height: imageHeight.toInt(), crop: crop);
        }
        // return Container(width: width, height: height, color: Colors.red, child: Image.network(url));
        return _heroTag(
          child: CachedNetworkImage(
            imageUrl: url,
            width: width,
            height: height,
            alignment: Alignment.center,
            fit: fit,
            fadeInDuration: const Duration(milliseconds: 220),
            fadeOutDuration: const Duration(milliseconds: 150),
            placeholder: (context, url) {
              if (showLoader) {
                return Shimmer.fromColors(
                  baseColor: const Color(0xFFF1F5F9),
                  highlightColor: const Color(0xFFF8FAFC),
                  child: Container(
                    color: const Color(0xFFF1F5F9),
                    width: width,
                    height: height,
                  ),
                );
              }
              return const SizedBox();
            },
            errorWidget: (context, url, error) => Image.asset(kNoImage, width: width, height: height),
            imageBuilder: (context, imageProvider) {
              return Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: imageProvider,
                    alignment: alignment,
                    fit: fit ?? BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        );
      }
    }

    return Image.asset(kNoImage, width: width, height: height);
  }

  Widget _heroTag({required Widget child}) {
    if (heroTag != null) {
      return Hero(tag: heroTag!, child: child);
    }
    return child;
  }

  ImageProvider<dynamic> getImageProviderWidget() {
    if (image != null) {
      if (image is File) {
        return FileImage(image);
      } else if (image is String && image.isNotEmpty) {
        if (image.startsWith('assets')) {
          return AssetImage(image);
        }
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
