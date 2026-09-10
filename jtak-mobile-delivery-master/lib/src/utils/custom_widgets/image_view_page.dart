import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';

import '../../config/constants/constants.dart';
import '../utilities/global_var.dart';

class ImageViewPage extends StatelessWidget {
  static const String routeName = '/ImageViewPage';
  final dynamic image;

  const ImageViewPage({Key? key, this.image}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    return WillPopScope(
      onWillPop: () async {
        // SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
        return true;
      },
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.black87,
          resizeToAvoidBottomInset: true,
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _imageView(),
              _buildTopBar(),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  _buildTopBar() {
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
          children: const <Widget>[
            BackButton(color: Colors.white),
            Spacer(),
          ],
        ),
      ),
    );
  }

  _buildBottomBar() {
    return Positioned(
      bottom: 0,
      right: 0,
      left: 0,
      child: Container(
        height: null,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black26, Colors.black12, Colors.transparent],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: const <Widget>[],
        ),
      ),
    );
  }

  _imageView() {
    // return Container(
    //   child: FadeInImage(
    //     alignment: Alignment.center,
    //     image: NetworkImage(GlobalVar.getDownloadUrl(image)),
    //     fit: BoxFit.cover,
    //     placeholder: AssetImage(GlobalVar.logo),
    //     imageErrorBuilder: (context, error, stackTrace) {
    //       log('imageErrorBuilder');
    //       print(error.toString());
    //       print(stackTrace.toString());
    //       log(GlobalVar.getDownloadUrl(image));
    //       return Image.asset(
    //         GlobalVar.noImage,
    //         color: Colors.white70,
    //       );
    //     },
    //   ),
    // );
    ImageProvider imageProvider;
    if (image == null) {
      imageProvider = const AssetImage(kNoImage);
    } else if (image is File) {
      imageProvider = FileImage(image);
    } else {
      imageProvider = NetworkImage(image.startsWith('http') ? image : GlobalVar.getDownloadUrl(image));
    }

    return PhotoView(
      heroAttributes: PhotoViewHeroAttributes(tag: image?.toString() ?? DateTime.now().toString()),
      imageProvider: imageProvider,
    );
  }
}
