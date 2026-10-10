import 'dart:io';

import '../config/env_config.dart';
import '../constants/app_constants.dart';

class RedirectionUrl {
  static final String webBaseUrl = EnvConfig.webBaseUrl;
  static final String userTermsConditions = "$webBaseUrl/terms-conditions#user";
  static final String partnerTermsConditions = "$webBaseUrl/terms-conditions#provider";
  static final String patientConsent = "$webBaseUrl/terms-conditions#patient";
  static final String privacyPolicy = "$webBaseUrl/privacy-policy";
  static final String helpSupport = "$webBaseUrl/contact-us";
  static final String engagementAgreement = "$webBaseUrl/adhisaathi-engagement-agreement";
  static final String patientConsentForm = "$webBaseUrl/patient-consent-form";
  static final String cancellationPolicy = "$webBaseUrl/cancellation-policy";
  static final String refundPolicy = "$webBaseUrl/cancellation-policy";
  static final String medicoLegalPolicy = "$webBaseUrl/medico-legal-policy";
  static final String faq = "$webBaseUrl/faq";

  static final String deleteAccount = "${AppConstants.baseUrl}/delete-account";
  static final String shareApp = Platform.isIOS ? AppConstants.userAppStoreUrl : AppConstants.userPlayStoreUrl;
  static final String partnerShareApp = Platform.isIOS ? AppConstants.partnerAppStoreUrl : AppConstants.partnerPlayStoreUrl;
  // static final String rateThisApp = "https://play.google.com/store/apps/details?id=com.adhisaat.app";
  static final String aboutUs = "$webBaseUrl/about-us";
  static final String howToUse = '$webBaseUrl/how-it-work';
  static final String workPartnerApp = "$webBaseUrl/work-partner-app";

  // Social media
  static const String instagram = "https://www.instagram.com/adhisaatindia";
  static const String facebook = "https://www.facebook.com/adhisaatindia";
}
