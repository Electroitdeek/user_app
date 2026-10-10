import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/storage/local_storage_service.dart';
import 'package:adhisaat_health_care/features/user/profile/data/user_profile_repository.dart';
import 'package:adhisaat_health_care/features/user/support_ticket/data/support_ticket_repository.dart';
import 'package:get_it/get_it.dart';

import '../core/api/api_client.dart';
import '../core/services/app_clock.dart';
import '../core/services/deep_link_service.dart';
import '../core/services/location_service.dart';
import '../core/services/network_service.dart';
import '../core/services/notification_service.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/blood_donation_repository.dart';
import '../data/repositories/dropdown_repository.dart';
import '../data/repositories/faq_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../data/repositories/provider_repository.dart';
import '../data/repositories/system_settings_repository.dart';
import '../features/faq/bloc/faq_bloc.dart';
import '../features/service_provider/availability/data/repositories/availability_repository.dart';
import '../features/service_provider/notification/bloc/provider_notification_bloc.dart';
import '../features/service_provider/provider_requests/data/repositories/provider_request_repository.dart';
import '../features/user/address/data/user_address_repository.dart';
import '../features/user/emergency/data/emergency_service_repository.dart';
import '../features/user/extend_booking/data/extend_booking_repository.dart';
import '../features/user/family/data/family_repository.dart';
import '../features/user/health_records/bloc/health_record_bloc.dart';
import '../features/user/health_records/data/health_record_repository.dart';
import '../features/user/notification/bloc/notification_bloc.dart';
import '../features/user/payment/data/payment_repository.dart';
import '../features/user/refer_earn/bloc/refer_earn_bloc.dart';
import '../features/user/service_booking/bloc/service_request_bloc.dart';
import '../features/user/service_booking/bloc/sub_category_bloc.dart';
import '../features/user/service_booking/data/nearby_provider_repository.dart';
import '../features/user/service_booking/data/rating_repository.dart';
import '../features/user/service_booking/data/service_category_repository.dart';
import '../features/user/service_booking/data/service_request_repository.dart';
import '../features/user/wallet/data/wallet_repository.dart';

import '../core/services/analytics_service.dart';
import '../core/services/facebook_service.dart';

final locator = GetIt.instance;

Future<void> setupLocator() async {
  // 1. Core Services
  locator.registerLazySingleton<AnalyticsService>(() => AnalyticsService());
  locator.registerLazySingleton<NotificationService>(() => NotificationService());
  locator.registerLazySingleton<LocalStorageService>(() => LocalStorageService());
  locator.registerLazySingleton<ApiClient>(() => ApiClient());
  locator.registerLazySingleton<NetworkService>(() => NetworkService());
  locator.registerLazySingleton<AppNavigator>(() => AppNavigator());
  locator.registerLazySingleton<LocationService>(() => LocationService());
  locator.registerLazySingleton<DeepLinkService>(() => DeepLinkService());
  locator.registerLazySingleton<AppClock>(() => AppClock());
  locator.registerLazySingleton<FacebookService>(() => FacebookService());

  // 2. Repositories
  locator.registerLazySingleton<AuthRepository>(
    () => AuthRepository(locator<ApiClient>(), locator<LocalStorageService>()),
  );
  locator.registerLazySingleton<BloodDonationRepository>(() => BloodDonationRepository(locator<ApiClient>()));

  locator.registerLazySingleton<ProviderRepository>(
    () => ProviderRepository(locator<ApiClient>(), locator<LocalStorageService>()),
  );
  locator.registerLazySingleton<DropdownRepository>(() => DropdownRepository(locator<ApiClient>()));
  locator.registerLazySingleton<AvailabilityRepository>(() => AvailabilityRepository());

  locator.registerLazySingleton<ProviderRequestRepository>(() => ProviderRequestRepository());

  locator.registerLazySingleton<ServiceCategoryRepository>(
    () => ServiceCategoryRepository(locator<ApiClient>(), locator<LocalStorageService>()),
  );
  locator.registerLazySingleton<EmergencyServiceRepository>(
    () => EmergencyServiceRepository(locator<ApiClient>()),
  );

  locator.registerLazySingleton<UserAddressRepository>(() => UserAddressRepository(locator<ApiClient>()));

  locator.registerLazySingleton<UserProfileRepository>(
    () => UserProfileRepository(locator<ApiClient>(), locator<LocalStorageService>()),
  );

  locator.registerLazySingleton<FamilyRepository>(() => FamilyRepository(locator<ApiClient>()));

  // New repositories for booking flow
  locator.registerLazySingleton<NearbyProviderRepository>(() => NearbyProviderRepository(locator<ApiClient>()));
  locator.registerLazySingleton<PaymentRepository>(() => PaymentRepository(locator<ApiClient>()));
  locator.registerLazySingleton<WalletRepository>(() => WalletRepository(locator<ApiClient>()));
  locator.registerLazySingleton<ExtendBookingRepository>(() => ExtendBookingRepository(locator<ApiClient>()));
  locator.registerFactory(() => SubCategoryBloc(locator<ServiceCategoryRepository>()));

  // Service Request / Booking History BLoC
  locator.registerFactory(() => ServiceRequestBloc(locator<ServiceRequestRepository>()));
  locator.registerLazySingleton<ServiceRequestRepository>(() => ServiceRequestRepository(locator<ApiClient>()));
  locator.registerLazySingleton<RatingRepository>(() => RatingRepository(locator<ApiClient>()));

  locator.registerLazySingleton<HealthRecordRepository>(() => HealthRecordRepository(locator<ApiClient>()));
  locator.registerLazySingleton<NotificationRepository>(() => NotificationRepository(locator<ApiClient>()));
  locator.registerLazySingleton<SupportTicketRepository>(() => SupportTicketRepository(locator<ApiClient>()));
  locator.registerLazySingleton<SystemSettingsRepository>(() => SystemSettingsRepository(locator<ApiClient>()));
  locator.registerLazySingleton<FaqRepository>(() => FaqRepository(locator<ApiClient>()));

  // HealthRecordBloc is registered as a factory (new instance per page)
  locator.registerFactory<HealthRecordBloc>(
    () => HealthRecordBloc(
      healthRepo: locator<HealthRecordRepository>(),
      familyRepo: locator<FamilyRepository>(), // already registered
    ),
  );
  locator.registerFactory<NotificationBloc>(() => NotificationBloc(repository: locator<NotificationRepository>()));
  locator.registerFactory<ProviderNotificationBloc>(
    () => ProviderNotificationBloc(locator<NotificationRepository>()),
  );
  locator.registerFactory<ReferEarnBloc>(
    () => ReferEarnBloc(locator<ApiClient>(), locator<UserProfileRepository>()),
  );
  locator.registerFactory<FaqBloc>(() => FaqBloc(locator<FaqRepository>()));

  await _initializeAsyncServices();
}

Future<void> _initializeAsyncServices() async {
  await locator<NetworkService>().initialize();
}
