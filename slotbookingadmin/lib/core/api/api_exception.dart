class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final dynamic data;

  const ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => message;
}
