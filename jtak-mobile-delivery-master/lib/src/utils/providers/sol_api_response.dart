import '../utilities/global_var.dart';

class SolApiErrorResponse {
  String requestId;
  String timeStamp;
  List<dynamic> errors = [];

  SolApiErrorResponse({this.requestId = "", this.timeStamp = ""});

  String getErrorsString({String divider = '\n'}) {
    String errorStr = "";
    errors.forEach((err) {
      errorStr += err + " $divider";
    });
    return errorStr;
  }

  void fromJson(Map<String, dynamic> json) {
    try {
      {
        if (json.containsKey('errors'))
          errors = json['errors'];
        else if (json.containsKey('Errors'))
          errors = json['Errors'];
        else if (json.containsKey('errorDescription'))
          errors = [json['errorDescription']];
        else if (json.containsKey('error_description'))
          errors = [json['error_description']];
        else if (json.containsKey('error'))
          errors = [json['error']];
        else
          errors.add(str.msg.errConnectionServer);
      }
    } catch (err) {
      print(err.toString());
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['errors'] = this.errors;
    data['requestId'] = this.requestId;
    data['timeStamp'] = this.timeStamp;
    return data;
  }
}
