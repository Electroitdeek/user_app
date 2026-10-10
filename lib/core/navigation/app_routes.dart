import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/constants/app_constants.dart';
import 'package:adhisaat_health_care/core/storage/local_storage_service.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/data/repositories/provider_repository.dart';
import 'package:adhisaat_health_care/data/repositories/system_settings_repository.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/features/auth/splash/splash_screen.dart';
import 'package:adhisaat_health_care/features/faq/view/faq_page.dart';
import 'package:adhisaat_health_care/features/service_provider/availability/view/provider_availability_page.dart';
import 'package:adhisaat_health_care/features/service_provider/bank_detail/view/provider_bank_detail_add_edit_page.dart';
import 'package:adhisaat_health_care/features/service_provider/bank_detail/view/provider_bank_detail_page.dart';
import 'package:adhisaat_health_care/features/service_provider/document/view/provider_document_list_page.dart';
import 'package:adhisaat_health_care/features/service_provider/feedback/bloc/feedback_bloc.dart';
import 'package:adhisaat_health_care/features/service_provider/feedback/view/provider_feedback_page.dart';
import 'package:adhisaat_health_care/features/service_provider/manage_categories/view/manage_categories_page.dart';
import 'package:adhisaat_health_care/features/service_provider/notification/view/provider_notification_page.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_profile/blocs/profile_bloc/provider_profile_bloc.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/view/provider_request_detail_page.dart';
import 'package:adhisaat_health_care/features/user/address/data/user_address_repository.dart';
import 'package:adhisaat_health_care/features/user/address/view/user_address_add_edit_page.dart';
import 'package:adhisaat_health_care/features/user/emergency/bloc/emergency_map/emergency_map_bloc.dart';
import 'package:adhisaat_health_care/features/user/health_records/view/health_record_page.dart';
import 'package:adhisaat_health_care/features/user/home/view/search_service_page.dart';
import 'package:adhisaat_health_care/features/user/home/view/user_home_page.dart';
import 'package:adhisaat_health_care/features/user/notification/bloc/notification_bloc.dart';
import 'package:adhisaat_health_care/features/user/notification/view/user_notification_page.dart';
import 'package:adhisaat_health_care/features/user/profile/bloc/user_feedback_bloc.dart';
import 'package:adhisaat_health_care/features/user/profile/data/user_profile_repository.dart';
import 'package:adhisaat_health_care/features/user/profile/view/app_feedback_page.dart';
import 'package:adhisaat_health_care/features/user/service_booking/bloc/service_category_bloc.dart';
import 'package:adhisaat_health_care/features/user/service_booking/bloc/service_request_bloc.dart';
import 'package:adhisaat_health_care/features/user/service_booking/data/service_category_repository.dart';
import 'package:adhisaat_health_care/features/user/service_booking/data/service_request_repository.dart';
import 'package:adhisaat_health_care/features/user/wallet/bloc/wallet_bloc.dart';
import 'package:adhisaat_health_care/features/user/wallet/bloc/wallet_state.dart';
import 'package:adhisaat_health_care/features/user/wallet/data/wallet_repository.dart';
import 'package:adhisaat_health_care/features/user/wallet/view/add_money_page.dart';
import 'package:adhisaat_health_care/features/user/wallet/view/wallet_history_page.dart';
import 'package:adhisaat_health_care/shared/pages/need_help_page.dart';
import 'package:adhisaat_health_care/shared/widgets/common/web_view_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/provider_models/bank_detail_model.dart';
import '../../features/auth/login/view/login_page.dart';
import '../../features/service_provider/earnings/view/provider_earning_list_page.dart';
import '../../features/service_provider/provider_home/bloc/provider_tracking_bloc/provider_tracking_bloc.dart';
import '../../features/service_provider/provider_home/data/models/service_request.dart';
import '../../features/service_provider/provider_home/view/provider_active_service_page.dart';
import '../../features/service_provider/provider_home/view/service_provider_dashboard_page.dart';
import '../../features/service_provider/provider_profile/view/provider_profile_edit_page.dart';
import '../../features/service_provider/provider_profile/view/provider_profile_view_page.dart';
import '../../features/service_provider/provider_requests/bloc/provider_request_detail_bloc/provider_request_detail_bloc.dart';
import '../../features/service_provider/provider_requests/data/repositories/provider_request_repository.dart';
import '../../features/service_provider/provider_requests/view/provider_request_list_page.dart';
import '../../features/service_provider/refer_earn/view/provider_refer_earn_page.dart';
import '../../features/service_provider/wallet/view/provider_wallet_page.dart';
import '../../features/user/address/model/user_address_model.dart';
import '../../features/user/address/view/user_address_list_page.dart';
import '../../features/user/booking_history/bloc/service_request_detail_bloc.dart';
import '../../features/user/booking_history/view/booking_detail_page.dart';
import '../../features/user/booking_history/view/user_booking_history_page.dart';
import '../../features/user/emergency/bloc/emergency_tracking/emergency_tracking_bloc.dart';
import '../../features/user/emergency/services/emergency_tracking_service.dart';
import '../../features/user/emergency/view/emergency_booking_pre_confirmation_page.dart';
import '../../features/user/emergency/view/emergency_map_page.dart';
import '../../features/user/emergency/view/emergency_tracking_page.dart';
import '../../features/user/extend_booking/bloc/extend_booking_bloc.dart';
import '../../features/user/extend_booking/data/extend_booking_repository.dart';
import '../../features/user/extend_booking/view/extend_booking_page.dart';
import '../../features/user/family/model/family_member_model.dart';
import '../../features/user/family/view/family_add_edit_page.dart';
import '../../features/user/family/view/family_list_page.dart';
import '../../features/user/home/view/user_dashboard_page.dart';
import '../../features/user/payment/view/payment_success_page.dart';
import '../../features/user/payment_list/view/payments_page.dart';
import '../../features/user/profile/view/user_profile_edit_page.dart';
import '../../features/user/profile/view/user_profile_page.dart';
import '../../features/user/refer_earn/view/refer_earn_page.dart';
import '../../features/user/service_booking/model/booking_model.dart';
import '../../features/user/service_booking/model/service_category_model.dart';
import '../../features/user/service_booking/view/service_booking_flow.dart';
import '../../features/user/support_ticket/view/create_support_ticket_page.dart';
import '../../features/user/support_ticket/view/support_ticket_detail_page.dart';
import '../../features/user/support_ticket/view/support_tickets_page.dart';

class AppRoutes {
  AppRoutes._();

  // ─── Route Names ────────────────────────────────────────────────────────────
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String initializer = '/initializer';
  static const String userDashboard = '/user_dashboard';
  static const String userHome = '/user_home';
  static const String providerDashboard = '/provider_dashboard';
  static const String providerProfilePage = '/provider_profile';
  static const String providerEditProfile = '/provider_edit_profile';
  static const String providerEarningsList = '/provider/earnings';
  static const String providerNotification = '/provider_notification';
  static const String providerDocuments = '/provider_documents';
  static const String manageCategories = '/manage_categories';
  static const String providerWallet = '/provider/wallet';
  static const String userProfilePage = '/user_profile_page';
  static const String userNotificationPage = '/user_notification_page';
  static const String referEarn = '/refer_earn';
  static const String userPayments = '/user_payments';
  static const String providerSchedule = '/provider/schedule';
  static const String wallet = '/wallet';
  static const String addMoney = '/add-money';
  static const String needHelp = '/need_help';
  static const String supportTickets = '/support_tickets';
  static const String supportTicketDetail = '/support_ticket_detail';
  static const String createSupportTicket = '/create_support_ticket';
  static const String faqs = '/faqs_page';
  static const String searchService = '/search_service';

  // Address & Family
  static const String userAddressList = '/user_addresses';
  static const String userAddressAddEdit = '/user_addresses/add_edit';
  static const String addressSelectionSheet = '/address_selection_sheet';
  static const String familyList = '/family_members';
  static const String familyAddEdit = '/family_members/add_edit';
  static const String healthRecordsList = '/health_records';

  // User Profile
  static const String userUpdateProfile = '/user/update_profile';

  // Booking
  static const String bookingHistory = '/booking_history';
  static const String serviceRequestDetail = '/service_request_detail';
  static const String extendBooking = '/extend_booking';
  static const String serviceBookingFlow = '/service_booking_flow';

  // Emergency
  static const String emergency = '/emergency';
  static const String emergencyMap = '/emergency/map';
  static const String emergencyConfirm = '/emergency/confirm';
  static const String emergencyTracking = '/emergency/tracking';

  // Provider Active Service (emergency GPS push)
  static const String providerActiveService = '/provider/active-service';
  static const String providerRequestDetail = '/provider/request-detail';
  static const String providerBankDetail = '/provider/bank-detail';
  static const String providerBankDetailAddEdit = '/provider/bank-detail-add-edit';
  static const String webView = '/web_view';
  static const String providerFeedback = '/provider/feedback';
  static const String providerRequestList = '/provider/request-list';
  static const String userAppFeedback = '/user/feedback';
  static const String paymentSuccess = '/payment_success';

  // ─── Route Generator ─────────────────────────────────────────────────────────
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      // Core
      case splash:
        return _page(const SplashPage());
      case login:
        return _page(const LoginPage());
      // case initializer:
      //   return _page(const AppInitializer());

      // Dashboards
      case userDashboard:
        return _page(const UserDashboardPage());
      case userHome:
        return _page(
          MultiBlocProvider(
            providers: [
              BlocProvider<ServiceCategoryBloc>(
                create: (_) =>
                    ServiceCategoryBloc(locator<ServiceCategoryRepository>())
                      ..add(LoadServiceCategories(useCacheFirst: true)),
              ),
              BlocProvider<ServiceRequestBloc>(
                create: (context) => ServiceRequestBloc(locator<ServiceRequestRepository>()),
              ),
              BlocProvider<NotificationBloc>(create: (context) => locator<NotificationBloc>()),
            ],
            child: const Scaffold(backgroundColor: kScaffoldColor, body: UserHomePage()),
          ),
        );
      case providerDashboard:
        return _page(const ProviderDashboardPage());
      case providerNotification:
        return _page(const ProviderNotificationPage());
      case providerDocuments:
        return _page(const ProviderDocumentListPage());
      case manageCategories:
        return _page(const ManageCategoriesPage());
      case providerEarningsList:
        return _page(const ProviderEarningsPage());
      case providerWallet:
        return _page(const ProviderWalletPage());
      case providerProfilePage:
        return _page(
          BlocProvider(
            create: (context) =>
                ProviderProfileBloc(repository: locator<ProviderRepository>())..add(LoadProviderProfile()),
            child: const ProviderProfileViewPage(),
          ),
        );
      case providerEditProfile:
        final args = settings.arguments as Map<String, dynamic>?;
        final autoScrollToBottom = args?['autoScrollToBottom'] == true;
        return _page(
          BlocProvider(
            create: (context) =>
                ProviderProfileBloc(repository: locator<ProviderRepository>())..add(LoadProviderProfile()),
            child: ProviderProfileEditPage(autoScrollToBottom: autoScrollToBottom),
          ),
        );
      case userProfilePage:
        return _page(const UserProfilePage());
      case userNotificationPage:
        return _page(const UserNotificationPage());
      case referEarn:
        if (AppConstants.isProviderApp) {
          return _page(const ProviderReferEarnPage());
        }
        return _page(const ReferEarnPage());
      case userPayments:
        return _page(const UserPaymentsPage());
      case wallet:
        return _page(
          BlocProvider(
            create: (context) => WalletBloc(
              locator<WalletRepository>(),
              locator<LocalStorageService>(),
              locator<SystemSettingsRepository>(),
            )..add(const FetchWalletTransactionsEvent()),
            child: const WalletHistoryPage(),
          ),
        );
      case addMoney:
        return _page(
          BlocProvider(
            create: (context) => WalletBloc(
              locator<WalletRepository>(),
              locator<LocalStorageService>(),
              locator<SystemSettingsRepository>(),
            ),
            child: const AddMoneyPage(),
          ),
        );

      // Address
      case userAddressList:
        return _page(const UserAddressListPage(), settings);
      case userAddressAddEdit:
        final existing = settings.arguments as UserAddressModel?;
        return _page(UserAddressAddEditPage(existing: existing));

      // Family
      case familyList:
        return _page(const FamilyListPage());
      case familyAddEdit:
        final existing = settings.arguments as FamilyMemberModel?;
        return _page(FamilyAddEditPage(existing: existing));

      case healthRecordsList:
        return _page(HealthRecordsListPage());

      // User Profile
      case userUpdateProfile:
        return _page(const UserProfileEditPage());

      // Booking History
      case bookingHistory:
        return _page(
          BlocProvider(
            create: (context) => ServiceRequestBloc(locator<ServiceRequestRepository>()),
            child: const UserBookingHistoryPage(),
          ),
        );
      case serviceRequestDetail:
        final args = settings.arguments;
        int? requestId;
        int? bookingId;
        int? subBlockId;
        if (args is int) {
          requestId = args;
        } else if (args is Map<String, dynamic>) {
          requestId = args['requestId'] as int?;
          bookingId = args['bookingId'] as int?;
          subBlockId = args['subBlockId'] as int?;
        }
        return _page(
          BlocProvider(
            create: (context) =>
                ServiceRequestDetailBloc(locator<ServiceRequestRepository>())
                  ..add(LoadServiceRequestDetail(requestId: requestId, bookingId: bookingId)),
            child: BookingDetailPage(requestId: requestId ?? 0, initialSubBlockId: subBlockId),
          ),
        );
      case serviceBookingFlow:
        final args = settings.arguments as Map<String, dynamic>?;
        return _page(
          ServiceBookingFlow(
            initialMainCategory: args?['initialMainCategory'] as ServiceCategoryModel?,
            initialRequest: args?['initialRequest'] as BookingRequest?,
            initialRoute: args?['initialRoute'] as String?,
            isEmergency: args?['isEmergency'] as bool? ?? false,
          ),
          settings,
        );

      // Service Tracking

      // Extend Booking
      case extendBooking:
        final args = settings.arguments as Map<String, dynamic>;
        kPrint(args);
        return _page(
          BlocProvider(
            create: (_) => ExtendBookingBloc(
              serviceRequestId: args['serviceRequestId'] as int,
              bookingId: args['bookingId'] as int,
              serviceType: args['serviceType'] as String,
              currentEndDate: args['currentEndDate'] as String,
              repo: locator<ExtendBookingRepository>(),
              storage: locator<LocalStorageService>(),
            ),
            child: ExtendBookingPage(
              serviceRequestId: args['serviceRequestId'] as int,
              bookingId: args['bookingId'] as int,
              serviceType: args['serviceType'] as String,
              currentEndDate: args['currentEndDate'] as String,
              serviceName: args['serviceName'] as String,
              providerName: args['providerName'] as String?,
              categoryIconUrl: args['categoryIconUrl'] as String?,
              currentTotalAmount: (args['currentTotalAmount'] as num?)?.toDouble() ?? 0,
            ),
          ),
        );

      // Emergency Flow
      case emergency:
        return _page(const ServiceBookingFlow(isEmergency: true), settings);
      case emergencyConfirm:
        final category = settings.arguments as ServiceCategoryModel;
        return _page(EmergencyBookingPreConfirmationPage(category: category));
      case emergencyMap:
        final args = settings.arguments as Map<String, dynamic>;
        final category = args['category'] as ServiceCategoryModel;
        final instructions = args['instructions'] as String?;
        final familyMemberId = args['familyMemberId'] as int?;
        final familyMemberName = args['familyMemberName'] as String?;
        final latitude = args['latitude']?.toString();
        final longitude = args['longitude']?.toString();
        return _page(
          BlocProvider(
            create: (context) => EmergencyMapBloc(
              locator<ServiceRequestRepository>(),
              locator<UserAddressRepository>(),
            ),
            child: EmergencyMapPage(
              category: category,
              instructions: instructions,
              familyMemberId: familyMemberId,
              familyMemberName: familyMemberName,
              latitude: latitude,
              longitude: longitude,
            ),
          ),
        );
      case emergencyTracking:
        final args = settings.arguments;
        int? requestId;
        if (args is int) {
          requestId = args;
        } else if (args is Map<String, dynamic>) {
          requestId = args['requestId'] as int? ?? args['bookingId'] as int?;
        }
        return _page(
          BlocProvider(
            create: (_) => EmergencyTrackingBloc(EmergencyTrackingService()),
            child: EmergencyTrackingPage(requestId: requestId ?? 0),
          ),
        );
      case providerSchedule:
        return _page(const ProviderAvailabilityPage());
      case providerActiveService:
        final request = settings.arguments as ServiceRequest;
        return _page(
          BlocProvider(
            create: (_) => ProviderTrackingBloc(),
            child: ProviderActiveServicePage(request: request),
          ),
        );
      case providerRequestDetail:
        final args = settings.arguments;
        int? requestId;
        int? bookingId;
        bool isIncomingAlert = false;
        if (args is int) {
          requestId = args;
        } else if (args is Map<String, dynamic>) {
          requestId = args['requestId'] as int?;
          bookingId = args['bookingId'] as int?;
          isIncomingAlert = args['isIncomingAlert'] == true;
        }
        return _page(
          BlocProvider(
            create: (context) =>
                ProviderRequestDetailBloc(repository: locator<ProviderRequestRepository>())
                  ..add(LoadProviderRequestDetail(requestId: requestId, bookingId: bookingId)),
            child: ProviderRequestDetailPage(
              requestId: requestId,
              bookingId: bookingId,
              isIncomingAlert: isIncomingAlert,
            ),
          ),
        );
      case providerBankDetail:
        return _page(const ProviderBankDetailPage());
      case providerBankDetailAddEdit:
        final bankDetail = settings.arguments as BankDetail?;
        return _page(ProviderBankDetailAddEditPage(bankDetail: bankDetail));
      case webView:
        final args = settings.arguments as Map<String, dynamic>;
        return _page(WebViewPage(title: args['title'] as String, url: args['url'] as String));
      case providerFeedback:
        return _page(
          BlocProvider(
            create: (context) => FeedbackBloc(repository: locator<ProviderRepository>())..add(FetchFeedback()),
            child: const ProviderFeedbackPage(),
          ),
        );
      case providerRequestList:
        final initialStatus = settings.arguments as String? ?? 'new_request';
        return _page(ProviderRequestsPage(initialStatus: initialStatus));
      case userAppFeedback:
        return _page(
          BlocProvider(
            create: (context) =>
                UserFeedbackBloc(repository: locator<UserProfileRepository>())..add(FetchUserFeedback()),
            child: const AppFeedbackPage(),
          ),
        );
      case needHelp:
        final contextMessage = settings.arguments as String?;
        return _page(NeedHelpPage(contextMessage: contextMessage));
      case supportTickets:
        return _page(const SupportTicketsPage());
      case supportTicketDetail:
        final ticketId = settings.arguments as String;
        return _page(SupportTicketDetailPage(ticketId: ticketId));
      case createSupportTicket:
        final args = settings.arguments;
        String? requestId;
        String? requestNumber;
        String? serviceName;
        String? category;
        String? subject;
        if (args is String) {
          requestId = args;
        } else if (args is Map<String, dynamic>) {
          requestId = args['requestId'] as String?;
          requestNumber = args['requestNumber'] as String?;
          serviceName = args['serviceName'] as String?;
          category = args['category'] as String?;
          subject = args['subject'] as String?;
        }
        return _page(
          CreateSupportTicketPage(
            serviceRequestId: requestId,
            requestNumber: requestNumber,
            serviceName: serviceName,
            category: category,
            subject: subject,
          ),
        );
      case faqs:
        return _page(const FaqPage());
      case searchService:
        return _page(const SearchServicePage());
      case paymentSuccess:
        final args = settings.arguments as Map<String, dynamic>;
        return _page(
          PaymentSuccessPage(
            serviceRequestId: args['serviceRequestId'] as int,
            unitType: args['unitType'] as String?,
          ),
        );
      default:
        return _page(const SplashPage());
    }
  }

  static MaterialPageRoute<T> _page<T>(Widget child, [RouteSettings? settings]) {
    return MaterialPageRoute<T>(builder: (_) => child, settings: settings);
  }
}
