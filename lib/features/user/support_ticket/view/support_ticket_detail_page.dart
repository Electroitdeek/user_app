import 'dart:io';

import 'package:adhisaat_health_care/shared/widgets/common/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/file_downloading_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_edge_insets.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/screen_dimensions.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/message_service.dart';
import '../../../../core/utils/number_utils.dart';
import '../../../../di/locator.dart';
import '../../../../shared/widgets/common/app_bar_custom.dart';
import '../../../../shared/widgets/dialogs/custom_bottom_sheets.dart';
import '../../booking_history/helper/booking_status_mapper.dart';
import '../data/support_ticket_repository.dart';
import '../model/support_ticket_model.dart';

class SupportTicketDetailPage extends StatefulWidget {
  final String ticketId;
  const SupportTicketDetailPage({super.key, required this.ticketId});

  @override
  State<SupportTicketDetailPage> createState() => _SupportTicketDetailPageState();
}

class _SupportTicketDetailPageState extends State<SupportTicketDetailPage> {
  late Future<SupportTicketModel> _ticketFuture;
  late Future<List<SupportTicketMessageModel>> _messagesFuture;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  File? _selectedFile;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _ticketFuture = locator<SupportTicketRepository>().getSupportTicketDetails(widget.ticketId);
      _messagesFuture = locator<SupportTicketRepository>().getSupportTicketMessages(widget.ticketId);
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Future<void> _pickFile() async {
    final file = await ChooseFileBottomSheet.show();
    if (file != null) {
      setState(() {
        _selectedFile = file;
      });
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty && _selectedFile == null) return;

    if (_selectedFile != null && messageText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a message to send with the attachment')));
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await locator<SupportTicketRepository>().sendSupportTicketMessage(
        ticketId: widget.ticketId,
        message: messageText,
        attachmentPath: _selectedFile?.path,
      );
      _messageController.clear();
      setState(() {
        _selectedFile = null;
      });
      _refresh();
      Future.delayed(const Duration(milliseconds: 500), _scrollToBottom);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _closeTicket() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xl),
        title: Text('Close Ticket', style: kTextBold()),
        content: const Text('Are you sure you want to close this support ticket? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: kTextMedium(color: kTextSecondaryColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: kErrorColor),
            child: const Text('Close Ticket'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await locator<SupportTicketRepository>().updateSupportTicketStatus(widget.ticketId, 'closed');
        _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Ticket closed successfully'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.m),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update ticket: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhiteColor,
      appBar: CustomAppBar(
        title: 'Ticket Details',
        backgroundColor: kScaffoldColor,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => _ticketFuture.then((ticket) {
              if (!context.mounted) return;
              _showTicketDetailsSheet(context, ticket: ticket);
            }),
            icon: Icon(Icons.info_outline_rounded, color: kSecondaryColor, size: 22.sp),
            tooltip: 'Ticket Details',
          ),
          IconButton(
            onPressed: _refresh,
            icon: Icon(Icons.refresh_rounded, color: kSecondaryColor, size: 22.sp),
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: FutureBuilder<SupportTicketModel>(
        future: _ticketFuture,
        builder: (context, ticketSnapshot) {
          if (ticketSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kSecondaryColor));
          }
          if (ticketSnapshot.hasError) {
            return _ErrorState(onRetry: _refresh, error: ticketSnapshot.error.toString());
          }

          final ticket = ticketSnapshot.data!;
          final canChat = ticket.status.toLowerCase() != 'closed' && ticket.status.toLowerCase() != 'resolved';

          return Container(
            color: kScaffoldColor,
            child: Column(
              children: [
                _TicketHeader(
                  ticket: ticket,
                  onViewDetails: () => _showTicketDetailsSheet(context, ticket: ticket),
                ),
                Expanded(
                  child: FutureBuilder<List<SupportTicketMessageModel>>(
                    future: _messagesFuture,
                    builder: (context, messagesSnapshot) {
                      if (messagesSnapshot.connectionState == ConnectionState.waiting && !messagesSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator(color: kSecondaryColor));
                      }

                      final messages = messagesSnapshot.data ?? [];

                      return CustomRefreshIndicator(
                        onRefresh: () async => _refresh(),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: AppPadding.screenHorizontal.copyWith(top: 24.h, bottom: 24.h),
                          itemCount: messages.isEmpty ? 1 : messages.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Column(
                                children: [
                                  _DateDivider(date: ticket.createdAt),
                                  AppSpacing.lVertical,
                                  _ChatBubble(message: ticket.description, time: ticket.createdAt, isMe: true, title: ticket.subject),
                                  if (messages.isEmpty && (ticket.adminRemark == null || ticket.adminRemark!.isEmpty)) const _WaitingStateCard(),
                                ],
                              );
                            }

                            final message = messages[index - 1];
                            return _ChatBubble(
                              message: message.message,
                              time: message.createdAt,
                              isMe: !message.isAdmin,
                              attachment: message.attachment,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),

                if (_selectedFile != null) _FilePreview(file: _selectedFile!, onRemove: () => setState(() => _selectedFile = null)),

                _BottomActionArea(
                  canChat: canChat,
                  isSending: _isSending,
                  controller: _messageController,
                  onSend: _sendMessage,
                  onPickFile: _pickFile,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showTicketDetailsSheet(BuildContext context, {SupportTicketModel? ticket}) async {
    final currentTicket = ticket ?? await _ticketFuture;
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TicketDetailsSheet(
        ticket: currentTicket,
        onCloseTicket: (currentTicket.status.toLowerCase() != 'closed' && currentTicket.status.toLowerCase() != 'resolved') ? _closeTicket : null,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  final String error;
  const _ErrorState({required this.onRetry, required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: AppPadding.all(20),
              decoration: BoxDecoration(color: kErrorColor.withValues(alpha: 0.05), shape: BoxShape.circle),
              child: Icon(Icons.error_outline_rounded, size: 40.sp, color: kErrorColor),
            ),
            SizedBox(height: 16.h),
            Text('Failed to load details', style: kTextSemiBold1()),
            SizedBox(height: 8.h),
            Text(
              error,
              style: kTextNormal0(color: kTextSecondaryColor),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: 120.w,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kSecondaryColor,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.m),
                ),
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilePreview extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;
  const _FilePreview({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: AppRadius.l,
        border: Border.all(color: kSecondaryColor.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: kBlackColor.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Container(
            padding: AppPadding.all(10),
            decoration: BoxDecoration(color: kSecondaryColor.withValues(alpha: 0.1), borderRadius: AppRadius.m),
            child: Icon(Icons.insert_drive_file_rounded, color: kSecondaryColor, size: 22.sp),
          ),
          AppSpacing.mHorizontal,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  file.path.split('/').last,
                  style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 13.sp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Ready to send',
                  style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: Container(
              padding: AppPadding.all(4),
              decoration: BoxDecoration(color: kErrorColor.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.close_rounded, color: kErrorColor, size: 16.sp),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActionArea extends StatelessWidget {
  final bool canChat;
  final bool isSending;
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onPickFile;

  const _BottomActionArea({required this.canChat, required this.isSending, required this.controller, required this.onSend, required this.onPickFile});

  @override
  Widget build(BuildContext context) {
    if (!canChat) {
      return Container(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: kWhiteColor,
          boxShadow: [BoxShadow(color: kBlackColor.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, -4))],
        ),
        child: Container(
          height: 56.h,
          width: double.infinity,
          decoration: BoxDecoration(
            color: kGreyColor1.withValues(alpha: 0.5),
            borderRadius: AppRadius.l,
            border: Border.all(color: kGreyColor2),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_rounded, color: kTextSecondaryColor, size: 18.sp),
                AppSpacing.mHorizontal,
                Text(
                  'Conversation closed',
                  style: kTextBold(color: kTextSecondaryColor).copyWith(fontSize: 14.sp),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        boxShadow: [BoxShadow(color: kBlackColor.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                margin: EdgeInsets.only(bottom: 4.h),
                child: Material(
                  color: kPrimaryColor.withValues(alpha: 0.1),
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: onPickFile,
                    icon: Icon(Icons.add_rounded, color: kPrimaryColor, size: 24.sp),
                  ),
                ),
              ),
              AppSpacing.sHorizontal,
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  style: kTextNormal(color: kTextPrimaryColor).copyWith(fontSize: 14.sp),
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    hintStyle: kTextNormal0(color: kTextHintColor),
                    filled: true,
                    fillColor: kGreyColor1.withValues(alpha: 0.8),
                    contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24.r),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24.r),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24.r),
                      borderSide: BorderSide(color: kPrimaryColor.withValues(alpha: 0.2), width: 1),
                    ),
                  ),
                ),
              ),
              AppSpacing.sHorizontal,
              Container(
                margin: EdgeInsets.only(bottom: 4.h),
                child: GestureDetector(
                  onTap: isSending ? null : onSend,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: AppPadding.all(12),
                    decoration: BoxDecoration(
                      color: isSending ? kGreyColor3 : null,
                      gradient: isSending ? null : const LinearGradient(colors: [kPrimaryColor, kSecondaryColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      shape: BoxShape.circle,
                      boxShadow: isSending
                          ? []
                          : [BoxShadow(color: kPrimaryColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: isSending
                        ? SizedBox(
                            height: 20.sp,
                            width: 20.sp,
                            child: const CircularProgressIndicator(color: kWhiteColor, strokeWidth: 2),
                          )
                        : Icon(Icons.send_rounded, color: kWhiteColor, size: 20.sp),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TicketHeader extends StatelessWidget {
  final SupportTicketModel ticket;
  final VoidCallback onViewDetails;

  const _TicketHeader({required this.ticket, required this.onViewDetails});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 12.w, 16.h),
      decoration: BoxDecoration(
        color: kWhiteColor,
        border: Border(bottom: BorderSide(color: kGreyColor.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ticket.subject,
                  style: kTextBold(color: kPrimaryColor).copyWith(fontSize: 14.sp),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                AppSpacing.xsVertical,
                Row(
                  children: [
                    _StatusChip(status: ticket.statusLabel, color: ticket.statusColor),
                    AppSpacing.sHorizontal,
                    Text(
                      'Ticket #${ticket.ticketNo}',
                      style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onViewDetails,
            icon: Icon(Icons.info_outline_rounded, color: kPrimaryColor, size: 20.sp),
          ),
        ],
      ),
    );
  }
}

class _TicketDetailsSheet extends StatelessWidget {
  final SupportTicketModel ticket;
  final VoidCallback? onCloseTicket;

  const _TicketDetailsSheet({required this.ticket, this.onCloseTicket});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: 0.9.sh),
      decoration: BoxDecoration(
        color: kScaffoldColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(context),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuickInfoGrid(),
                  AppSpacing.lVertical,
                  _buildSectionHeader('Subject'),
                  _buildSubjectCard(),
                  AppSpacing.lVertical,
                  _buildSectionHeader('Description'),
                  _buildDescriptionCard(),
                  if (ticket.adminRemark != null && ticket.adminRemark!.isNotEmpty) ...[
                    AppSpacing.lVertical,
                    _buildSectionHeader('Admin Response'),
                    _buildAdminRemarkCard(),
                  ],
                  // if (ticket.adminName != null) ...[AppSpacing.lVertical, _buildSectionHeader('Assigned Support'), _buildAssignmentCard()],
                  if (ticket.serviceRequestNumber != null) ...[AppSpacing.lVertical, _buildSectionHeader('Booking Reference'), _buildBookingCard()],
                  AppSpacing.xlVertical,
                ],
              ),
            ),
          ),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 12.h),
        width: 40.w,
        height: 4.h,
        decoration: BoxDecoration(color: kGreyColor2, borderRadius: BorderRadius.circular(2.r)),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
      decoration: BoxDecoration(
        color: kScaffoldColor,
        border: Border(bottom: BorderSide(color: kGreyColor.withValues(alpha: 0.05))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ticket Details',
                  style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 20.sp),
                ),
                AppSpacing.xsVertical,
                Row(
                  children: [
                    Text(
                      'Ticket #${ticket.ticketNo}',
                      style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                    ),
                    AppSpacing.sHorizontal,
                    _StatusChip(status: ticket.statusLabel, color: ticket.statusColor),
                  ],
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: AppPadding.all(6),
              decoration: const BoxDecoration(color: kWhiteColor, shape: BoxShape.circle),
              child: Icon(Icons.close_rounded, color: kTextPrimaryColor, size: 20.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfoGrid() {
    return Container(
      margin: EdgeInsets.only(top: 16.h),
      padding: AppPadding.all(16),
      decoration: BoxDecoration(color: kWhiteColor, borderRadius: AppRadius.l),
      child: Row(
        children: [
          _GridItem(icon: Icons.category_outlined, label: 'Category', value: ticket.category.capitalizeFirst()),
          _GridDivider(),
          _GridItem(
            icon: Icons.flag_outlined,
            label: 'Priority',
            value: ticket.priority.capitalizeFirst(),
            valueColor: ticket.priority.toLowerCase() == 'high' ? kErrorColor : kTextPrimaryColor,
          ),
          _GridDivider(),
          _GridItem(icon: Icons.calendar_today_outlined, label: 'Date', value: AppDateFormatter.smartDate(ticket.createdAt).split(',')[0]),
        ],
      ),
    );
  }

  Widget _buildSubjectCard() {
    return Container(
      width: double.infinity,
      padding: AppPadding.all(16),
      decoration: BoxDecoration(color: kWhiteColor, borderRadius: AppRadius.l),
      child: Text(
        ticket.subject,
        style: kTextBold(color: kTextPrimaryColor).copyWith(height: 1.5, fontSize: 13.sp),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      width: double.infinity,
      padding: AppPadding.all(16),
      decoration: BoxDecoration(color: kWhiteColor, borderRadius: AppRadius.l),
      child: Text(
        ticket.description,
        style: kTextNormal(color: kTextPrimaryColor).copyWith(height: 1.5, fontSize: 13.sp),
      ),
    );
  }

  Widget _buildAdminRemarkCard() {
    return Container(
      width: double.infinity,
      padding: AppPadding.all(16),
      decoration: BoxDecoration(
        color: kSecondaryColor.withValues(alpha: 0.05),
        borderRadius: AppRadius.l,
        border: Border.all(color: kSecondaryColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: kSecondaryColor, size: 16.sp),
              AppSpacing.sHorizontal,
              Text(
                'Support Reply',
                style: kTextBold(color: kSecondaryColor).copyWith(fontSize: 12.sp),
              ),
            ],
          ),
          AppSpacing.sVertical,
          Text(
            ticket.adminRemark!,
            style: kTextNormal(color: kTextPrimaryColor).copyWith(height: 1.5, fontSize: 13.sp),
          ),
        ],
      ),
    );
  }


  Widget _buildBookingCard() {
    return Container(
      padding: AppPadding.all(16),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: AppRadius.l,
        border: Border.all(color: kGreyColor.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '#${ticket.serviceRequestNumber}',
                  style: kTextBold(color: kSecondaryColor).copyWith(fontSize: 14.sp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8.w),
              if (ticket.serviceRequest != null)
                Builder(
                  builder: (context) {
                    final sr = ticket.serviceRequest!;
                    final status = BookingStatusMapper.fromString(sr.status);
                    final type = BookingStatusMapper.typeFromString(sr.serviceType ?? '');
                    final bookingConfig = BookingStatusMapper.getConfig(status, type, sr.paymentStatus ?? '');
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: bookingConfig.bgColor,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(bookingConfig.icon, size: 14.sp, color: bookingConfig.primaryColor),
                          SizedBox(width: 4.w),
                          Text(
                            bookingConfig.label.toUpperCase(),
                            style: kTextBold(color: bookingConfig.primaryColor).copyWith(fontSize: 10.sp, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    );
                  },
                )
              else if (ticket.bookingStatusText != null)
                Text(
                  ticket.bookingStatusText!.replaceAll(RegExp(r'<[^>]*>'), ''),
                  style: kTextBold(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
                ),
            ],
          ),
          AppSpacing.mVertical,
          Text(
             ticket.subject.contains(' - ') ? ticket.subject.split(' - ').last.trim() : ticket.subject,
             style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 15.sp),
             maxLines: 2,
             overflow: TextOverflow.ellipsis,
          ),
          if (ticket.bookingStartDate != null) ...[
            AppSpacing.sVertical,
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 14.sp, color: kGreyColor4),
                AppSpacing.sHorizontal,
                Text(
                  AppDateFormatter.dateRangeShort(ticket.bookingStartDate, ticket.bookingEndDate),
                  style: kTextSemiBold1(color: kTextPrimaryColor).copyWith(fontSize: 12.sp),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    if (onCloseTicket == null) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: kWhiteColor,
        boxShadow: [BoxShadow(color: kBlackColor.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onCloseTicket!();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: kErrorColor,
            foregroundColor: kWhiteColor,
            padding: EdgeInsets.symmetric(vertical: 16.h),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.m),
            elevation: 0,
          ),
          child: Text('Resolve & Close Ticket', style: kTextBold().copyWith(fontSize: 14.sp)),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h, left: 4.w),
      child: Text(
        title.toUpperCase(),
        style: kTextBold(color: kTextSecondaryColor).copyWith(fontSize: 11.sp, letterSpacing: 0.5),
      ),
    );
  }
}


class _GridItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _GridItem({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18.sp, color: kSecondaryColor.withValues(alpha: 0.6)),
          AppSpacing.xsVertical,
          Text(
            label,
            style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 10.sp),
          ),
          AppSpacing.xsVertical,
          Text(
            value,
            style: kTextBold(color: valueColor ?? kTextPrimaryColor).copyWith(fontSize: 12.sp),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _GridDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32.h,
      width: 1,
      color: kGreyColor.withValues(alpha: 0.1),
      margin: EdgeInsets.symmetric(horizontal: 8.w),
    );
  }
}


class _StatusChip extends StatelessWidget {
  final String status;
  final Color color;
  final bool isOutline;
  const _StatusChip({required this.status, required this.color}) : isOutline = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: isOutline ? Colors.transparent : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: isOutline ? 0.3 : 0.0)),
      ),
      child: Text(
        status.toUpperCase(),
        style: kTextBold(color: color).copyWith(fontSize: 9.sp, letterSpacing: 0.5),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String message;
  final String time;
  final bool isMe;
  final String? title;
  final String? attachment;

  const _ChatBubble({required this.message, required this.time, required this.isMe, this.title, this.attachment});

  @override
  Widget build(BuildContext context) {
    final textColor = isMe ? kWhiteColor : kTextPrimaryColor;
    final subTextColor = isMe ? kWhiteColor.withValues(alpha: 0.8) : kTextSecondaryColor;

    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              Container(
                margin: EdgeInsets.only(top: 2.h),
                child: CircleAvatar(
                  radius: 15.r,
                  backgroundColor: kSecondaryColor.withValues(alpha: 0.1),
                  child: Icon(Icons.support_agent_rounded, color: kSecondaryColor, size: 16.sp),
                ),
              ),
              SizedBox(width: 8.w),
            ],
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 0.82.sw),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: isMe ? null : kWhiteColor,
                    gradient: isMe ? const LinearGradient(colors: [kPrimaryColor, kSecondaryColor], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16.r),
                      topRight: Radius.circular(16.r),
                      bottomLeft: Radius.circular(isMe ? 16.r : 4.r),
                      bottomRight: Radius.circular(isMe ? 4.r : 16.r),
                    ),
                    boxShadow: [BoxShadow(color: isMe ? kPrimaryColor.withValues(alpha: 0.18) : kBlackColor.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null) ...[
                      Text(
                        title!,
                        style: kTextSemiBold(color: textColor).copyWith(fontSize: 13.sp, height: 1.3),
                      ),
                      SizedBox(height: 6.h),
                      Container(
                        height: 1,
                        width: double.infinity,
                        color: textColor.withValues(alpha: 0.15),
                      ),
                      SizedBox(height: 6.h),
                    ],
                    if (attachment != null && attachment!.isNotEmpty) ...[_AttachmentPreview(url: attachment!, isMe: isMe), SizedBox(height: 6.h)],
                    if (message.isNotEmpty)
                      Text(
                        message,
                        style: kTextNormal(color: textColor).copyWith(height: 1.35, fontSize: 13.sp),
                      ),
                    SizedBox(height: 3.h),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppDateFormatter.smartDate(time).split(',').last.trim(),
                            style: kTextNormal0(color: subTextColor).copyWith(fontSize: 9.sp),
                          ),
                          if (isMe) ...[SizedBox(width: 3.w), Icon(Icons.done_all_rounded, color: kWhiteColor.withValues(alpha: 0.9), size: 12.sp)],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),),
          ],
        ),
        SizedBox(height: 16.h),
      ],
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  final String url;
  final bool isMe;
  const _AttachmentPreview({required this.url, this.isMe = false});

  @override
  Widget build(BuildContext context) {
    final isImage = url.toLowerCase().endsWith('.jpg') || url.toLowerCase().endsWith('.jpeg') || url.toLowerCase().endsWith('.png');

    final absoluteUrl = _getAbsoluteUrl(url);
    final contentColor = isMe ? kWhiteColor : kSecondaryColor;

    return InkWell(
      onTap: () {
        if (!isNotNull(absoluteUrl)) {
          MessageService.showInfo('Attachment not available');
          return;
        }
        final downloadService = FileDownloadService();
        downloadService.downloadAndViewFile(url: absoluteUrl);
      },
      borderRadius: AppRadius.s,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.s,
          border: Border.all(color: kGreyColor2),
        ),
        child: isImage
            ? ClipRRect(
                borderRadius: AppRadius.s,
                child: Image.network(
                  absoluteUrl,
                  height: 150.h,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                ),
              )
            : ListTile(
                leading: Icon(Icons.insert_drive_file_rounded, color: contentColor),
                title: Text('Attachment', style: kTextMedium(color: contentColor)),
                trailing: Icon(Icons.download_rounded, color: contentColor),
              ),
      ),
    );
  }

  String _getAbsoluteUrl(String url) {
    if (url.isEmpty || url.startsWith('http') || url.startsWith('file://') || url.startsWith('data:')) {
      return url;
    }
    final baseUrl = AppConstants.baseUrl;
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanPath = url.startsWith('/') ? url.substring(1) : url;
    return '$cleanBase/$cleanPath';
  }
}

class _DateDivider extends StatelessWidget {
  final String date;
  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: kGreyColor3, thickness: 0.5)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            AppDateFormatter.smartDate(date).toUpperCase(),
            style: kTextBold(color: kTextHintColor).copyWith(fontSize: 9.sp, letterSpacing: 1),
          ),
        ),
        Expanded(child: Divider(color: kGreyColor3, thickness: 0.5)),
      ],
    );
  }
}

class _WaitingStateCard extends StatelessWidget {
  const _WaitingStateCard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: EdgeInsets.only(top: 40.h),
        padding: AppPadding.all(32),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: AppRadius.xl,
          boxShadow: [BoxShadow(color: kBlackColor.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: AppPadding.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [kPrimaryColor.withValues(alpha: 0.1), kSecondaryColor.withValues(alpha: 0.1)]),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.forum_rounded, color: kPrimaryColor, size: 48.sp),
            ),
            AppSpacing.lVertical,
            Text(
              'Ticket Submitted',
              style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 18.sp),
              textAlign: TextAlign.center,
            ),
            AppSpacing.sVertical,
            Text(
              'Our support team has been notified.\nYou\'ll receive a response here shortly.',
              style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 13.sp, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
