class CustomException implements Exception {
  final String? message;
  final String? prefix;
  final int? statusCode;
  final dynamic data;

  CustomException([this.message, this.statusCode = 0, this.prefix = 'Error During Communication', this.data]);

  @override
  String toString() {
    //return "$prefix \n $message";
    return "$message";
  }
}

class NotFoundException extends CustomException {
  NotFoundException([String? message, int statusCode = 404, dynamic data]) : super(message, statusCode, "Error !! ", data);
}

class GeneralException extends CustomException {
  GeneralException([String? message, int? statusCode, dynamic data]) : super(message, statusCode, "Error !! ", data);
}

class FetchDataException extends CustomException {
  FetchDataException([String? message, int? statusCode, dynamic data]) : super(message, statusCode, "Error During Communication: ", data);
}

class BadRequestException extends CustomException {
  BadRequestException([dynamic message, int? statusCode, dynamic data]) : super(message?.toString(), statusCode, "Invalid Request: ", data);
}

class UnauthorisedException extends CustomException {
  UnauthorisedException([String? message, int? statusCode]) : super(message, statusCode, "Unauthorised: ");
}

class InvalidInputException extends CustomException {
  InvalidInputException([String? message, int? statusCode]) : super(message, statusCode, "Invalid Input: ");
}

class InternetException extends CustomException {
  InternetException([String? message, int statusCode = -1]) : super(message, statusCode, "Invalid Input: ");
}
