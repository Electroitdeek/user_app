import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/assets/app_assets.dart';
import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/message_service.dart';
import 'package:adhisaat_health_care/data/repositories/provider_repository.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/repositories/provider_request_repository.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/view/provider_request_detail_page.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../di/locator.dart';
import '../../features/service_provider/provider_home/widgets/floating_request_card.dart';
import '../../features/service_provider/provider_requests/dialogs/date_conflict_dialog.dart';

// ─── QueuedRequest model ─────────────────────────────────────────────────────

class QueuedRequest {
  final String requestId;
  final String title;
  final String area;
  final bool isEmergency;
  final DateTime receivedAt;
  final int timeoutSeconds;

  final String? serviceName;
  final String? serviceImageUrl;
  final double? distanceKm;
  final double? totalPayout;
  final double? perDayPayout;
  final int? durationDays;
  final String? startTime;
  final String? endTime;
  final String? shiftType;
  final String? customerName;
  final String? patientName;
  final String? patientRelation;
  final int requestStage;
  final bool detailsLoaded;

  const QueuedRequest({
    required this.requestId,
    required this.title,
    required this.area,
    required this.isEmergency,
    required this.receivedAt,
    this.timeoutSeconds = 30,
    this.serviceName,
    this.serviceImageUrl,
    this.distanceKm,
    this.totalPayout,
    this.perDayPayout,
    this.durationDays,
    this.startTime,
    this.endTime,
    this.shiftType,
    this.customerName,
    this.patientName,
    this.patientRelation,
    this.requestStage = 1,
    this.detailsLoaded = false,
  });

  int get numericId => int.tryParse(requestId) ?? 0;

  int get secondsElapsed => DateTime.now().difference(receivedAt).inSeconds;
  int get secondsRemaining => (timeoutSeconds - secondsElapsed).clamp(0, timeoutSeconds);
  bool get isExpired => secondsRemaining <= 0;

  int get priorityScore {
    int score = 0;
    if (isEmergency) score += 1000;
    if (requestStage == 4) score += 500;
    if (requestStage == 3) score += 200;
    if (totalPayout != null) score += (totalPayout! / 1000).toInt();
    if (distanceKm != null && distanceKm! < 3) score += 100;
    score += secondsRemaining ~/ 3; // urgency by time left
    return score;
  }

  QueuedRequest copyWithDetails({
    String? serviceName,
    String? serviceImageUrl,
    double? distanceKm,
    double? totalPayout,
    double? perDayPayout,
    int? durationDays,
    String? startTime,
    String? endTime,
    String? shiftType,
    String? customerName,
    String? patientName,
    String? patientRelation,
    int? requestStage,
    String? area,
  }) =>
      QueuedRequest(
        requestId: requestId,
        title: title,
        area: area ?? this.area,
        isEmergency: isEmergency,
        receivedAt: receivedAt,
        timeoutSeconds: timeoutSeconds,
        serviceName: serviceName ?? this.serviceName,
        serviceImageUrl: serviceImageUrl ?? this.serviceImageUrl,
        distanceKm: distanceKm ?? this.distanceKm,
        totalPayout: totalPayout ?? this.totalPayout,
        perDayPayout: perDayPayout ?? this.perDayPayout,
        durationDays: durationDays ?? this.durationDays,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        shiftType: shiftType ?? this.shiftType,
        customerName: customerName ?? this.customerName,
        patientName: patientName ?? this.patientName,
        patientRelation: patientRelation ?? this.patientRelation,
        requestStage: requestStage ?? this.requestStage,
        detailsLoaded: true,
      );

  factory QueuedRequest.fromFcmData(Map<String, dynamic> data) {
    final isEmergency = data['is_emergency']?.toString() == 'true' ||
        data['type']?.toString() == 'emergency_request';

    // Extract area from body: "New request at 60B, Gopal Pura Mode, Jaipur"
    final body = data['body']?.toString() ?? '';
    final area = body.contains(' at ') ? body.split(' at ').last : body;

    // Service name from title: "SC Injection (Insulin) Requested ✅"
    String title = data['title']?.toString() ?? 'New Request';
    String? serviceName;
    if (title.contains(' Requested')) {
      serviceName = title.split(' Requested').first.replaceAll(' ✅', '').trim();
    }

    return QueuedRequest(
      requestId: data['request_id']?.toString() ?? '',
      title: title,
      area: area,
      isEmergency: isEmergency,
      receivedAt: DateTime.now(),
      timeoutSeconds: 400,
      serviceName: serviceName,
      distanceKm: double.tryParse(data['distance_km']?.toString() ?? ''),
      customerName: data['customer_name']?.toString(),
    );
  }
}

// ─── IncomingRequestManager ───────────────────────────────────────────────────

/// Singleton that manages the floating in-app request card queue.
/// Receives requests from [addRequest], shows floating overlay cards,
/// and handles accept / reject / view actions.
class IncomingRequestManager with WidgetsBindingObserver {
  static final IncomingRequestManager _i = IncomingRequestManager._();
  factory IncomingRequestManager() => _i;
  IncomingRequestManager._() {
    WidgetsBinding.instance.addObserver(this);
  }

  final List<QueuedRequest> _queue = [];
  OverlayEntry? _overlayEntry;
  final AudioPlayer _audio = AudioPlayer();
  bool _audioPlaying = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopAudio();
    } else if (state == AppLifecycleState.resumed && isShowing) {
      _startAudio();
    }
  }

  /// Broadcast stream of the current queue (for queue-count badges etc.).
  final ValueNotifier<List<QueuedRequest>> queueNotifier = ValueNotifier(const []);

  bool get isShowing => _overlayEntry != null;

  // ── Public ────────────────────────────────────────────────────────────────

  void addRequest(Map<String, dynamic> data) {
    final req = QueuedRequest.fromFcmData(data);
    if (req.requestId.isEmpty) return;
    if (req.isExpired) return;
    if (_queue.any((q) => q.requestId == req.requestId)) return; // dedup

    _queue.add(req);
    _sort();
    _notify();

    if (!isShowing) _show(_queue.first);

    _loadDetails(req.requestId);
  }

  // ── Internal actions called by FloatingRequestCard ────────────────────────

  void onAccept(QueuedRequest req) async {
    _dismissOverlay();
    _remove(req.requestId);

    try {
      final result = await locator<ProviderRepository>().respondToRequest(
        requestId: req.numericId,
        accepted: true,
      );

      if (result.success) {
        _showAcceptSuccessDialog(req.numericId, result.message);
      } else if (result.isDateConflict) {
        _showDateConflictDialog(result.message, result.conflictDates);
      } else if (result.hasPartialConflict) {
        _showConflictDialog(result.message, result.invalidIds);
      } else {
        MessageService.showError(result.message.isNotEmpty
            ? result.message
            : 'Request not found or already responded.');
      }
    } catch (e) {
      MessageService.showError(e.toString().replaceAll('Exception: ', ''));
    }

    _showNext();
  }

  void _showAcceptSuccessDialog(int requestId, String message) {
    final ctx = AppNavigator.navigatorKey.currentContext;
    if (ctx == null) return;
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dCtx) => _RespondSuccessDialog(
        message: message,
        onViewBooking: () {
          Navigator.pop(dCtx);
          ProviderRequestDetailPage.showIncomingRequest(requestId);
        },
        onClose: () => Navigator.pop(dCtx),
      ),
    );
  }

  void _showDateConflictDialog(String message, List<String> conflictDates) {
    final ctx = AppNavigator.navigatorKey.currentContext;
    if (ctx == null) return;
    DateConflictDialog.show(ctx, conflictDates: conflictDates, message: message);
  }

  void _showConflictDialog(String message, List<int> invalidIds) {
    final ctx = AppNavigator.navigatorKey.currentContext;
    if (ctx == null) return;
    showDialog(
      context: ctx,
      builder: (dCtx) => _RespondConflictDialog(
        message: message,
        invalidIds: invalidIds,
        onClose: () => Navigator.pop(dCtx),
      ),
    );
  }

  void onReject(QueuedRequest req) {
    _dismissOverlay();
    _remove(req.requestId);
    locator<ProviderRepository>()
        .respondToRequest(requestId: req.numericId, accepted: false)
        .catchError((_) => const RespondResult(success: false, message: ''));
    _showNext();
  }

  void onView(QueuedRequest req) {
    _dismissOverlay();
    _remove(req.requestId);
    ProviderRequestDetailPage.showIncomingRequest(req.numericId);
    _showNext();
  }

  void onExpired(QueuedRequest req) {
    _dismissOverlay();
    _remove(req.requestId);
    _showNext();
  }

  // ── Private ───────────────────────────────────────────────────────────────

  void _show(QueuedRequest request) {
    final overlay = AppNavigator.navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    _startAudio();

    _overlayEntry = OverlayEntry(
      builder: (_) => ValueListenableBuilder<List<QueuedRequest>>(
        valueListenable: queueNotifier,
        builder: (context, queue, _) {
          if (queue.isEmpty) return const SizedBox.shrink();
          return _IncomingRequestScene(queue: queue, manager: this);
        },
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _dismissOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _stopAudio();
  }

  void _remove(String requestId) {
    _queue.removeWhere((q) => q.requestId == requestId);
    _notify();
  }

  void _sort() {
    _queue.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
  }

  void _notify() {
    queueNotifier.value = List.unmodifiable(_queue);
  }

  void _showNext() {
    if (_queue.isEmpty) return;
    Future.delayed(const Duration(milliseconds: 380), () {
      if (_queue.isNotEmpty && !isShowing) _show(_queue.first);
    });
  }

  Future<void> _loadDetails(String requestId) async {
    try {
      final repo = locator<ProviderRequestRepository>();
      final details = await repo.getRequestDetails(requestId: int.tryParse(requestId));
      if (details == null) return;

      final idx = _queue.indexWhere((q) => q.requestId == requestId);
      if (idx == -1) return;

      final blocks = details.subBlocks;
      final perDay = blocks.isNotEmpty ? blocks.first.providerPayout : 0.0;
      final total = blocks.fold<double>(0.0, (s, b) => s + b.providerPayout);

      // For new requests, sub_blocks is empty before acceptance.
      // Compute provider payout as total_amount - company_commission.
      final commission = details.companyCommission ?? 0;
      final providerTotal = total > 0
          ? total
          : (details.totalAmount != null && commission > 0
              ? details.totalAmount! - commission
              : details.totalAmount ?? details.basePrice ?? 0);

      _queue[idx] = _queue[idx].copyWithDetails(
        serviceName: details.serviceCategoryName,
        serviceImageUrl: details.categoryIconUrl,
        distanceKm: details.distanceKm > 0 ? details.distanceKm : null,
        totalPayout: providerTotal > 0 ? providerTotal : (details.totalAmount ?? details.basePrice),
        perDayPayout: perDay,
        durationDays: details.durationDays,
        startTime: details.startTime,
        endTime: details.endTime,
        shiftType: details.shiftType,
        customerName: details.customerName,
        patientName: details.familyMember?.fullName,
        patientRelation: details.familyMember?.relationship,
        requestStage: details.requestStage,
        area: details.customerAddress?.area,
      );

      _sort();
      _notify();
    } catch (e) {
      kPrint('IncomingRequestManager._loadDetails error: $e');
    }
  }

  void _startAudio() {
    if (_audioPlaying) return;
    _audioPlaying = true;
    _audio.setReleaseMode(ReleaseMode.loop);
    _audio.play(AssetSource(AppAssets.emergencySound)).catchError((_) {});
  }

  void _stopAudio() {
    if (!_audioPlaying) return;
    _audioPlaying = false;
    _audio.stop();
  }

}

// ─── Response dialogs ─────────────────────────────────────────────────────────

class _RespondSuccessDialog extends StatelessWidget {
  final String message;
  final VoidCallback onViewBooking;
  final VoidCallback onClose;

  const _RespondSuccessDialog({
    required this.message,
    required this.onViewBooking,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      contentPadding: EdgeInsets.all(24.w),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64.w,
            height: 64.w,
            decoration: BoxDecoration(
              color: kSuccessColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded, color: kSuccessColor, size: 36.sp),
          ),
          SizedBox(height: 16.h),
          Text('Request Accepted!',
              style: kTextBold2(), textAlign: TextAlign.center),
          SizedBox(height: 8.h),
          Text(
            message.isNotEmpty ? message : 'Request accepted successfully.',
            style: kTextNormal(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onViewBooking,
              icon: Icon(Icons.assignment_turned_in_rounded,
                  size: 18.sp, color: Colors.white),
              label: Text('View Booking', style: kTextBold1(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kSuccessColor,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r)),
                elevation: 0,
              ),
            ),
          ),
          SizedBox(height: 10.h),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onClose,
              child: Text('Close', style: kTextMedium(color: Colors.grey.shade600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RespondConflictDialog extends StatelessWidget {
  final String message;
  final List<int> invalidIds;
  final VoidCallback onClose;

  const _RespondConflictDialog({
    required this.message,
    required this.invalidIds,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      contentPadding: EdgeInsets.all(24.w),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64.w,
            height: 64.w,
            decoration: BoxDecoration(
              color: kWarningColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warning_amber_rounded,
                color: kWarningColor, size: 36.sp),
          ),
          SizedBox(height: 16.h),
          Text('Slots Already Taken',
              style: kTextBold2(), textAlign: TextAlign.center),
          SizedBox(height: 8.h),
          Text(
            message.isNotEmpty
                ? message
                : 'Some booking slots were already accepted by another provider.',
            style: kTextNormal(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          if (invalidIds.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: kWarningColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: kWarningColor.withValues(alpha: 0.25)),
              ),
              child: Text(
                '${invalidIds.length} slot${invalidIds.length > 1 ? 's' : ''} unavailable',
                style: kTextSemiBold(color: kWarningColor),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          SizedBox(height: 24.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onClose,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r)),
              ),
              child: Text('OK', style: kTextBold1(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Full-screen overlay scene ────────────────────────────────────────────────
// Renders: blur + dark scrim + stacked peeker cards + active FloatingRequestCard.

class _IncomingRequestScene extends StatefulWidget {
  final List<QueuedRequest> queue;
  final IncomingRequestManager manager;

  const _IncomingRequestScene({required this.queue, required this.manager});

  @override
  State<_IncomingRequestScene> createState() => _IncomingRequestSceneState();
}

class _IncomingRequestSceneState extends State<_IncomingRequestScene>
    with SingleTickerProviderStateMixin {
  late AnimationController _scrimCtrl;
  late Animation<double> _scrimAnim;

  @override
  void initState() {
    super.initState();
    _scrimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scrimAnim = CurvedAnimation(parent: _scrimCtrl, curve: Curves.easeOut);
    _scrimCtrl.forward();
  }

  @override
  void dispose() {
    _scrimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queue = widget.queue;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // ── Blur + dark scrim ─────────────────────────────────────────────
          FadeTransition(
            opacity: _scrimAnim,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withValues(alpha: 0.42)),
            ),
          ),
          // ── Card stack (bottom-anchored) ──────────────────────────────────
          Positioned.fill(
            child: Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                // Peeker card 3 (far back) — just a rounded strip
                if (queue.length > 2)
                  Positioned(
                    bottom: _peekerBottom(context, 2),
                    left: 30.w,
                    right: 30.w,
                    child: _peekerStrip(const Color(0xFFCDD8E6), 20.h),
                  ),
                // Peeker card 2 (middle)
                if (queue.length > 1)
                  Positioned(
                    bottom: _peekerBottom(context, 1),
                    left: 18.w,
                    right: 18.w,
                    child: _peekerStrip(const Color(0xFFDFE8F2), 28.h),
                  ),
                // Active card (front) — Positioned gives tight width constraints
                // so Spacer() in header row works correctly and avoids overflow
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: FloatingRequestCard(
                    request: queue.first,
                    queueCount: (queue.length - 1).clamp(0, 99),
                    manager: widget.manager,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Peeker cards sit slightly above the active card's bottom margin.
  double _peekerBottom(BuildContext context, int layer) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    // Active card bottom margin + action bar height (~64h) + overlap
    final base = safeBottom + 12.h + 64.h;
    return base - (layer * 10.h);
  }

  Widget _peekerStrip(Color color, double height) => Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
      );
}
