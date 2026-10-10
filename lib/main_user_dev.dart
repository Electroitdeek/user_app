import 'package:adhisaat_health_care/app.dart';
import 'package:adhisaat_health_care/core/config/env_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_flavor/flutter_flavor.dart';

import 'core/constants/app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  // Keep portrait-only
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  FlavorConfig(
    name: kDebugMode ? "DEV" : null,
    color: Colors.red,
    location: BannerLocation.topStart,
    variables: {"baseUrl": EnvConfig.devBaseUrl, "appName": "${AppConstants.appName} Dev", 'role': 'user', 'env': 'dev'},
  );

  await runMainApp();
}

// flutter run --flavor dev lib/main_dev.dart
