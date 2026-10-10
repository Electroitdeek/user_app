import 'package:adhisaat_health_care/core/config/env_config.dart';
import 'package:flutter_flavor/flutter_flavor.dart';

class AppConstants {
  AppConstants._();

  static FlavorConfig get _flavor => FlavorConfig.instance;

  static bool get isProd => (_flavor.variables['env'] as String?)?.toLowerCase() == 'prod';

  static bool get isDev => !isProd;

  static bool get isProviderApp => (_flavor.variables['role'] as String?)?.toLowerCase() == 'provider';

  static bool get isUserApp => !isProviderApp;

  static String get appDisplayName => _flavor.variables['appName'] as String? ?? 'Adhisaat';

  static const String providerAppName = 'Adhisaat Partner';
  static const String userAppName = 'Adhisaat Health Care';

  static final String appName = appDisplayName;
  static const String appTagline = '• Trust • Care • Support';
  static const String appDevelopedBy = 'KUMA VENTURES PRIVATE LIMITED';
  static final String baseUrl = FlavorConfig.instance.variables["baseUrl"] ?? EnvConfig.prodBaseUrl;
  static String userPlayStoreUrl = 'https://play.google.com/store/apps/details?id=com.adhisaat.app';
  static String userAppStoreUrl = 'https://apps.apple.com/app/id6761096533';
  static String partnerPlayStoreUrl = 'https://play.google.com/store/apps/details?id=com.adhisaat.provider';
  static String partnerAppStoreUrl = 'https://apps.apple.com/app/id6761734492';

  // ── Support Contact ──────────────────────────────────────────────────────
  /// Partner app shared customer phone number
  static const String partnerCustomerPhone = '9649221110';
  static const String customerPartnerPhone = '9549221110';

  /// Primary phone used for tel: deep-link
  static const String supportPhone = '+917023221110';

  /// Alternate / landline number (display only)
  static const String supportPhoneAlt = '0141-2221110';

  /// Full display string shown in the Help page
  static const String supportPhoneDisplay = '+91-7023221110';

  /// Pre-built WhatsApp deep-link (official wa.me URL with pre-filled message)
  static const String supportWhatsAppUrl =
      'https://api.whatsapp.com/send/?phone=917023221110'
      '&text=Hello%20Adhisaat%20Support%2C%20I%20need%20assistance'
      '&type=phone_number&app_absent=0';

  /// Primary email used for mailto: deep-link
  static const String supportEmail = 'info@adhisaat.com';

  /// Second support email (display only)
  static const String supportEmailAlt = 'info@adhisaat.com';

  /// Display string for the Help page
  static const String supportEmailDisplay = 'info@adhisaat.com';

  /// Availability badge shown on contact cards
  static const String supportHours = 'Mon–Sun · 24×7';

  // ── Cache Keys ────────────────────────────────────────────────────────────
  static const String cachedZipCode = 'cached_zip_code';

  // ── File Limits ───────────────────────────────────────────────────────────
  static const int maxFileSizeMB = 10;
  static const int maxFileSize = maxFileSizeMB * 1024 * 1024;
}
