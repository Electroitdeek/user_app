class ErrorConstants {
  // General Errors
  static const String defaultError = "Something went wrong. Please try again.";
  static const String networkError = "No internet connection. Please check your network.";
  static const String timeoutError = "Server is taking too long to respond. Try again.";
  static const String unauthorized = "Session expired. Please login again.";

  // Authentication & OTP
  static const String invalidMobile = "Please enter a valid 10-digit mobile number.";
  static const String emptyMobile = "Mobile number cannot be empty.";
  static const String invalidOtp = "The OTP you entered is incorrect. Please try again.";
  static const String otpExpired = "OTP has expired. Please request a new one.";
  static const String resendLimit = "Too many resend attempts. Please try after some time.";

  // Profile & Registration
  static const String requiredField = "This field is required.";
  static const String invalidEmail = "Please enter a valid email address.";
  static const String invalidDob = "Please select a valid date of birth.";
  static const String declarationRequired = "Please accept the declaration to proceed.";

  // API Specific
  static const String userNotFound = "User not found with this mobile number.";
  static const String serverError = "Internal server error. Our team is looking into it.";
}
