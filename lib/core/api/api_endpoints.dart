class ApiEndpoints {
  ApiEndpoints._(); // no instance

  // Auth
  static const String sendOtp = "/auth/registration/send-otp";
  static const String verifyOtp = "/auth/registration/verify-otp";
  static const String sendPasswordResetOtp = "/auth/password/send-otp";
  static const String verifyPasswordResetOtp = "/auth/password/verify-otp";
  static const String resetPassword = "/auth/password/reset";
  static const String login = "/users/login";
  static const String logout = "/auth/logout";
  static const String dropdown = "/dropdown";
  static const String serviceSubCategoryList = "/dropdown/service_category";
  static const String saveDeviceToken = "/auth/save-device-token";
  static const String authProfile = "/auth/profile";
  static const String currentUser = "/users/me";
  static const String getDonorProfile = "/auth/donor-profile";
  static const String addUpdateDonorProfile = "/auth/update-donor-profile";
  static const String addUpdateBloodRequest = "/auth/blood-request-addUpdate";
  static const String getBloodRequest = "/auth/blood-requests";

  // Service Provider
  static const String registerProvider = "/register/service-provider";
  static const String registerUser = "/users/register";
  static const String validateReferralCode = "/register/customer/validate-referral-code";
  static const String updateProviderCurrentLocation = "/provider/update-current-location";
  static const String providerDashboardData = "/provider/dashboard";
  static const String updateIsAvailableProvider = "/provider/update-is-available";
  static const String documentList = "/provider/documents";
  static const String addUpdateDocument = "/provider/document-addUpdate";
  static const String deleteDocument = "/provider/document-delete";
  static const String deleteCategory = "/provider/service-delete";
  static const String saveCategory = "/provider/service-save";
  static const String getProviderServiceRequests = "/provider/service-requests";
  static const String getProviderServiceRequestDetails =
      "/provider/service-requests/details"; // ?service_request_id=X
  static const String respondToServiceRequest =
      "/provider/service-requests/respond"; // multipart: service_request_id, action
  static const String startBooking = "/provider/service-requests/start-booking"; // multipart: service_request_id
  static const String sendBookingCompletionOtp =
      "/provider/service-requests/send-otp"; // multipart: booking_id, mobile_number
  static const String completeBooking = "/provider/service-requests/complete"; // multipart: booking_id, otp
  static const String providerCancellationPreview = "/provider/service-requests/cancellation-preview";
  static const String providerCancelSession = "/provider/service-requests/cancel";
  static const String updateProviderProfile = "/provider/update-profile";
  static const String getProviderCategories = "/provider/services"; // GET — provider's active categories
  static const String providerEarnings = "/provider/earnings";
  static const String providerWallet = "/provider/wallet";
  static const String providerWalletTransactions = "/provider/wallet/transactions";
  static const String providerWithdrawals = "/provider/wallet/withdrawals";
  static const String providerWithdrawalRequest = "/provider/wallet/withdrawals/request";
  static String providerWithdrawalCancel(int id) => "/provider/wallet/withdrawals/$id/cancel";
  static const String providerBankDetail = "/provider/bank-detail";
  static const String providerSaveBankDetail = "/provider/save-bank-detail";
  static const String registerAsCustomer = "/provider/register-as-customer";
  static const String getWeeklyAvailability = "/provider/get-weekly-availability";
  static const String updateWeeklyAvailability = "/provider/update-weekly-availability";
  static const String initiateRegistrationFeePayment = "/provider/registration-fee-payment-initiate";

  // User/Patient Side
  static const String updateCustomerProfile = '/customer/update-profile';
  static const String getServiceCategories = '/service-categories';
  static const String catalogServices = '/services';
  // ignore: constant_identifier_names
  static const String get_service_categories_with_price = '/get_service_categories_with_price'; // append /{id}
  static const String getSubCategoriesWithServices = '/get-sub-categories';
  static const String getCustomerAddresses = "/users/me/addresses";
  static const String addUpdateCustomerAddress = "/customer/address-addUpdate";
  static const String deleteCustomerAddress = "/customer/address-delete";

  static const String getCustomerFamilyMembers = "/customer/family-members";
  static const String addUpdateCustomerFamilyMember = "/customer/family-members/save";
  static const String deleteCustomerFamilyMember = "/customer/family-members-delete";

  // Nearby Providers
  static const String findNearbyProviders = "/customer/find-nearby-available-providers";

  // Service Requests / Bookings
  static const String bookings = '/bookings';
  static const String createServiceRequest = "/customer/service-requests-create";
  static const String createEmergencyServiceRequest = "/customer/emergency-service-requests-create";
  static const String cancelServiceRequest = "/customer/service-requests-cancel";
  static const String cancelSubBlock = "/customer/service-requests-cancel-sub-block";
  static const String subBlockDetail = "/customer/sub-block-detail";
  static const String cancellationPreview = "/customer/cancellation-preview";
  static const String cancelUnpaidBooking = "/customer/service-requests-cancel-unpaid-booking";
  static const String getServiceRequests = "/customer/service-requests";
  static const String getServiceRequestDetails = "/customer/service-requests-details";

  // Payments
  static const String applyPromocode = "/auth/payments/apply-promocode";
  static const String initiatePayment = "/auth/payments/initiate";
  static const String regularBookingPaymentInitiate = "/auth/payments/reguler-booking-payment-initiate";
  static const String payPendingInstallments = "/customer/service-requests-pay-pending-installments";
  static const String addMoneyToWalletInitiate = "/auth/add-money-to-wallet-initiate";
  static const String verifyPayment = "/auth/payments/verify";
  static const String failedPayment = "/auth/payments/failed";
  static const String walletTransactions = "/auth/wallet-transections";
  static const String bookingConfirmZeroAmount = "/customer/service-requests-booking-confirm";


  // Rating
  static const String submitRating = "/customer/submit-rating";

  // Extend Booking
  static const String extendPriceCalculate = "/customer/service-extend-price-calculate";
  static const String initiateExtendPrice = "/customer/service-extend-price-initiate";

  static const String healthRecords = "/auth/health-records";
  static const String saveHealthRecord = "/auth/health-records/save";
  static const String deleteHealthRecord = "/auth/health-records/delete";

  // Notifications
  static const String pushNotifications = "/auth/push-notifications";
  static const String pushNotificationsResponse =
      "/auth/push-notifications-response"; // multipart: type, notification_ids[]
  static const String systemSettings = "/get-system-settings";
  static const String userPayments = "/customer/payments";
  static const String invoiceDownload = "/customer/invoice-download";
  static const String getComplaints = "/customer/complaints";
  static const String appFeedback = "/auth/app-feedback";
  static const String saveAppFeedback = "/auth/save-app-feedback";
  static const String faqs = "/faqs";
  static const String getPromoCodes = "/promo-codes";

  // Support Tickets
  static const String supportTickets = "/customer/support-tickets";
  static const String supportTicketsCreate = "/customer/support-tickets-create";
  static const String supportTicketsDetails = "/customer/support-tickets-details";
  static const String supportTicketsUpdateStatus = "/customer/support-tickets-update-status";
  static const String supportTicketsMessages = "/customer/support-tickets-messages";
  static const String supportTicketsSendMessage = "/customer/support-tickets-send-message";
  static const String checkServiceAvailability = "/locations/coverage";
  static const String consents = "/consents";
  static const String getProcedures = "/get-procedures";
}
