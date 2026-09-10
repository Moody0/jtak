import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

import '../../config/constants/constants.dart';

class FileUtil {
  Future<File> getFileFromByteData(ByteData bytes, {String? fileName}) async {
    fileName ??= DateTime.now().toIso8601String();
    String dir = (await path_provider.getTemporaryDirectory()).path;
    return await writeToFile(bytes, '$dir/$fileName');
  }

  //write to app path
  Future<File> writeToFile(ByteData data, String path) {
    log('////image file Path : $path');
    final buffer = data.buffer;
    return File(path).writeAsBytes(buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }

  Future<FileSystemEntity> deleteFile(String path) {
    try {
      return File(path).delete(recursive: false);
    } catch (error) {
      rethrow;
    }
  }

  Future<FileSystemEntity> deleteFile2(File file) async {
    try {
      return await file.delete(recursive: false);
    } catch (error) {
      rethrow;
    }
  }

  Future<Directory> getAppDirectory({String dirName = ''}) async {
    Directory dir;
    String baseFolder = '$kAppName/$dirName';
    if (Platform.isAndroid) {
      try {
        String path = join('/storage/emulated/0', baseFolder);
        dir = await Directory(path).create(recursive: true);
        if (!await dir.exists()) {
          var temp = await path_provider.getExternalStorageDirectory();
          path = join(temp!.path, baseFolder);
          dir = await Directory(path).create(recursive: true);
        }
      } catch (err) {
        log(err.toString());
        dir = await path_provider.getApplicationSupportDirectory();
      }
    } else {
      var temp = await path_provider.getTemporaryDirectory();
      String path = join(temp.path, baseFolder);
      dir = await Directory(path).create(recursive: true);
    }
    return dir;
  }
}
