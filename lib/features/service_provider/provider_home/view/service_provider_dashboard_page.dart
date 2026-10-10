import 'dart:async';

import 'package:adhisaat_health_care/features/service_provider/earnings/view/provider_earning_list_page.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_home/view/service_provider_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/provider_blocked_dialog.dart';
import '../../../../data/repositories/provider_repository.dart';
import '../../../../di/locator.dart';
import '../../../auth/login/bloc/auth_bloc.dart';
import '../../provider_menu/view/provider_menu_page.dart';
import '../../provider_requests/dialogs/date_conflict_dialog.dart';
import '../../provider_requests/view/provider_request_list_page.dart';
import '../bloc/provider_dashboard_bloc/provider_dashboard_bloc.dart';
import '../bloc/provider_dashboard_bloc/provider_dashboard_event.dart';
import '../bloc/provider_dashboard_bloc/provider_dashboard_state.dart';
import '../bloc/sos_bloc/sos_bloc.dart';
import '../bloc/user_booking_bloc/user_booking_bloc.dart';

class ProviderDashboardPage extends StatefulWidget {
  const ProviderDashboardPage({super.key});

  @override
  State<ProviderDashboardPage> createState() => _ServiceProviderDashboardPageState();
}

class _ServiceProviderDashboardPageState extends State<ProviderDashboardPage> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  // True whenever a new request arrives and the provider hasn't
  // opened the Requests tab yet. Cleared as soon as they tap it.
  bool _hasNewRequest = false;

  late final ProviderDashboardBloc _dashboardBloc;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dashboardBloc = ProviderDashboardBloc(locator<ProviderRepository>())..add(LoadProviderDashboard(forceRefresh: true));

    NotificationService().registerBlocCallback(_handleNotification);

    // ── PERIODIC REFRESH (10 minutes) ─────────────────────────────
    // Ensures the provider's location and token stay "fresh" in the
    // backend so the dispatch algorithm continues to include them.
    _refreshTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      if (mounted) {
        _dashboardBloc.add(LoadProviderDashboard());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App returned from background → ensure we have fresh data
      // and let the backend know we are active.
      // We use RefreshDashboardEvent here instead of LoadProviderDashboard
      // to avoid triggering automatic location permission requests on every resume,
      // which can lead to an infinite dialog loop.
      _dashboardBloc.add(RefreshDashboardEvent());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService().unregisterBlocCallback(_handleNotification);
    _refreshTimer?.cancel();
    _dashboardBloc.close();
    super.dispose();
  }

  void _handleNotification(String type, Map<String, dynamic> data) {
    if (type == 'service_request' || type == 'emergency_request') {
      // Dispatch event to bloc to show overlay and refresh data
      _dashboardBloc.add(NewRequestReceivedEvent(requestData: data));
      _dashboardBloc.add(RefreshDashboardEvent());
    } else if (type == 'booking_cancelled') {
      _dashboardBloc.add(RefreshDashboardEvent());
    } else if (type == 'fcm_token_refresh') {
      final token = data['token']?.toString();
      if (token != null) {
        context.read<AuthBloc>().add(UpdateFcmTokenEvent(token));
      }
    }
  }

  final List<Widget> _pages = [
    const ProviderHomePageUI(),
    const ProviderRequestsPage(showBackButton: false),
    const ProviderEarningsPage(showBackButton: false),
    const ProviderMenuPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _dashboardBloc),
        BlocProvider(create: (_) => SOSBloc()),
        BlocProvider(create: (_) => UserBookingBloc()),
      ],
      child: BlocListener<ProviderDashboardBloc, ProviderDashboardState>(
        listener: (context, state) {
          if (state is ProviderDashboardLoaded) {
            final isUserBlocked = state.profile.isBlocked;
            final isProviderBlocked = state.profile.serviceProviderProfile?.isBlocked ?? false;

            if (isUserBlocked || isProviderBlocked) {
              final profile = state.profile.serviceProviderProfile;
              final reason = profile?.blockedReason ?? 'Your account has been temporarily blocked.';

              String? formattedDate;
              if (profile?.blockedTillDate != null) {
                try {
                  final date = DateTime.parse(profile!.blockedTillDate!);
                  formattedDate = DateFormat('dd-MMM-yyyy').format(date);
                } catch (e) {
                  formattedDate = profile!.blockedTillDate;
                }
              }

              final tillDate = formattedDate != null ? '\n\nBlocked till: $formattedDate.' : '';

              ProviderBlockedDialog.show(
                context,
                title: 'Account Blocked ❌',
                message: '$reason$tillDate',
                onOkPressed: () {
                  Navigator.pop(context);
                  context.read<AuthBloc>().add(LogoutRequested());
                },
              );
            }
          }
          // New request arrived → light up the Requests badge
          // (IncomingRequestManager handles the floating card)
          if (state is NewRequestReceived) {
            setState(() => _hasNewRequest = true);
          }
          // Request was accepted/rejected → clear badge
          if (state is RequestAccepted) {
            setState(() => _hasNewRequest = false);
          }
          if (state is AcceptDateConflict) {
            DateConflictDialog.show(context, conflictDates: state.conflictDates, message: state.message);
          }
        },
        child: PopScope(
          canPop: _selectedIndex == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _selectedIndex > 0) {
              setState(() => _selectedIndex = 0);
            }
          },
          child: Scaffold(
            body: IndexedStack(index: _selectedIndex, children: _pages),
            bottomNavigationBar: _buildBottomNav(),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        border: Border(top: BorderSide(color: kGreyColor2, width: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 65.h,
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'Home'),
              _buildNavItem(1, Icons.assignment_rounded, 'Requests', badge: _hasNewRequest),
              _buildNavItem(2, Icons.account_balance_wallet_rounded, 'Earnings'),
              _buildNavItem(3, Icons.menu_rounded, 'Menu'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {bool badge = false}) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
            // Clear the badge as soon as provider opens the Requests tab
            if (index == 1) _hasNewRequest = false;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: isSelected ? kPrimaryColor : kTextHintColor, size: 22.sp),
                if (badge) Positioned(top: -2.h, right: -2.w, child: _PulsingBadge()),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: (isSelected ? kTextBold() : kTextMedium()).copyWith(fontSize: 10.sp, color: isSelected ? kPrimaryColor : kTextSecondaryColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Animated pulsing red dot
// ─────────────────────────────────────────────────────────────────
class _PulsingBadge extends StatefulWidget {
  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.3).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _opacityAnim = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse ring
          Transform.scale(
            scale: _scaleAnim.value,
            child: Opacity(
              opacity: (1 - _opacityAnim.value) * 0.5,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red.shade400),
              ),
            ),
          ),
          // Solid inner dot
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.shade500,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
