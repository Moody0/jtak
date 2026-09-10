// import 'dart:developer';

// import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';

// import '../../main_imports.dart';
// import '../custome_widgets/button.dart';
// import '../custome_widgets/messages.dart';

// class StoragePermission {
//   final BuildContext context;

//   StoragePermission(this.context);

//   Future<bool> getstoragePermission() async {
//     if (await Permission.storage.isGranted) return true;
//     await requestStoragePermission();
//     if (await Permission.storage.isGranted)
//       return true;
//     else if (await Permission.storage.isDenied) {
//       await showDialog(
//         context: context,
//         builder: (context) => CustomDialog(
//           title: str.msg.operationCanNotCompleted,
//           message: str.app.pleaseStoragePermission,
//           actions: [
//             TextButton(
//                 child: Text(str.main.yes),
//                 onPressed: () async {
//                   Navigator.pop(context);
//                   await requestStoragePermission();
//                 }),
//             ButtonWidget(
//               str.main.no,
//               () => Navigator.pop(context),
//               padding: EdgeInsets.all(8),
//             ),
//           ],
//         ),
//       );
//     }
//     if (await Permission.storage.isPermanentlyDenied) {
//       log('storage permission is isPermanentlyDenied');
//       // The user opted to never again see the permission request dialog for this
//       // app. The only way to change the permission's status now is to let the
//       // user manually enable it in the system settings.
//       await showDialog(
//         context: context,
//         builder: (context) => CustomDialog(
//           title: str.msg.operationCanNotCompleted,
//           message: str.app.pleaseStoragePermission,
//           actions: [
//             TextButton(
//                 child: Text(str.main.yes),
//                 onPressed: () {
//                   Navigator.pop(context);
//                   openAppSettings();
//                 }),
//             ButtonWidget(
//               str.main.no,
//               () => Navigator.pop(context),
//               padding: EdgeInsets.all(8),
//             ),
//           ],
//         ),
//       );
//     }
//     return await Permission.storage.isGranted;
//   }

//   Future<bool> requestStoragePermission() async {
//     try {
//       log(' request storage permission');
//       var res = await Permission.storage.request();
//       return res.isGranted;
//     } catch (err) {
//       log(err.toString());
//       showDialog(context: context, builder: (context) => CustomDialog(message: err.toString()));
//     }
//     return false;
//   }
// }
