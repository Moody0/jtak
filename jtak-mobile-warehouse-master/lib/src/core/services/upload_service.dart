import 'dart:developer';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../utils/providers/sol_api.dart';
import '../../utils/utilities/global_var.dart';
import 'authentication_service.dart';
import 'locator.dart';

/// ---------------------------------------------------------------------------
/// Upload Service (Photo Picker & Multipart Upload to JTAK Backend)
/// ---------------------------------------------------------------------------

class UploadService {
  final ImagePicker _picker = ImagePicker();

  /// Pick an image from gallery or camera
  Future<String?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      return pickedFile?.path;
    } catch (e) {
      log('Error picking image: $e');
      return null;
    }
  }

  /// Upload file to JTAK SaveUploaded endpoint
  Future<String?> uploadImage(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        log('Upload error: File does not exist at $filePath');
        return null;
      }

      final uri = Uri.parse('${SolApi.baseURL}/api/v1/Services/SaveUploaded');
      final request = http.MultipartRequest('POST', uri);

      // Ensure token is fresh and attach auth header
      final authService = locator<AuthenticationService>();
      try {
        await authService.checkAuthorizationToken();
      } catch (_) {}
      final token = authService.getAccessToken;
      if (token.isNotEmpty) {
        request.headers['authorization'] = 'Bearer $token';
      }
      request.headers['Accept-Language'] = 'ar';

      // Attach file with multipart form
      final multipartFile = await http.MultipartFile.fromPath('file', filePath);
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        String body = response.body.trim();
        // Remove surrounding quotes if server returned JSON string like "2026/09/..."
        if (body.startsWith('"') && body.endsWith('"') && body.length >= 2) {
          body = body.substring(1, body.length - 1);
        }
        // Normalize any Windows backslashes to forward slashes for URL compatibility
        body = body.replaceAll(r'\', '/');
        log('Image uploaded successfully: $body');
        return body;
      } else {
        log('Image upload failed with status ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      log('Image upload exception: $e');
      return null;
    }
  }

  /// Resolve full image URL from file identifier
  static String resolveImageUrl(String? fileId, {int width = 300, int height = 200, bool crop = true}) {
    if (fileId == null || fileId.isEmpty || fileId.toLowerCase() == 'null') {
      return '';
    }
    var clean = fileId.split(',').first.trim().replaceAll(r'\', '/');
    while (clean.startsWith('/')) {
      clean = clean.substring(1);
    }
    if (clean.isEmpty || clean == 'null') return '';
    if (clean.startsWith('http://') || clean.startsWith('https://') || clean.startsWith('assets/')) {
      return clean;
    }
    return GlobalVar.getImageUrl(clean, width: width, height: height, crop: crop);
  }
}
