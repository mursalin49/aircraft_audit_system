class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final dynamic details;

  const ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.details,
  });

  @override
  String toString() => message;
}
