import 'package:adhisaat_health_care/app.dart';
import 'package:adhisaat_health_care/core/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_flavor/flutter_flavor.dart';

import 'core/config/env_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  // Keep portrait-only
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  FlavorConfig(
    variables: {
      "baseUrl": EnvConfig.prodBaseUrl,
      "appName": AppConstants.providerAppName,
      'role': 'provider',
      'env': 'prod',
    },
  );

  await runMainApp();
}
