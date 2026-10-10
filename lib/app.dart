import 'package:adhisaat_health_care/core/constants/app_constants.dart';
import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/services/network_service.dart';
import 'package:adhisaat_health_care/features/auth/auth_wrapper/view/auth_wrapper.dart';
import 'package:adhisaat_health_care/features/auth/auth_wrapper/view/network_wrapper.dart';
import 'package:adhisaat_health_care/core/services/permission_gate.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_flavor/flutter_flavor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:path_provider/path_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'core/navigation/app_routes.dart';
import 'core/services/app_update_service.dart';
import 'core/utils/app_bloc_observer.dart';
import 'core/services/notification_service.dart';
import 'core/services/deep_link_service.dart';
import 'core/storage/local_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/dropdown_repository.dart';
import 'data/shared_blocs/dropdown/dropdown_bloc.dart';
import 'data/shared_blocs/dropdown/dropdown_event.dart';
import 'core/services/analytics_service.dart';
import 'di/locator.dart';
import 'features/auth/login/bloc/auth_bloc.dart';
import 'firebase_options.dart';

Future<void> runMainApp() async {
  // ── Ensure status bar + navigation bar are always visible (iOS & Android) ─
  // edgeToEdge lets the app draw behind system bars (modern look) while still
  // keeping them rendered — fixes iOS status bar disappearing entirely.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light, // iOS: dark-content (dark icons)
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Load Hive into private Application Support directory (hidden from iOS Files app)
  final appSupportDir = await getApplicationSupportDirectory();
  Hive.init(appSupportDir.path);
  await setupLocator(); // init GetIt

  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Initialize Firebase (Note: for real production, you might have different Firebase projects/options)
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Initialize Crashlytics
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };
    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (e, st) {
    debugPrint('Firebase init skipped (configure a dedicated dev Firebase project): $e\n$st');
  }

  Bloc.observer = AppBlocObserver();

  // Persist app role so the FCM background isolate can filter send_to
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('_app_role', AppConstants.isProviderApp ? 'provider' : 'user');

  await locator<LocalStorageService>().init();
  await locator<NotificationService>().initialize();
  locator<DeepLinkService>().init();

  // Check for app updates (usually only in prod)
  if (FlavorConfig.instance.name == "PROD") {
    await AppUpdateService().initializeUpdateCheck();
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FlavorBanner(
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return AppUpdateWrapper(
            child: MultiBlocProvider(
              providers: [
                BlocProvider<AuthBloc>(
                  create: (_) => AuthBloc(
                    repository: locator<AuthRepository>(),
                    storage: locator<LocalStorageService>(),
                    networkService: locator<NetworkService>(),
                  )..add(CheckAuthStatus()),
                ),
                BlocProvider<DropdownBloc>(
                  create: (_) => DropdownBloc(locator<DropdownRepository>())..add(FetchDropdownData()),
                ),
              ],
              child: MaterialApp(
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [Locale('en', 'IN')],
                locale: const Locale('en', 'IN'),
                theme: AppTheme.light(),
                title: AppConstants.appName,
                navigatorKey: AppNavigator.navigatorKey,
                navigatorObservers: [locator<AnalyticsService>().analyticsObserver],
                debugShowCheckedModeBanner: false,
                onGenerateRoute: AppRoutes.onGenerateRoute,
                builder: (context, mChild) {
                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                    child: mChild!,
                  );
                },
                home: child,
              ),
            ),
          );
        },
        child: NetworkWrapper(
          child: AppConstants.isProviderApp
              ? const PermissionGate(child: AuthWrapper())
              : const AuthWrapper(),
        ),
      ),
    );
  }
}
