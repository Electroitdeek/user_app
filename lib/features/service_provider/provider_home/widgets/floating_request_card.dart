import 'dart:async';

import 'package:adhisaat_health_care/core/services/incoming_request_manager.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/number_utils.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

/// InDrive/Uber-style floating bottom card for incoming service requests.
/// Slides up from bottom. Works above any screen.
class FloatingRequestCard extends StatefulWidget {
  final QueuedRequest request;
  final int queueCount;
  final IncomingRequestManager manager;

  const FloatingRequestCard({
    super.key,
    required this.request,
    required this.queueCount,
    required this.manager,
  });

  @override
  State<FloatingRequestCard> createState() => _FloatingRequestCardState();
}

class _FloatingRequestCardState extends State<FloatingRequestCard>
    with TickerProviderStateMixin {
  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  late AnimationController _countCtrl;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;
  late AnimationController _dotCtrl;
  late Animation<double> _dotAnim;

  // ── State ──────────────────────────────────────────────────────────────────
  int _secsLeft = 30;
  Timer? _ticker;
  bool _dismissing = false;

  // ── Constants ──────────────────────────────────────────────────────────────
  static const _cardBg = Colors.white;
  static const _navy = Color(0xFF123B61);

  @override
  void initState() {
    super.initState();
    _secsLeft = widget.request.secondsRemaining.clamp(1, 99);

    // Slide up from bottom with elastic feel
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 1.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _slideCtrl.forward();

    // Countdown progress (1.0 → 0.0 over timeout seconds)
    _countCtrl = AnimationController(
      vsync: this,
      duration: Duration(seconds: _secsLeft),
      value: 1.0,
    )..reverse();

    // Pulse — activated in last 5 seconds
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.025)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Breathing glow for Accept button
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.45, end: 0.85)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    // Pulsing live dot in badge
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _dotAnim = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _dotCtrl, curve: Curves.easeInOut));

    _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void _onTick(Timer t) {
    if (!mounted) {
      t.cancel();
      return;
    }
    setState(() => _secsLeft = (_secsLeft - 1).clamp(0, 99));

    if (_secsLeft == 5) {
      _pulseCtrl.repeat(reverse: true);
    }
    if (_secsLeft <= 0) {
      t.cancel();
      _expire();
    }
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _countCtrl.dispose();
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    _dotCtrl.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Color get _timerColor {
    if (_secsLeft > 15) return const Color(0xFF22C55E);
    if (_secsLeft > 7) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String get _timerLabel {
    final m = _secsLeft ~/ 60;
    final s = _secsLeft % 60;
    return m > 0 ? '$m:${s.toString().padLeft(2, '0')}' : '$_secsLeft';
  }

  String _fmtTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final p = raw.split(':');
      return DateFormat('h:mm a').format(DateTime(0, 1, 1, int.parse(p[0]), int.parse(p[1])));
    } catch (_) {
      return raw;
    }
  }

  String _capitalize(String? s) {
    if (s == null || s.isEmpty) return '';
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  /// Shift-type chip label. `24_hours`/`full_day` → "Full Day".
  String _shiftLabel(String? s) {
    if (s == null || s.isEmpty) return '';
    final t = s.toLowerCase();
    if (t == '24_hours' || t == '24_hour' || t == 'full_day' || t == 'fullday') {
      return 'Full Day';
    }
    return '${_capitalize(s)} Shift';
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _accept() async {
    if (_dismissing) return;
    _dismissing = true;
    HapticFeedback.heavyImpact();
    await _slideOut();
    widget.manager.onView(widget.request);
  }

  Future<void> _reject() async {
    if (_dismissing) return;
    _dismissing = true;
    HapticFeedback.mediumImpact();
    await _slideOut();
    widget.manager.onReject(widget.request);
  }

  Future<void> _view() async {
    if (_dismissing) return;
    _dismissing = true;
    await _slideOut();
    widget.manager.onView(widget.request);
  }

  void _expire() {
    if (_dismissing) return;
    _dismissing = true;
    _slideOut().then((_) => widget.manager.onExpired(widget.request));
  }

  Future<void> _slideOut() async {
    _ticker?.cancel();
    _pulseCtrl.stop();
    _glowCtrl.stop();
    _dotCtrl.stop();
    _countCtrl.stop();
    await _slideCtrl.reverse();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: ScaleTransition(
        scale: _pulseAnim,
        child: _buildCard(context, widget.request),
      ),
    );
  }

  Widget _buildCard(BuildContext context, QueuedRequest r) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: EdgeInsets.fromLTRB(12.w, 0, 12.w, (bottomPad + 10).h),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(26.r),
        boxShadow: [
          // Primary deep shadow — creates floating depth
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 48,
            offset: const Offset(0, -10),
            spreadRadius: 0,
          ),
          // Secondary ambient shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
          // Brand color glow for non-emergency
          if (!r.isEmergency)
            BoxShadow(
              color: kPrimaryColor.withValues(alpha: 0.15),
              blurRadius: 32,
              spreadRadius: 0,
              offset: const Offset(0, -4),
            ),
          // Red pulse glow for emergency
          if (r.isEmergency)
            BoxShadow(
              color: kErrorColor.withValues(alpha: 0.3),
              blurRadius: 28,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dragHandle(),
          _progressBar(),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 4.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerRow(r),
                SizedBox(height: 14.h),
                r.detailsLoaded ? _serviceRow(r) : _skeleton(height: 38.h),
                SizedBox(height: 12.h),
                r.detailsLoaded ? _earningsRow(r) : _skeleton(height: 52.h),
                SizedBox(height: 12.h),
                _locationRow(r),
                SizedBox(height: 8.h),
                _customerRow(r),
                SizedBox(height: 14.h),
              ],
            ),
          ),
          if (widget.queueCount > 0) _queueBadge(),
          _actionBar(),
        ],
      ),
    );
  }

  // ── Drag handle ───────────────────────────────────────────────────────────

  Widget _dragHandle() => Padding(
        padding: EdgeInsets.fromLTRB(12.w, 10.h, 8.w, 4.h),
        child: Row(
          children: [
            const Spacer(),
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _expire,
                  child: Container(
                    width: 28.w,
                    height: 28.w,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded, size: 16.sp, color: Colors.grey.shade600),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  // ── Progress bar ─────────────────────────────────────────────────────────

  Widget _progressBar() => ClipRRect(
        borderRadius: BorderRadius.circular(2.r),
        child: AnimatedBuilder(
          animation: _countCtrl,
          builder: (_, _) => LinearProgressIndicator(
            value: _countCtrl.value,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation(_timerColor),
            minHeight: 4.h,
          ),
        ),
      );

  // ── Header row ────────────────────────────────────────────────────────────

  Widget _headerRow(QueuedRequest r) {
    return Row(
      children: [
        // Compact badge — secondary visual weight
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: r.isEmergency ? kErrorColor : _navy,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _dotAnim,
                builder: (_, _) => Container(
                  width: 6.w,
                  height: 6.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF4ADE80).withValues(alpha: _dotAnim.value),
                  ),
                ),
              ),
              SizedBox(width: 5.w),
              Text(
                r.isEmergency ? '🚨 EMERGENCY' : 'NEW REQUEST',
                style: kTextNormal0(color: Colors.white)
                    .copyWith(fontSize: 9.sp, letterSpacing: 0.6),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (r.detailsLoaded && r.requestStage > 1 && (r.durationDays ?? 1) > 1) ...[
          Flexible(
            child: Container(
              margin: EdgeInsets.only(right: 8.w),
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: _stageColor(r.requestStage).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                _stageLabel(r.requestStage),
                style: kTextBold0(color: _stageColor(r.requestStage))
                    .copyWith(fontSize: 10.sp),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        // Countdown timer chip
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
          decoration: BoxDecoration(
            color: _timerColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: _timerColor.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_rounded, size: 12.sp, color: _timerColor),
              SizedBox(width: 4.w),
              Text(
                _timerLabel,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: _timerColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Service row ───────────────────────────────────────────────────────────

  Widget _serviceRow(QueuedRequest r) {
    final st = r.shiftType?.toLowerCase();
    final shiftIcon = st == 'night'
        ? Icons.nightlight_outlined
        : (st == '24_hours' || st == 'full_day')
            ? Icons.brightness_4_outlined
            : Icons.wb_sunny_outlined;
    final startFmt = _fmtTime(r.startTime);
    final endFmt = _fmtTime(r.endTime);
    final timingText = r.isEmergency
        ? startFmt
        : (startFmt.isNotEmpty && endFmt.isNotEmpty ? '$startFmt – $endFmt' : '');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Service icon
        Container(
          width: 44.w,
          height: 44.w,
          decoration: BoxDecoration(
            color: kPrimaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: kPrimaryColor.withValues(alpha: 0.15)),
          ),
          child: r.serviceImageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: AppCachedImage(imageUrl: r.serviceImageUrl),
                )
              : Icon(Icons.medical_services_outlined,
                  color: kPrimaryColor, size: 22.sp),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.serviceName ?? r.title,
                style: kTextBold2().copyWith(fontSize: 18.sp),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4.h),
              Wrap(
                spacing: 6.w,
                runSpacing: 4.h,
                children: [
                  if (r.durationDays != null && !r.isEmergency)
                    _chip(Icons.event_repeat_rounded, '${r.durationDays} Days',
                        kPrimaryColor),
                  if (r.shiftType != null && !r.isEmergency)
                    _chip(shiftIcon, _shiftLabel(r.shiftType), kSecondaryColor),
                  if (timingText.isNotEmpty)
                    _chip(Icons.schedule, timingText, Colors.grey.shade600),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Earnings row ──────────────────────────────────────────────────────────

  Widget _earningsRow(QueuedRequest r) {
    final total = r.totalPayout ?? 0;
    final perDay = r.perDayPayout ?? 0;
    final showPerDay = (r.durationDays ?? 1) > 1 && perDay > 0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0FDF4), Color(0xFFECFCF4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          // Total payout (hero)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    NumberUtils.formatCurrency(total, decimalDigits: 0),
                    style: kTextBold3(color: const Color(0xFF15803D))
                        .copyWith(fontSize: 30.sp),
                    maxLines: 1,
                  ),
                ),
                Text(
                  'You will earn',
                  style: kTextMedium(color: const Color(0xFF16A34A))
                      .copyWith(fontSize: 11.sp),
                ),
              ],
            ),
          ),
          if (showPerDay) ...[
            // Divider
            Container(
              width: 1,
              height: 36.h,
              color: const Color(0xFFBBF7D0),
            ),
            // Per day
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      NumberUtils.formatCurrency(perDay, decimalDigits: 0),
                      style: kTextBold2(color: const Color(0xFF166534)),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                  ),
                  Text(
                    'per day',
                    style: kTextNormal0(color: const Color(0xFF16A34A))
                        .copyWith(fontSize: 10.sp),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
          // Wallet icon
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              color: const Color(0xFF16A34A),
              size: 18.sp,
            ),
          ),
        ],
      ),
    );
  }

  // ── Location row ──────────────────────────────────────────────────────────

  Widget _locationRow(QueuedRequest r) {
    final hasDistance = r.distanceKm != null && r.distanceKm! > 0;
    final distanceText = hasDistance
        ? '  •  ${r.distanceKm!.toStringAsFixed(1)} km away'
        : '';
    return Row(
      children: [
        Icon(Icons.location_on_rounded, color: kErrorColor, size: 16.sp),
        SizedBox(width: 5.w),
        Expanded(
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: kTextMedium(color: Colors.grey.shade700).copyWith(fontSize: 13.sp),
              children: [
                TextSpan(
                  text: r.area.isNotEmpty ? r.area : 'Location loading...',
                ),
                if (hasDistance)
                  TextSpan(
                    text: distanceText,
                    style: kTextSemiBold0(color: kPrimaryColor).copyWith(fontSize: 12.sp),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Customer row ──────────────────────────────────────────────────────────

  Widget _customerRow(QueuedRequest r) {
    final hasCustomer = (r.customerName ?? '').isNotEmpty;
    final hasPatient = (r.patientName ?? '').isNotEmpty;
    if (!hasCustomer && !hasPatient) return const SizedBox.shrink();

    return Row(
      children: [
        Icon(Icons.person_rounded, color: kSecondaryColor, size: 16.sp),
        SizedBox(width: 6.w),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: kTextMedium(color: Colors.grey.shade700)
                  .copyWith(fontSize: 12.sp),
              children: [
                if (hasPatient)
                  TextSpan(
                    text: r.patientName!,
                    style: kTextSemiBold(color: Colors.grey.shade800)
                        .copyWith(fontSize: 12.sp),
                  )
                else if (hasCustomer)
                  TextSpan(
                    text: r.customerName,
                    style: kTextSemiBold(color: Colors.grey.shade800)
                        .copyWith(fontSize: 12.sp),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ── Queue badge ───────────────────────────────────────────────────────────

  Widget _queueBadge() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.symmetric(vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.queue_rounded, size: 13.sp, color: Colors.grey.shade500),
          SizedBox(width: 6.w),
          Text(
            '+${widget.queueCount} more request${widget.queueCount > 1 ? 's' : ''} waiting',
            style: kTextMedium(color: Colors.grey.shade600)
                .copyWith(fontSize: 11.sp),
          ),
        ],
      ),
    );
  }

  // ── Action bar ────────────────────────────────────────────────────────────

  Widget _actionBar() {
    final stage = widget.request.requestStage;
    final isStage1 = stage == 1;
    final viewLabel = isStage1 ? 'Details' : _stageActionLabel(stage);

    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26.r)),
        border: Border(top: BorderSide(color: Colors.grey.shade100, width: 1)),
      ),
      child: Row(
        children: [
          // Decline — quiet, non-destructive
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 50.h,
              child: OutlinedButton(
                onPressed: _reject,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade300,
                  side: BorderSide(color: Colors.red.shade200, width: 1),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r)),
                ),
                child: Text('Decline',
                    style: kTextNormal0(color: Colors.red.shade300)
                        .copyWith(fontSize: 12.sp)),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          // Details — neutral secondary
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 50.h,
              child: OutlinedButton(
                onPressed: _view,
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimaryColor,
                  side: BorderSide(
                      color: kPrimaryColor.withValues(alpha: 0.4), width: 1.5),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isStage1 ? Icons.info_outline_rounded : Icons.edit_calendar_rounded,
                      size: 14.sp,
                      color: kPrimaryColor,
                    ),
                    SizedBox(width: 4.w),
                    Flexible(
                      child: Text(viewLabel,
                          style: kTextMedium(color: kPrimaryColor)
                              .copyWith(fontSize: 12.sp),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          // Accept — dominant hero CTA with breathing glow
          Expanded(
            flex: 5,
            child: AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, child) => Container(
                height: 50.h,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14.r),
                  boxShadow: [
                    BoxShadow(
                      color: kSuccessColor.withValues(alpha: _glowAnim.value),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: child,
              ),
              child: ElevatedButton(
                onPressed: _accept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kSuccessColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r)),
                  elevation: 0,
                  minimumSize: Size.zero,
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 18.sp, color: Colors.white),
                    SizedBox(width: 6.w),
                    Text(
                      'Accept',
                      style: kTextSemiBold1(color: Colors.white)
                          .copyWith(fontSize: 15.sp),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Skeleton loader ───────────────────────────────────────────────────────

  Widget _skeleton({required double height}) => Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: const _ShimmerEffect(),
      );

  // ── Small helpers ─────────────────────────────────────────────────────────

  Widget _chip(IconData icon, String label, Color color) => Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10.sp, color: color),
            SizedBox(width: 4.w),
            Text(label,
                style:
                    kTextNormal0(color: color).copyWith(fontSize: 10.sp)),
          ],
        ),
      );

  Color _stageColor(int stage) {
    switch (stage) {
      case 2:
        return kSecondaryColor;
      case 3:
        return const Color(0xFF7C3AED);
      case 4:
        return kAccentColor;
      default:
        return kSuccessColor;
    }
  }

  String _stageLabel(int stage) {
    switch (stage) {
      case 2:
        return 'Split';
      case 3:
        return 'Flex Dates';
      case 4:
        return 'Last Slots';
      default:
        return 'Full';
    }
  }

  String _stageActionLabel(int stage) {
    switch (stage) {
      case 2:
        return 'Pick Half';
      case 3:
        return 'Select Dates';
      case 4:
        return 'Last Slots';
      default:
        return 'Details';
    }
  }
}

// ─── Shimmer effect for skeleton loader ──────────────────────────────────────

class _ShimmerEffect extends StatefulWidget {
  const _ShimmerEffect();

  @override
  State<_ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<_ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(begin: -2, end: 2)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value + 1, 0),
            colors: [
              Colors.grey.shade100,
              Colors.grey.shade200,
              Colors.grey.shade100,
            ],
          ),
        ),
      ),
    );
  }
}
