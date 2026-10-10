import 'package:facebook_app_events/facebook_app_events.dart';
import '../api/api_client.dart';

class FacebookService {
  final FacebookAppEvents _facebookAppEvents;

  FacebookService({FacebookAppEvents? facebookAppEvents})
      : _facebookAppEvents = facebookAppEvents ?? FacebookAppEvents();

  /// Logs a custom Meta App Event for Facebook Ads & Analytics tracking.
  Future<void> logEvent({
    required String name,
    Map<String, dynamic>? parameters,
    double? valueToSum,
  }) async {
    try {
      await _facebookAppEvents.logEvent(
        name: name,
        parameters: parameters,
        valueToSum: valueToSum,
      );
      kPrint('Meta App Event Logged: $name, Params: $parameters');
    } catch (e) {
      kPrint('Error logging Meta event ($name): $e');
    }
  }

  /// Logs a Purchase event for Facebook Ads Conversion Tracking.
  Future<void> logPurchase({
    required double amount,
    required String currency,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      await _facebookAppEvents.logPurchase(
        amount: amount,
        currency: currency,
        parameters: parameters,
      );
      kPrint('Meta Purchase Event Logged: $amount $currency');
    } catch (e) {
      kPrint('Error logging Meta purchase event: $e');
    }
  }

  /// Logs when a user completes registration/signup.
  Future<void> logCompletedRegistration({String registrationMethod = 'phone'}) async {
    try {
      await _facebookAppEvents.logCompletedRegistration(
        registrationMethod: registrationMethod,
      );
      kPrint('Meta Completed Registration Logged ($registrationMethod)');
    } catch (e) {
      kPrint('Error logging Meta completed registration event: $e');
    }
  }

  /// Sets the logged-in user ID for accurate analytics tracking across sessions.
  Future<void> setUserId(String userId) async {
    try {
      await _facebookAppEvents.setUserID(userId);
      kPrint('Meta Analytics User ID set: $userId');
    } catch (e) {
      kPrint('Error setting Meta User ID: $e');
    }
  }

  /// Clears the user ID when the user logs out.
  Future<void> clearUserId() async {
    try {
      await _facebookAppEvents.clearUserID();
      kPrint('Meta Analytics User ID cleared.');
    } catch (e) {
      kPrint('Error clearing Meta User ID: $e');
    }
  }
}
/*final facebookService = locator<FacebookService>();

// 1. Log Payment/Booking Purchase (for Facebook Ad ROAS tracking)
facebookService.logPurchase(
  amount: 499.0,
  currency: 'INR',
  parameters: {'service_name': 'Nursing Care'},
);

// 2. Log Registration/Signup Completed
facebookService.logCompletedRegistration(registrationMethod: 'phone');

// 3. Log any Custom Event
facebookService.logEvent(
  name: 'booking_requested',
  parameters: {'category_id': '12'},
);
*/