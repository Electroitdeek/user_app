import 'package:flutter/material.dart';
import '../../../core/api/redirection_url.dart';
import '../../../core/services/launch_url_service.dart';
import '../../../core/utils/message_service.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../di/locator.dart';
import '../widgets/dialogs/consent_bottom_sheet.dart';
import '../widgets/dialogs/dialog_helpers.dart';

class ConsentHelper {
  ConsentHelper._();

  /// Fetches consent from API and shows the bottom sheet.
  /// [consentType] is the type of consent to fetch (e.g., 'provider_registration').
  /// [onAgree] is called when the user taps the Agree button in the bottom sheet.
  static Future<void> show({
    required BuildContext context,
    required String consentType,
    int? cityAdminId,
    VoidCallback? onAgree,
    bool silentFailure = false,
    bool viewOnly = false,
    // When consent list is empty / fetch fails, open the Terms & Conditions
    // web page instead of showing an error.
    bool fallbackToTermsOnEmpty = false,
  }) async {
    try {
      // 1. Show loading dialog
      DialogHelper.showLoading(message: 'Fetching consent...');

      // 2. Fetch consent data
      final repository = locator<AuthRepository>();
      final response = await repository.fetchConsents(consentType, cityAdminId: cityAdminId);

      // 3. Close loading dialog (pushed on the root navigator via global key)
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (response['status'] == true) {
        final List<dynamic> consents = response['data'] ?? [];
        if (consents.isNotEmpty) {
          final consent = consents.first;
          final String title = consent['title'] ?? 'Consent';
          final String content = consent['content'] ?? '';

          if (context.mounted) {
            // 4. Show the bottom sheet
            await ConsentBottomSheet.show(
              context: context,
              title: title,
              content: content,
              onAgree: onAgree,
              viewOnly: viewOnly,
            );
          }
        } else {
          if (fallbackToTermsOnEmpty) {
            LaunchUrlService.launchInAppWebUrl(RedirectionUrl.userTermsConditions);
          } else if (silentFailure) {
            onAgree?.call();
          } else {
            MessageService.showError('No consent data found.');
          }
        }
      } else {
        if (fallbackToTermsOnEmpty) {
          LaunchUrlService.launchInAppWebUrl(RedirectionUrl.userTermsConditions);
        } else if (silentFailure) {
          onAgree?.call();
        } else {
          MessageService.showError(response['message'] ?? 'Failed to fetch consent.');
        }
      }
    } catch (e) {
      // Close loading dialog if error occurs
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (fallbackToTermsOnEmpty) {
        LaunchUrlService.launchInAppWebUrl(RedirectionUrl.userTermsConditions);
      } else if (silentFailure) {
        onAgree?.call();
      } else {
        MessageService.showError('Error fetching consent: $e');
      }
    }
  }
}
