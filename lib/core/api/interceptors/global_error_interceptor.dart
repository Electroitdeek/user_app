part of '../api_client.dart';

class GlobalErrorInterceptor extends Interceptor {
  /// Prevents multiple simultaneous logout calls (e.g. when several
  /// requests fail with 401 at the same time).
  static bool _isLoggingOut = false;

  // ── Paths that must NEVER trigger an auto-logout ──────────────────────────
  static bool _isAuthPath(String path) =>
      path.contains(ApiEndpoints.verifyOtp) ||
      path.contains(ApiEndpoints.sendOtp) ||
      path.contains(ApiEndpoints.login);

  // ── onResponse ────────────────────────────────────────────────────────────
  // Called for every response whose status passes validateStatus.
  // GET / POST use `validateStatus: (s) => s != null && s < 500`, so 401
  // arrives here instead of onError — we must check it manually.
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final int? statusCode = response.statusCode;
    final dynamic data = response.data;
    final String path = response.requestOptions.path;

    final bool isUnauthenticated =
        statusCode == 401 ||
        (data is Map && data['message'] == 'Unauthenticated.');

    if (isUnauthenticated && !_isAuthPath(path)) {
      final storage = locator<LocalStorageService>();
      final token = await storage.token;

      // Only perform auto-logout AND trigger rejection for 401 if a token exists.
      // If no token exists, the user is a Guest, and 401 here is just a gated
      // resource — it should NOT trigger a "Session Expired" logout event.
      if (token != null && token.isNotEmpty) {
        kPrintError(
          "Session expired (onResponse 401) at $path. Triggering auto-logout.",
        );
        await _performAutoLogout();

        return handler.reject(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            message: 'Session expired. Please login again.',
          ),
        );
      }
    }

    return handler.next(response);
  }

  // ── onError ───────────────────────────────────────────────────────────────
  // Catches 401 for PUT / DELETE (which don't override validateStatus).
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final String path = err.requestOptions.path;
    final int? statusCode = err.response?.statusCode;

    // Log for debugging
    final friendlyMessage = ApiErrorHandler.getErrorMessage(err);
    kPrintError("API Error [$path] | Status: $statusCode | $friendlyMessage");

    _logToExternalService(err);

    if (statusCode == 401 && !_isAuthPath(path)) {
      final storage = locator<LocalStorageService>();
      final token = await storage.token;
      if (token != null && token.isNotEmpty) {
        kPrintError(
          "Session expired (onError 401) at $path. Triggering auto-logout.",
        );
        await _performAutoLogout();
      }
    }

    return handler.next(err);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _logToExternalService(DioException err) {
    if (kDebugMode) return;
    final path = err.requestOptions.path;
    final status = err.response?.statusCode;
    FirebaseCrashlytics.instance.recordError(
      err,
      err.stackTrace,
      reason: 'API Error: $path → $status',
      fatal: false,
    );
  }

  Future<void> _performAutoLogout() async {
    if (_isLoggingOut) return; // already in progress — skip
    _isLoggingOut = true;

    try {
      final storage = locator<LocalStorageService>();
      final token = await storage.token;

      // If no token exists, the user is likely a Guest or already logged out.
      // We shouldn't trigger the "Session Expired" UX.
      if (token == null || token.isEmpty) {
        _isLoggingOut = false;
        return;
      }

      await storage.clearAll();

      // Navigate to login, clearing the entire stack.
      AppNavigator.removeAndGo(AppRoutes.login);

      // Show a session-expired snackbar on the new page after it is built.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = AppNavigator.navigatorKey.currentContext;
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Session expired. Please login again.'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        _isLoggingOut = false; // reset after navigation completes
      });
    } catch (e) {
      _isLoggingOut = false;
      kPrintError('_performAutoLogout error: $e');
    }
  }
}
