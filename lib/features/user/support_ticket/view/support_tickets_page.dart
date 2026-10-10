import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/shared/widgets/common/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../di/locator.dart';
import '../../../../shared/widgets/common/app_bar_custom.dart';
import '../data/support_ticket_repository.dart';
import '../model/support_ticket_model.dart';

class SupportTicketsPage extends StatefulWidget {
  const SupportTicketsPage({super.key});

  @override
  State<SupportTicketsPage> createState() => _SupportTicketsPageState();
}

class _SupportTicketsPageState extends State<SupportTicketsPage> {
  late Future<SupportTicketsResponse> _ticketsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _ticketsFuture = locator<SupportTicketRepository>().getSupportTickets();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kScaffoldColor,
      appBar: CustomAppBar(
        title: 'My Tickets',

        centerTitle: true,
        backgroundColor: kScaffoldColor,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: kPrimaryColor, size: 22.sp),
            onPressed: _refresh,
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: FutureBuilder<SupportTicketsResponse>(
        future: _ticketsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmer();
          }
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          final tickets = snapshot.data?.data ?? [];

          if (tickets.isEmpty) {
            return _buildEmptyState();
          }

          return CustomRefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(12.w, 16.h, 12.w, 100.h),
              itemCount: tickets.length,
              itemBuilder: (context, index) => _TicketCard(ticket: tickets[index]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await AppNavigator.to(AppRoutes.createSupportTicket);
          if (result == true && mounted) _refresh();
        },
        backgroundColor: kPrimaryColor,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, color: kWhiteColor),
        label: Text(
          'New Ticket',
          style: kTextBold(color: kWhiteColor).copyWith(fontSize: 14.sp),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h), itemCount: 6, itemBuilder: (_, _) => _ShimmerCard());
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.06), shape: BoxShape.circle),
            child: Icon(Icons.confirmation_number_outlined, size: 48.sp, color: kPrimaryColor.withValues(alpha: 0.5)),
          ),
          SizedBox(height: 20.h),
          Text('No Tickets Yet', style: kTextBold().copyWith(fontSize: 18.sp)),
          SizedBox(height: 8.h),
          Text(
            "You haven't raised any support tickets yet.\nTap below to get help.",
            style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 13.sp),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 28.h),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await AppNavigator.to(AppRoutes.createSupportTicket);
              if (result == true && mounted) _refresh();
            },
            icon: const Icon(Icons.add_rounded, color: kWhiteColor),
            label: Text('Raise a Ticket', style: kTextBold(color: kWhiteColor)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(color: kErrorColor.withValues(alpha: 0.08), shape: BoxShape.circle),
              child: Icon(Icons.error_outline_rounded, size: 36.sp, color: kErrorColor),
            ),
            SizedBox(height: 16.h),
            Text('Failed to Load Tickets', style: kTextBold().copyWith(fontSize: 17.sp)),
            SizedBox(height: 8.h),
            Text(
              error.replaceAll('Exception: ', ''),
              style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
              textAlign: TextAlign.center,
              maxLines: 3,
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded, color: kWhiteColor),
              label: Text('Try Again', style: kTextBold(color: kWhiteColor)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ticket Card ─────────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  final SupportTicketModel ticket;

  const _TicketCard({required this.ticket});

  IconData get _categoryIcon {
    switch (ticket.category.toLowerCase()) {
      case 'payment':
        return Icons.payment_rounded;
      case 'service':
        return Icons.medical_services_outlined;
      case 'billing':
        return Icons.receipt_long_rounded;
      case 'technical':
        return Icons.build_outlined;
      case 'refund':
        return Icons.currency_rupee_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = ticket.statusColor;

    return GestureDetector(
      onTap: () => AppNavigator.to(AppRoutes.supportTicketDetail, arguments: ticket.id.toString()),
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: kGreyColor1, width: 1),
          boxShadow: [BoxShadow(color: kBlackColor.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top colored accent strip ──────────────────────────────
            // Container(
            //   height: 4.h,
            //   decoration: BoxDecoration(
            //     color: statusColor,
            //     borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            //   ),
            // ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Row 1: Ticket No + Status chip ─────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Category icon badge
                      Container(
                        width: 38.w,
                        height: 38.w,
                        decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10.r)),
                        child: Icon(_categoryIcon, size: 18.sp, color: kPrimaryColor),
                      ),
                      SizedBox(width: 12.w),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '#${ticket.ticketNo}',
                                  style: kTextBold(color: kTextHintColor).copyWith(fontSize: 10.sp, letterSpacing: 0.8),
                                ),
                                if (ticket.serviceRequestNumber != null) ...[
                                  SizedBox(width: 8.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                    decoration: BoxDecoration(color: kInfoColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4.r)),
                                    child: Text(
                                      'Req #${ticket.serviceRequestNumber}',
                                      style: kTextBold(color: kInfoColor).copyWith(fontSize: 9.sp),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            SizedBox(height: 3.h),
                            Text(
                              ticket.subject,
                              style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 13.sp),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(width: 10.w),
                      // Status chip
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5.w,
                              height: 5.w,
                              decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                            ),
                            SizedBox(width: 5.w),
                            Text(
                              ticket.statusLabel.toUpperCase(),
                              style: kTextBold(color: statusColor).copyWith(fontSize: 9.sp, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 12.h),
                  Divider(color: kGreyColor1, height: 1),
                  SizedBox(height: 10.h),

                  // ── Row 2: Category + Priority + Date ──────────────
                  Row(
                    children: [
                      // Category tag
                      _MetaChip(icon: Icons.category_outlined, label: ticket.category.capitalizeFirst(), color: kTextSecondaryColor),
                      // SizedBox(width: 8.w),
                      // // Priority tag
                      // _MetaChip(icon: Icons.flag_rounded, label: ticket.priority.capitalizeFirst(), color: _priorityColor),
                      const Spacer(),
                      // Date
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 11.sp, color: kTextHintColor),
                          SizedBox(width: 4.w),
                          Text(
                            AppDateFormatter.smartDate(ticket.createdAt),
                            style: kTextNormal(color: kTextHintColor).copyWith(fontSize: 10.sp),
                          ),
                        ],
                      ),
                      SizedBox(width: 8.w),
                      Icon(Icons.chevron_right_rounded, size: 16.sp, color: kGreyColor4),
                    ],
                  ),

                  // ── Admin remark preview ───────────────────────────
                  if (ticket.adminRemark != null && ticket.adminRemark!.isNotEmpty) ...[
                    SizedBox(height: 10.h),
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: kScaffoldColor,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: kGreyColor1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.support_agent_rounded, size: 13.sp, color: kPrimaryColor),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              ticket.adminRemark!,
                              style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Meta Chip ────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.sp, color: color),
          SizedBox(width: 4.w),
          Text(
            label,
            style: kTextSemiBold(color: color).copyWith(fontSize: 10.sp),
          ),
        ],
      ),
    );
  }
}

// ─── Shimmer Card ─────────────────────────────────────────────────────────────

class _ShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: kGreyColor1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4.h,
            decoration: BoxDecoration(
              color: kGreyColor2,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ShimmerBox(width: 38.w, height: 38.w, radius: 10),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ShimmerBox(width: 80.w, height: 10.h, radius: 4),
                          SizedBox(height: 6.h),
                          _ShimmerBox(width: double.infinity, height: 13.h, radius: 4),
                        ],
                      ),
                    ),
                    SizedBox(width: 10.w),
                    _ShimmerBox(width: 60.w, height: 24.h, radius: 20),
                  ],
                ),
                SizedBox(height: 12.h),
                Divider(color: kGreyColor1, height: 1),
                SizedBox(height: 10.h),
                Row(
                  children: [
                    _ShimmerBox(width: 70.w, height: 22.h, radius: 6),
                    SizedBox(width: 8.w),
                    _ShimmerBox(width: 60.w, height: 22.h, radius: 6),
                    const Spacer(),
                    _ShimmerBox(width: 80.w, height: 12.h, radius: 4),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox({required this.width, required this.height, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: kGreyColor2, borderRadius: BorderRadius.circular(radius)),
    );
  }
}

extension StringExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
