class AppException implements Exception {
  final String message;
  final Map<String, dynamic>? errors;

  AppException(this.message, {this.errors});

  @override
  String toString() => message;
}
