import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../api/api_client.dart';

class AppBlocObserver extends BlocObserver {
  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    kPrintError('[BLoC] ${bloc.runtimeType}: $error');
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: 'BLoC error in ${bloc.runtimeType}',
      );
    }
    super.onError(bloc, error, stackTrace);
  }
}
