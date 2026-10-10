// DEVELOPMENT HANDOVER TEMPLATE
// DO NOT use production Firebase credentials in this development copy.
// Configure a dedicated DEVELOPMENT Firebase project using FlutterFire CLI.
// After configuration, replace this file with the generated firebase_options.dart.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web Firebase configuration is not configured.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'Development Firebase is not configured. Create/use a dedicated development Firebase project and run FlutterFire configuration before running the app.',
        );
      default:
        throw UnsupportedError('Firebase is not configured for this platform.');
    }
  }

  // Local debug placeholders so USB installs can start. Replace with FlutterFire output.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDummyKeyForLocalDebugBuild000001',
    appId: '1:123456789012:android:aaaaaaaaaaaaaaaa',
    messagingSenderId: '123456789012',
    projectId: 'adhisaat-dev-local',
    storageBucket: 'adhisaat-dev-local.appspot.com',
  );
}
