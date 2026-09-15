import 'package:flutter/foundation.dart';

class SolApiErrorResponse {
  String requestId;
  String timeStamp;
  List<dynamic> errors = [];

  SolApiErrorResponse({this.requestId = "", this.timeStamp = ""});

  String getErrorsString({String divider = '\n'}) {
    List<String> list = [];
    for (var err in errors) {
      if (err != null) {
        final s = err.toString().trim();
        if (s.isNotEmpty && !list.contains(s)) {
          list.add(s);
        }
      }
    }
    return list.join(divider);
  }

  static String cleanText(dynamic val) {
    if (val == null) return '';
    return val
        .toString()
        .replaceAll('\r\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'^!+'), '')
        .trim();
  }

  static String localizeMessage(String msg) {
    final lower = msg.toLowerCase().trim();
    if (lower.contains('too many cart submits')) {
      return 'يرجى الانتظار بضع ثوانٍ قبل محاولة إرسال الطلب مرة أخرى.';
    }
    if (lower.contains('cartitems field is required') || lower.contains('cart is empty')) {
      return 'سلة المشتريات فارغة، يرجى إضافة منتجات أولاً.';
    }
    if (lower.contains('unauthorized') || lower.contains('not authorized')) {
      return 'يرجى تسجيل الدخول أولاً لإتمام طلبك.';
    }
    if (lower.contains('address') && (lower.contains('required') || lower.contains('null'))) {
      return 'يرجى اختيار عنوان التوصيل على الخريطة قبل إتمام الطلب.';
    }
    if (lower.contains('phonenumber') && (lower.contains('required') || lower.contains('invalid'))) {
      return 'يرجى التأكد من صحة رقم الهاتف المسجل.';
    }
    return msg;
  }

  void fromJson(Map<String, dynamic> json) {
    try {
      errors.clear();

      // Handle wrapping under 'order', 'data', or 'result'
      Map<String, dynamic> source = json;
      if (json['order'] is Map<String, dynamic>) {
        source = json['order'] as Map<String, dynamic>;
      } else if (json['data'] is Map<String, dynamic>) {
        source = json['data'] as Map<String, dynamic>;
      } else if (json['result'] is Map<String, dynamic>) {
        source = json['result'] as Map<String, dynamic>;
      }

      // 1. Extract OrderDetails item-level warnings and unavailability
      final orderDetails = source['orderDetails'] ??
          source['OrderDetails'] ??
          source['details'] ??
          source['Details'] ??
          source['items'] ??
          source['Items'] ??
          source['cartItems'] ??
          source['CartItems'] ??
          json['orderDetails'] ??
          json['OrderDetails'];

      List<String> itemWarnings = [];
      if (orderDetails is Iterable) {
        for (var d in orderDetails) {
          if (d is Map) {
            final w = d['warning'] ?? d['Warning'] ?? d['error'] ?? d['Error'];
            if (w != null && w.toString().trim().isNotEmpty) {
              final cleanWarn = cleanText(w);
              final title = cleanText(d['productTitle'] ??
                  d['ProductTitle'] ??
                  d['title'] ??
                  d['Title'] ??
                  d['name'] ??
                  '');
              if (cleanWarn.isNotEmpty) {
                if (title.isNotEmpty) {
                  itemWarnings.add('$title: $cleanWarn');
                } else {
                  itemWarnings.add(cleanWarn);
                }
              }
            }
          }
        }
      }

      // 2. Extract Root-level Warning
      final rawWarning = source['warning'] ?? source['Warning'] ?? json['warning'] ?? json['Warning'];
      final cleanRootWarning = rawWarning != null ? cleanText(rawWarning) : '';

      if (itemWarnings.isNotEmpty) {
        if (cleanRootWarning.isNotEmpty &&
            (cleanRootWarning.contains('مراجعة المواد') ||
             cleanRootWarning.contains('مراجعة الطلب') ||
             cleanRootWarning.contains('راجع المواد'))) {
          errors.add('يرجى مراجعة المنتجات التالية في سلتك:');
          for (var iw in itemWarnings) {
            errors.add('• $iw');
          }
        } else {
          if (cleanRootWarning.isNotEmpty) {
            errors.add(cleanRootWarning);
          }
          for (var iw in itemWarnings) {
            errors.add('• $iw');
          }
        }
      } else if (cleanRootWarning.isNotEmpty) {
        errors.add(cleanRootWarning);
      }

      // 3. Extract 'warnings' array if present
      final rawWarnings = source['warnings'] ?? source['Warnings'] ?? json['warnings'] ?? json['Warnings'];
      if (rawWarnings is Iterable) {
        for (var w in rawWarnings) {
          final cw = cleanText(w);
          if (cw.isNotEmpty) {
            errors.add(cw);
          }
        }
      }

      // 4. Extract 'errors' / 'Errors' map or list (ASP.NET ModelState)
      final rawErrors = source['errors'] ?? source['Errors'] ?? json['errors'] ?? json['Errors'];
      if (rawErrors != null) {
        if (rawErrors is Map) {
          rawErrors.forEach((key, value) {
            if (value is Iterable) {
              for (var v in value) {
                final s = cleanText(v);
                if (s.isNotEmpty) errors.add(localizeMessage(s));
              }
            } else if (value != null) {
              final s = cleanText(value);
              if (s.isNotEmpty) errors.add(localizeMessage(s));
            }
          });
        } else if (rawErrors is Iterable) {
          for (var v in rawErrors) {
            final s = cleanText(v);
            if (s.isNotEmpty) errors.add(localizeMessage(s));
          }
        } else {
          final s = cleanText(rawErrors);
          if (s.isNotEmpty) errors.add(localizeMessage(s));
        }
      }

      // 5. Fallback single fields: message, detail, errorDescription
      if (errors.isEmpty) {
        final singleErr = source['errorDescription'] ??
            source['error_description'] ??
            source['error'] ??
            source['Error'] ??
            source['message'] ??
            source['Message'] ??
            source['detail'] ??
            source['Detail'] ??
            json['errorDescription'] ??
            json['message'] ??
            json['detail'];
        if (singleErr != null) {
          final s = cleanText(singleErr);
          if (s.isNotEmpty) {
            errors.add(localizeMessage(s));
          }
        }
      }

      // 6. Title field (ASP.NET validation title) if informative
      if (errors.isEmpty) {
        final title = cleanText(source['title'] ?? json['title']);
        if (title.isNotEmpty && !title.toLowerCase().contains('one or more validation errors')) {
          errors.add(localizeMessage(title));
        }
      }

      // 7. Last resort fallback
      if (errors.isEmpty) {
        errors.add('تعذر إتمام الطلب، يرجى مراجعة محتويات السلة والتأكد من العنوان.');
      }
    } catch (err) {
      debugPrint('SolApiErrorResponse fromJson error: $err');
      errors = ['تعذر إتمام الطلب، يرجى مراجعة السلة والمحاولة مرة أخرى.'];
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['errors'] = errors;
    data['requestId'] = requestId;
    data['timeStamp'] = timeStamp;
    return data;
  }
}
