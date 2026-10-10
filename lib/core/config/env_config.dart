import 'package:flutter_dotenv/flutter_dotenv.dart';

/*
dart run build_runner build --delete-conflicting-outputs
*/
class EnvConfig {
  static String get googleMapsApiKeyAndroid => dotenv.env['GOOGLE_MAPS_API_KEY_ANDROID'] ?? '';

  static String get googleMapsApiKeyIOS => dotenv.env['GOOGLE_MAPS_API_KEY_IOS'] ?? '';

  // API Base URLs
  static String get webBaseUrl => dotenv.env['WEB_BASE_URL'] ?? '';

  static String get prodBaseUrl => dotenv.env['PROD_API_BASE_URL'] ?? '';

  static String get devBaseUrl => dotenv.env['DEV_API_BASE_URL'] ?? '';
}
