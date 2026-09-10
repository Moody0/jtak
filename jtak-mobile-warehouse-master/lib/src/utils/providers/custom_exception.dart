class CustomException implements Exception {
  final String? message;
  final String? prefix;
  final int? statusCode;

  CustomException([this.message, this.statusCode = 0, this.prefix = 'Error During Communication']);

  @override
  String toString() {
    //return "$prefix \n $message";
    return "$message";
  }
}

class NotFoundException extends CustomException {
  NotFoundException([String? message, int statusCode = 404]) : super(message, statusCode, "Error !! ");
}

class GeneralException extends CustomException {
  GeneralException([String? message, int? statusCode]) : super(message, statusCode, "Error !! ");
}

class FetchDataException extends CustomException {
  FetchDataException([String? message, int? statusCode]) : super(message, statusCode, "Error During Communication: ");
}

class BadRequestException extends CustomException {
  BadRequestException([message, int? statusCode]) : super(message, statusCode, "Invalid Request: ");
}

class UnauthorisedException extends CustomException {
  UnauthorisedException([message, int? statusCode]) : super(message, statusCode, "Unauthorised: ");
}

class InvalidInputException extends CustomException {
  InvalidInputException([String? message, int? statusCode]) : super(message, statusCode, "Invalid Input: ");
}

class InternetException extends CustomException {
  InternetException([String? message, int statusCode = -1]) : super(message, statusCode, "Invalid Input: ");
}
