part of '../api_client.dart';

class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final storage = locator<LocalStorageService>();
      final token = await storage.token;

      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      // Always include the Accept header to prevent 302 redirects
      options.headers['Accept'] = 'application/json';
      if (storage.cityAdminId != null) {
        options.headers['cityAdminId'] = storage.cityAdminId;
      }
    } catch (_) {
      // LocalStorageService not ready yet — ignore
    }

    super.onRequest(options, handler);
  }
}
