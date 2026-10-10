import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/widgets/login_required_dialog.dart';
import 'package:adhisaat_health_care/features/auth/login/bloc/auth_bloc.dart';
import 'package:adhisaat_health_care/features/user/booking_history/view/user_booking_history_page.dart';
import 'package:adhisaat_health_care/features/user/home/view/user_home_page.dart';
import 'package:adhisaat_health_care/features/user/notification/bloc/notification_bloc.dart';
import 'package:adhisaat_health_care/features/user/profile/view/user_menu_page.dart';
import 'package:adhisaat_health_care/features/user/service_booking/bloc/service_category_bloc.dart';
import 'package:adhisaat_health_care/features/user/service_booking/bloc/service_request_bloc.dart';
import 'package:adhisaat_health_care/features/user/service_booking/data/service_category_repository.dart';
import 'package:adhisaat_health_care/features/user/service_booking/data/service_request_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/services/pending_notification_action.dart';
import '../../../../di/locator.dart';
import '../../payment_list/view/payments_page.dart';

class UserDashboardPage extends ConsumerStatefulWidget {
  const UserDashboardPage({super.key});

  @override
  ConsumerState<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends ConsumerState<UserDashboardPage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    // Only Home (0) and Menu (3) are allowed in guest mode
    if (index != 0 && index != 3) {
      if (!_checkAuthAndRedirect()) return;
    }
    setState(() => _selectedIndex = index);
  }

  bool _checkAuthAndRedirect() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthGuest) {
      LoginRequiredDialog.show(context);
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    // Drain any pending notification action stored while the app was killed.
    // e.g. provider accepted → app cold-booted → PendingNotificationAction was
    // stored in the background isolate → we consume it here once the UI is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _drainPendingNotification();
      // _checkDonorPrompt();
    });
  }

  Future<void> _drainPendingNotification() async {
    final pending = await PendingNotificationAction.consume();
    if (pending == null || !mounted) return;

    if (pending.type == 'request_accepted') {
      final bookingId = int.tryParse(pending.requestId);
      if (bookingId != null) {
        debugPrint('📨 [UserDashboard] Draining pending request_accepted → bookingId: $bookingId');
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.serviceRequestDetail,
          (route) => route.settings.name == AppRoutes.userDashboard || route.isFirst,
          arguments: bookingId,
        );
      }
    } else if (pending.type == 'booking_completed') {
      // Cold-boot from a booking_completed notification — open service request detail.
      final serviceReqId = int.tryParse(pending.requestId);
      debugPrint('📨 [UserDashboard] Draining pending booking_completed → serviceReqId: $serviceReqId');
      if (serviceReqId != null) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.serviceRequestDetail,
          (route) => route.settings.name == AppRoutes.userDashboard || route.isFirst,
          arguments: serviceReqId,
        );
      } else {
        // Fallback: no service_request_id — switch to Bookings tab.
        setState(() => _selectedIndex = 1);
      }
    } else if (pending.type == 'booking_expired') {
      // Cold-boot from an expired booking notification —
      // switch to the Bookings tab so the user can see & retry.
      debugPrint('📨 [UserDashboard] Draining pending booking_expired → switching to Bookings tab');
      setState(() => _selectedIndex = 1);
    } else if (pending.type == 'booking_confirmed' ||
        pending.type == 'booking_payment_confirmed' ||
        pending.type == 'provider_waiting_for_payment' ||
        pending.type == 'booking_cancelled') {
      // Cold-boot from a booking status notification — open its detail page.
      final reqId = int.tryParse(pending.requestId);
      if (reqId != null) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.serviceRequestDetail,
          (route) => route.settings.name == AppRoutes.userDashboard || route.isFirst,
          arguments: reqId,
        );
      } else {
        setState(() => _selectedIndex = 1);
      }
    } else if (pending.type == 'booking_start_reminder' || pending.type == 'booking_started') {
      // Cold-boot from a start reminder / service-started — open booking detail + sub-block sheet.
      final reqId = int.tryParse(pending.requestId);
      final subBlockId = int.tryParse(
        pending.payload['booking_sub_block_id'] ?? pending.payload['sub_block_id'] ?? '',
      );
      if (reqId != null) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.serviceRequestDetail,
          (route) => route.settings.name == AppRoutes.userDashboard || route.isFirst,
          arguments: {'requestId': reqId, 'subBlockId': ?subBlockId},
        );
      } else {
        setState(() => _selectedIndex = 1);
      }
    }
  }


  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const UserHomePage();
      case 1:
        return const UserBookingHistoryPage(showBackButton: false);
      case 2:
        return const UserPaymentsPage(showBackButton: false);
      case 3:
        return const UserMenuPage();
      default:
        return const UserHomePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedIndex > 0) {
          setState(() => _selectedIndex = 0);
        }
      },
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ServiceCategoryBloc>(
            create: (_) =>
                ServiceCategoryBloc(locator<ServiceCategoryRepository>())
                  ..add(LoadServiceCategories(useCacheFirst: true, isEmergency: false)),
          ),
          BlocProvider<ServiceRequestBloc>(
            create: (context) {
              final bloc = ServiceRequestBloc(locator<ServiceRequestRepository>());
              final authState = context.read<AuthBloc>().state;
              if (authState is AuthAuthenticated) {
                bloc.add(const LoadServiceRequests());
              }
              return bloc;
            },
          ),
          BlocProvider<NotificationBloc>(
            create: (context) {
              final bloc = locator<NotificationBloc>();
              final authState = context.read<AuthBloc>().state;
              if (authState is AuthAuthenticated) {
                bloc.add(FetchNotificationsEvent());
              }
              return bloc;
            },
          ),
        ],
        child: Scaffold(
          backgroundColor: kScaffoldColor,
          body: Column(
            children: [
              Expanded(child: _buildBody()),
              _buildBottomNav(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // ── Nav bar background ───────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: kWhiteColor,
            border: Border(top: BorderSide(color: const Color(0xFFE8EAF0), width: 1)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -3)),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64.h,
              child: Row(
                children: [
                  _NavTab(icon: Icons.home_rounded, label: 'Home', selected: _selectedIndex == 0, onTap: () => _onItemTapped(0)),
                  _NavTab(icon: Icons.calendar_month_rounded, label: 'Bookings', selected: _selectedIndex == 1, onTap: () => _onItemTapped(1)),
                  // Center spacer for floating button
                  SizedBox(width: 72.w),
                  _NavTab(icon: Icons.credit_card_rounded, label: 'Payments', selected: _selectedIndex == 2, onTap: () => _onItemTapped(2)),
                  _NavTab(icon: Icons.menu_rounded, label: 'Menu', selected: _selectedIndex == 3, onTap: () => _onItemTapped(3)),
                ],
              ),
            ),
          ),
        ),

        // ── Floating Book Now button ─────────────────────────────
        Positioned(
          top: -16.h,
          child: GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onTap: () {
              HapticFeedback.lightImpact();
              if (!_checkAuthAndRedirect()) return;
              Navigator.of(context).pushNamed(AppRoutes.serviceBookingFlow);
            },
            child: ClipOval(
            child: Container(
              width: 74.w,
              height: 74.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kPrimaryColor, kSecondaryColor],
                ),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF123B61).withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 6)),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 26.w,
                      height: 26.w,
                      decoration: BoxDecoration(
                        color: kWhiteColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add_rounded, color: kWhiteColor, size: 18.sp),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      'Book Now',
                      maxLines: 1,
                      style: TextStyle(color: kWhiteColor, fontSize: 9.sp, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavTab({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? kPrimaryColor : const Color(0xFF9CA3AF), size: 22.sp),
            SizedBox(height: 3.h),
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5.sp,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? kPrimaryColor : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
