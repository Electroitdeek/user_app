import 'package:adhisaat_health_care/core/widgets/network_connection/retry_on_network_widget.dart';
import 'package:adhisaat_health_care/features/auth/splash/splash_screen.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_home/view/service_provider_dashboard_page.dart';
import 'package:adhisaat_health_care/features/user/address/bloc/selected_address_provider.dart';
import 'package:adhisaat_health_care/features/user/home/view/user_dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_flavor/flutter_flavor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/deep_link_service.dart';
import '../../../../core/services/network_service.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/widgets/network_connection/error_screen.dart';
import '../../../../core/widgets/network_connection/network_aware_widget.dart';
import '../../../../data/repositories/provider_repository.dart';
import '../../../../data/shared_blocs/user_profile_bloc.dart';
import '../../../../di/locator.dart';
import '../../../../features/user/home/view/user_home_page.dart';
import '../../../../features/user/notification/bloc/notification_bloc.dart';
import '../../../../features/user/service_booking/bloc/service_category_bloc.dart';
import '../../../../features/user/service_booking/bloc/service_request_bloc.dart';
import '../../../../features/user/service_booking/data/service_category_repository.dart';
import '../../../../features/user/service_booking/data/service_request_repository.dart';
import '../../intro/view/onboarding_page.dart';
import '../../login/bloc/auth_bloc.dart';
import '../../login/view/login_page.dart';
import '../../../../core/services/permission_gate.dart';
import '../data/role_enums.dart';
import '../../../../data/providers/user_profile_provider.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NetworkAwareWidget(
      builder: (context, status) {
        if (status != NetworkStatus.offline) {
          return BlocConsumer<AuthBloc, AuthState>(
            listenWhen: (_, current) =>
                current is AuthAuthenticated || current is AuthUnauthenticated,
            listener: (context, state) {
              // Load the saved address for any user who has the customer role.
              // Using hasCustomerRole (roles list) ensures dual-role users in
              // the user app also get their address initialised correctly.
              if (state is AuthAuthenticated && state.user.hasCustomerRole) {
                ref
                    .read(selectedAddressProvider.notifier)
                    .loadForLoggedInUser(force: true);

                // Sync profile to Riverpod provider for consumers like UserHomePage
                ref.read(userProfileProvider.notifier).state = state.user;
              }

              if (state is AuthAuthenticated) {
                locator<DeepLinkService>().processPendingLink();
              }

              if (state is AuthUnauthenticated) {
                ref.read(selectedAddressProvider.notifier).clearAddress();
                ref.read(userProfileProvider.notifier).state = null;
              }

              // Guard: Provider app doesn't allow customer-only users
              if (state is AuthAuthenticated &&
                  AppConstants.isProviderApp &&
                  state.user.userRole != UserRole.provider) {
                context.read<AuthBloc>().add(LogoutRequested());
              }
            },
            buildWhen: (previous, current) =>
                current is AuthInitializeLoading ||
                current is AuthLoggingOut ||
                current is AuthAuthenticated ||
                current is AuthGuest ||
                current is AuthUnauthenticated ||
                current is AuthNetworkError ||
                current is AuthError,
            builder: (context, state) {
              if (state is AuthInitializeLoading) {
                return const SplashPage();
              }

              if (state is AuthAuthenticated) {
                final isProviderApp = AppConstants.isProviderApp;
                final isProviderUser = state.user.userRole == UserRole.provider;

                if (isProviderApp && !isProviderUser) {
                  // While logout is processing in the listener, show login or splash
                  return const LoginPage();
                }

                return PermissionGate(
                  child: BlocProvider(
                    create: (_) => UserBloc(
                      locator<ProviderRepository>(),
                      initialUser: state.user,
                    ),
                    child: (isProviderApp && isProviderUser)
                        ? ProviderDashboardPage()
                        : const UserDashboardPage(),
                  ),
                );
              }

              if (state is AuthGuest) {
                return MultiBlocProvider(
                  providers: [
                    BlocProvider(
                      create: (_) => UserBloc(locator<ProviderRepository>()),
                    ),
                    BlocProvider<ServiceCategoryBloc>(
                      create: (_) =>
                          ServiceCategoryBloc(
                            locator<ServiceCategoryRepository>(),
                          )..add(
                            LoadServiceCategories(
                              // useCacheFirst: true,
                              isEmergency: false,
                            ),
                          ),
                    ),
                    BlocProvider<ServiceRequestBloc>(
                      create: (context) => ServiceRequestBloc(
                        locator<ServiceRequestRepository>(),
                      ),
                    ),
                    BlocProvider<NotificationBloc>(
                      create: (context) => locator<NotificationBloc>(),
                    ),
                  ],
                  child: const UserHomePage(),
                );
              }

              if (state is AuthUnauthenticated) {
                final role = FlavorConfig.instance.variables['role'] ?? 'user';
                final isOnboardingComplete = locator<LocalStorageService>()
                    .isOnboardingComplete(role);
                if (!isOnboardingComplete) {
                  return const OnboardingPage();
                }
                return const LoginPage();
              }

              if (state is AuthNetworkError) {
                return RetryOnNetworkWidget(
                  message: state.message,
                  onRetry: () => context.read<AuthBloc>().add(RetryAuthCheck()),
                );
              }

              if (state is AuthError) {
                if (state.isGlobal) {
                  return ErrorScreen(
                    message: state.message,
                    onRetry: () =>
                        context.read<AuthBloc>().add(CheckAuthStatus()),
                  );
                }
                // For login errors, keep the user on the login page to see the integrated warning
                return const LoginPage();
              }

              return const SplashPage();
            },
          );
        } else {
          return RetryOnNetworkWidget(
            message: "No Internet Connection",
            onRetry: () => context.read<AuthBloc>().add(RetryAuthCheck()),
          );
        }
      },
    );
  }
}
