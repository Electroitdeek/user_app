import 'dart:async';
import 'dart:io';

import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/constants/app_constants.dart';
import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/features/service_provider/registration_form/view/provider_profile_registration_page.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sms_autofill/sms_autofill.dart';

import '../../../../core/constants/error_constants.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/theme/app_edge_insets.dart';
import '../../../../core/utils/message_service.dart';
import '../../../../data/models/user_profile_model.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../features/user/address/bloc/selected_address_provider.dart';
import '../../../../shared/widgets/buttons/custom_button.dart';
import '../../../user/registeration/view/user_profile_registration_page.dart';
import '../../login/bloc/auth_bloc.dart';
import '../bloc/otp_bloc.dart';

class OtpVerificationPage extends StatelessWidget {
  final String mobileNumber;
  final bool isRegistration;

  const OtpVerificationPage({super.key, required this.mobileNumber, this.isRegistration = false});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OtpBloc(locator<AuthRepository>()),
      child: OtpVerificationUI(mobileNumber: mobileNumber, isRegistration: isRegistration),
    );
  }
}

class OtpVerificationUI extends StatefulWidget {
  final String mobileNumber;
  final bool isRegistration;

  const OtpVerificationUI({super.key, required this.mobileNumber, this.isRegistration = false});

  @override
  State<OtpVerificationUI> createState() => _OtpVerificationUIState();
}

class _OtpVerificationUIState extends State<OtpVerificationUI> with TickerProviderStateMixin {
  String _otpCode = '';
  String? _errorMessage;
  int _resendTimer = 30;
  Timer? _timer;
  bool _canResend = false;
  StreamSubscription<String>? _smsSubscription;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _initSmsAutofill();

    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -7.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -7.0, end: 7.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 7.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));
  }

  static const _smsConsentChannel = MethodChannel('sms_user_consent');

  @override
  void dispose() {
    _timer?.cancel();
    _shakeController.dispose();
    _smsSubscription?.cancel();
    if (Platform.isAndroid) {
      _smsConsentChannel.invokeMethod('cancelSmsUserConsent').catchError((_) {});
      _smsConsentChannel.setMethodCallHandler(null);
    } else {
      SmsAutoFill().unregisterListener();
    }
    super.dispose();
  }

  Future<void> _initSmsAutofill() async {
    if (Platform.isIOS) return;

    _smsConsentChannel.setMethodCallHandler((call) async {
      if (!mounted) return;
      switch (call.method) {
        case 'smsCode':
          final otp = (call.arguments as String? ?? '').trim();
          if (otp.length == 6) {
            setState(() => _otpCode = otp);
            _verifyOtp();
          }
          break;
        case 'error':
          debugPrint('SMS User Consent error: ${call.arguments}');
          _startSmsRetrieverFallback();
          break;
      }
    });

    try {
      await _smsConsentChannel.invokeMethod('startSmsUserConsent');
    } catch (_) {
      _startSmsRetrieverFallback();
    }
  }

  void _startSmsRetrieverFallback() {
    _smsSubscription = SmsAutoFill().code.listen((receivedCode) {
      if (!mounted || receivedCode.isEmpty) return;
      setState(() => _otpCode = receivedCode);
      if (receivedCode.length == 6) _verifyOtp();
    });
    SmsAutoFill().listenForCode(smsCodeRegexPattern: r'\d{6}');
  }

  void _startTimer() {
    setState(() {
      _resendTimer = 30;
      _canResend = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  String _friendlyError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('something went wrong')) return ErrorConstants.defaultError;
    if (msg.contains('expired') || msg.contains('expire')) return 'OTP has expired. Please request a new one.';
    if (msg.contains('attempt') || msg.contains('many') || msg.contains('limit')) {
      return 'Too many attempts. Please request a new OTP.';
    }
    if (msg.contains('invalid') ||
        msg.contains('incorrect') ||
        msg.contains('wrong') ||
        msg.contains('not match')) {
      return 'Incorrect OTP. Please try again.';
    }
    return raw.length < 60 ? raw : 'Verification failed. Please try again.';
  }

  void _showOtpError(String message) {
    setState(() {
      _errorMessage = _friendlyError(message);
      _otpCode = '';
    });
    _shakeController.forward(from: 0.0);
  }

  void _clearError() {
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  void _resendOtp() {
    if (_canResend) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _otpCode = '';
          _errorMessage = null;
        });
      });
      context.read<OtpBloc>().add(ResendOtpEvent(widget.mobileNumber));
      _startTimer();
    }
  }

  void _verifyOtp() {
    if (_otpCode.length == 6) {
      _clearError();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<OtpBloc>().add(VerifyOtpEvent(_otpCode, widget.mobileNumber));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: kWhiteColor,
        appBar: CustomAppBar(
          title: '',
          backgroundColor: kWhiteColor,
          actions: [
            TextButton.icon(
              onPressed: () => AppNavigator.to(AppRoutes.needHelp),
              icon: Icon(Icons.help_outline_rounded, size: 18.sp, color: kPrimaryColor),
              label: Text('Need Help?', style: kTextMedium0(color: kPrimaryColor)),
            ),
          ],
        ),
        body: BlocConsumer<OtpBloc, OtpState>(
          listener: (context, state) async {
            // ... (listener logic remains unchanged)
            if (state is AfterSuccessfulOtpVerification) {
              MessageService.showSuccess("OTP Verified Successfully");

              if (widget.isRegistration || state.isNewUser) {
                if (AppConstants.isProviderApp) {
                  AppNavigator.pushReplacement(
                    ProviderProfileRegistrationPage(mobileNumber: widget.mobileNumber),
                  );
                } else {
                  AppNavigator.pushReplacement(
                    UserProfileRegistrationPage(mobileNumber: widget.mobileNumber),
                  );
                }
                return;
              }

              final storage = locator<LocalStorageService>();
              final String token = state.data['access_token'].toString();
              final Map<String, dynamic> userData = (state.data['user'] as Map<String, dynamic>?) ?? {};
              final List<dynamic> roles = userData['roles'] as List<dynamic>? ?? [];
              final bool hasProviderRole = roles.any((r) => (r as Map)['name'] == 'service_provider');
              final bool hasCustomerRole = roles.any((r) => (r as Map)['name'] == 'customer');
              final bool isProviderApp = AppConstants.isProviderApp;

              // Only save token if it's correct role for the current app
              bool shouldSaveToken = true;
              if (isProviderApp && !hasProviderRole) {
                shouldSaveToken = false;
              } else if (!isProviderApp && !hasCustomerRole) {
                shouldSaveToken = false;
              }

              if (shouldSaveToken) {
                await storage.saveToken(token);
              }
              final int? userId = int.tryParse(userData['id']?.toString() ?? '');

              // ── CASE 1 & 2 : NEW USER ─────────────────────────────────────────
              if (state.isNewUser) {
                if (isProviderApp) {
                  AppNavigator.pushReplacement(
                    ProviderProfileRegistrationPage(mobileNumber: widget.mobileNumber, userId: userId),
                  );
                } else {
                  AppNavigator.pushReplacement(
                    UserProfileRegistrationPage(mobileNumber: widget.mobileNumber, userId: userId),
                  );
                }
                return;
              }

              // ── CASE 3–6 : EXISTING USER ──────────────────────────────────────
              await storage.saveUser(userData);

              final String? fcmToken = await locator<NotificationService>().getFCMToken();

              kPrint("fcmToken${fcmToken ?? "null"}");
              if (fcmToken != null && context.mounted) {
                context.read<AuthBloc>().add(UpdateFcmTokenEvent(fcmToken));
              }

              if (isProviderApp) {
                // ── PROVIDER APP ──────────────────────────────────────────────
                if (hasProviderRole) {
                  // ✅ CASE 5 : Has provider role → provider dashboard
                  if (context.mounted) {
                    final userModel = UserProfileModel.fromJson(userData);
                    context.read<AuthBloc>().add(LoginSuccess(user: userModel, token: token));
                    ProviderScope.containerOf(
                      context,
                    ).read(selectedAddressProvider.notifier).loadForLoggedInUser();
                  }
                  AppNavigator.removeAndGo(AppRoutes.providerDashboard);
                } else if (hasCustomerRole) {
                  // ⚠️ Customer-only account in Provider App → register as provider
                  AppNavigator.pushReplacement(
                    ProviderProfileRegistrationPage(mobileNumber: widget.mobileNumber, userId: userId),
                  );
                } else {
                  // Unknown role
                  if (context.mounted) {
                    MessageService.showError("Unable to determine account type. Please contact support.");
                  }
                  AppNavigator.removeAndGo(AppRoutes.login);
                }
              } else {
                // ── USER APP ──────────────────────────────────────────────────
                if (hasCustomerRole) {
                  // ✅ CASE 3 : Has customer role → user dashboard
                  if (context.mounted) {
                    final userModel = UserProfileModel.fromJson(userData);
                    context.read<AuthBloc>().add(LoginSuccess(user: userModel, token: token));
                    ProviderScope.containerOf(
                      context,
                    ).read(selectedAddressProvider.notifier).loadForLoggedInUser();
                  }
                  AppNavigator.removeAndGo(AppRoutes.userDashboard);
                } else {
                  // CASE 4 : Provider-only account in User App → register as customer
                  AppNavigator.pushReplacement(
                    UserProfileRegistrationPage(mobileNumber: widget.mobileNumber, userId: userId),
                  );
                }
              }
            }

            if (state is OtpResent) {
              MessageService.showSuccess('OTP resent successfully');
            }
            if (state is OtpVerifyError) {
              _showOtpError(state.message);
            }
          },
          builder: (context, state) {
            bool isLoading = state is OtpLoading || state is UpdateFcmTokenLoading;
            return Stack(
              children: [
                // ── Top Background Accents ──
                Positioned(
                  top: -100.h,
                  right: -50.w,
                  child: Container(
                    width: 300.w,
                    height: 300.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [kPrimaryColor.withValues(alpha: 0.05), Colors.transparent],
                      ),
                    ),
                  ),
                ),

                SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 32.h),

                        // Icon
                        Center(
                          child: Container(
                            width: 100.w,
                            height: 100.w,
                            decoration: BoxDecoration(
                              color: kPrimaryColor.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(Icons.chat_bubble_outline_rounded, size: 44.sp, color: kPrimaryColor),
                            ),
                          ),
                        ),

                        SizedBox(height: 48.h),

                        Center(
                          child: Text(
                            'OTP Verification',
                            style: kHeadingLarge(color: kTextPrimaryColor).copyWith(height: 1.15),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        SizedBox(height: 12.h),

                        Center(
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 14.sp),
                              children: [
                                const TextSpan(text: 'Enter the 6-digit code sent to\n'),
                                TextSpan(
                                  text: '+91 ${widget.mobileNumber}',
                                  style: kTextSemiBold(color: kTextPrimaryColor),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 54.h),

                        AnimatedBuilder(
                          animation: _shakeAnimation,
                          builder: (context, child) =>
                              Transform.translate(offset: Offset(_shakeAnimation.value, 0), child: child),
                          child: PinFieldAutoFill(
                            codeLength: 6,
                            autoFocus: true,
                            decoration: BoxLooseDecoration(
                              strokeColorBuilder: FixedColorBuilder(
                                _errorMessage != null ? kErrorColor : const Color(0xFFF0F1F3),
                              ),
                              bgColorBuilder: FixedColorBuilder(
                                _errorMessage != null
                                    ? kErrorColor.withValues(alpha: 0.05)
                                    : kGreyColor1.withValues(alpha: 0.5),
                              ),
                              textStyle: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 20.sp),
                              gapSpace: kSize(12),
                              radius: const Radius.circular(16),
                              strokeWidth: _errorMessage != null ? 1.5 : 1,
                            ),
                            currentCode: _otpCode,
                            onCodeSubmitted: (code) {
                              _otpCode = code;
                              if (code.length == 6) _verifyOtp();
                            },
                            onCodeChanged: (code) {
                              if (code != null && code != _otpCode) {
                                _otpCode = code;
                                _clearError();
                                if (code.length == 6) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _verifyOtp();
                                  });
                                }
                              }
                            },
                          ),
                        ),

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: SizeTransition(sizeFactor: animation, alignment: Alignment(-1.0, -1.0), child: child),
                          ),
                          child: _errorMessage != null
                              ? Padding(
                                  key: const ValueKey('otp_error'),
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.error_outline_rounded, size: 16.sp, color: kErrorColor),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          _errorMessage!,
                                          style: kTextMedium(color: kErrorColor).copyWith(fontSize: 13.sp),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(key: ValueKey('otp_no_error')),
                        ),

                        SizedBox(height: 32.h),

                        CustomButton(
                          title: 'Verify OTP',
                          width: double.infinity,
                          height: 56.h,
                          borderRadius: BorderRadius.circular(28.r),
                          isLoading: isLoading,
                          isEnable: true,
                          iconData: Icons.check_circle_outline_rounded,
                          isIconRight: true,
                          backgroundColor: _otpCode.length == 6 ? kPrimaryColor : kDisableButtonColor,
                          onPressed: _verifyOtp,
                        ),

                        SizedBox(height: 32.h),

                        Center(
                          child: RichText(
                            text: TextSpan(
                              style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 14.sp),
                              children: [
                                const TextSpan(text: "Didn't receive the code? "),
                                TextSpan(
                                  text: _canResend ? 'Resend OTP' : 'Resend in ${_resendTimer}s',
                                  style: kTextSemiBold(color: _canResend ? kPrimaryColor : kTextHintColor),
                                  recognizer: TapGestureRecognizer()..onTap = _canResend ? _resendOtp : null,
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 32.h),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
