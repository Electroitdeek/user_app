import 'package:firebase_analytics/firebase_analytics.dart';
import '../api/api_client.dart';

class AnalyticsService {
  final FirebaseAnalytics _analytics;

  AnalyticsService({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  FirebaseAnalytics get analytics => _analytics;

  /// Observer for tracking screen views automatically via MaterialApp.navigatorObservers
  FirebaseAnalyticsObserver get analyticsObserver =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// Sets the logged-in user ID for Google Analytics tracking.
  Future<void> setUserId(String userId) async {
    try {
      await _analytics.setUserId(id: userId);
      kPrint('GA: User ID set to $userId');
    } catch (e) {
      kPrintError('GA Error setting User ID: $e');
    }
  }

  /// Sets custom user properties (e.g., user_role: 'provider' | 'patient').
  Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
      kPrint('GA: User Property set ($name = $value)');
    } catch (e) {
      kPrintError('GA Error setting user property ($name): $e');
    }
  }

  /// Logs a sign_up event in Google Analytics.
  Future<void> logSignUp({String signUpMethod = 'phone_otp'}) async {
    try {
      await _analytics.logSignUp(signUpMethod: signUpMethod);
      kPrint('GA Sign Up Logged (Method: $signUpMethod)');
    } catch (e) {
      kPrintError('GA Error logging sign_up event: $e');
    }
  }

  /// Logs a custom event in Google Analytics.
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
      kPrint('GA Event Logged: $name, Params: $parameters');
    } catch (e) {
      kPrintError('GA Error logging event ($name): $e');
    }
  }

  /// Logs a purchase event for booking transactions.
  Future<void> logPurchase({
    required double value,
    required String currency,
    required String transactionId,
    List<AnalyticsEventItem>? items,
  }) async {
    try {
      await _analytics.logPurchase(
        value: value,
        currency: currency,
        transactionId: transactionId,
        items: items,
      );
      kPrint('GA Purchase Event Logged: $transactionId ($value $currency)');
    } catch (e) {
      kPrintError('GA Error logging purchase event: $e');
    }
  }

  /// Clears user data on logout.
  Future<void> clearUser() async {
    try {
      await _analytics.setUserId(id: null);
      await _analytics.resetAnalyticsData();
      kPrint('GA: Analytics user cleared on logout.');
    } catch (e) {
      kPrintError('GA Error clearing user data: $e');
    }
  }
}
