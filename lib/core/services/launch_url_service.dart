import 'dart:io';

import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/constants/app_constants.dart';
import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class LaunchUrlService {
  LaunchUrlService._();

  static Future<void> launchGoogleMaps(double lat, double lng) async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> launchInAppWebUrl(String url) async {
    launchWebUrl(url, mode: LaunchMode.inAppBrowserView);
  }

  static Future<void> launchWebUrl(String url, {bool inApp = false, String? title, LaunchMode? mode}) async {
    if (inApp) {
      AppNavigator.to(AppRoutes.webView, arguments: {'url': url, 'title': title ?? ''});
      return;
    }
    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: mode ?? LaunchMode.externalApplication);
      } else {
        kPrintError("Could not launch $url");
      }
    } catch (e) {
      kPrintError("Error launching URL: $e");
    }
  }

  static Future<void> rateApp() async {
    // ── iOS: App Store ──────────────────────────────────────────────────────
    // Replace YOUR_APP_ID with your numeric App Store ID (e.g. "6504XXXXXXX")
    final appStoreUrl = AppConstants.userAppStoreUrl;
    final iosStoreUrl = '$appStoreUrl?action=write-review';
    // ── Android: Play Store ─────────────────────────────────────────────────
    const packageName = 'com.adhisaat.app';
    final Uri marketUri = Uri.parse('market://details?id=$packageName&showAllReviews=true');
    final Uri playStoreUri = Uri.parse('${AppConstants.userPlayStoreUrl}&showAllReviews=true');

    try {
      if (Platform.isIOS) {
        final uri = Uri.parse(iosStoreUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        // Android only — never shown to iOS App Store reviewers
        if (await canLaunchUrl(marketUri)) {
          await launchUrl(marketUri);
        } else if (await canLaunchUrl(playStoreUri)) {
          await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      kPrintError('Error launching store: $e');
    }
  }

  static Future<void> makePhoneCall(String phoneNumber) async {
    final url = 'tel:$phoneNumber';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  static Future<void> launchEmail({required String to, String subject = '', String body = ''}) async {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: to,
      query: _encodeQueryParameters(<String, String>{
        if (subject.isNotEmpty) 'subject': subject,
        if (body.isNotEmpty) 'body': body,
      }),
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Fallback: open a plain mailto: without query params
        final fallback = Uri(scheme: 'mailto', path: to);
        if (await canLaunchUrl(fallback)) {
          await launchUrl(fallback);
        } else {
          kPrintError('No email client available for $to');
        }
      }
    } catch (e) {
      kPrintError('Error launching email: $e');
    }
  }

  // Helper function to encode query parameters properly (replaces ' ' with '%20' instead of '+')
  static String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
  }

  static Future<void> shareText(String text, {String? subject}) async {
    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: subject));
    } catch (e) {
      kPrintError("Error sharing text: $e");
    }
  }

  static Future<void> launchWhatsApp(String text) async {
    final url = "whatsapp://send?text=${Uri.encodeComponent(text)}";
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Fallback to web version if app not installed
        final webUrl = "https://wa.me/?text=${Uri.encodeComponent(text)}";
        await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      kPrintError("Error launching WhatsApp: $e");
    }
  }
}
