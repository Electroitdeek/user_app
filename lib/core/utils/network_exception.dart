class NetworkException implements Exception {
  final String message;

  NetworkException([this.message = 'No internet connection']);

  @override
  String toString() => message;
}
