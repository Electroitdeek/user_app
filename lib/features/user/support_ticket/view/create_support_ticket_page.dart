import 'package:adhisaat_health_care/core/theme/app_edge_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/screen_dimensions.dart';
import '../../../../di/locator.dart';
import '../../../../shared/widgets/buttons/custom_button.dart';
import '../../../../shared/widgets/common/app_bar_custom.dart';
import '../../../../shared/widgets/dialogs/dialog_helpers.dart';
import '../../../../shared/widgets/inputs/custom_text_field.dart';
import '../../service_booking/data/service_request_repository.dart';
import '../../service_booking/model/service_request_model.dart';
import '../data/support_ticket_repository.dart';

class CreateSupportTicketPage extends StatefulWidget {
  final String? serviceRequestId;
  final String? requestNumber;
  final String? serviceName;
  final String? category;
  final String? subject;
  const CreateSupportTicketPage({super.key, this.serviceRequestId, this.requestNumber, this.serviceName, this.category, this.subject});

  @override
  State<CreateSupportTicketPage> createState() => _CreateSupportTicketPageState();
}

class _CreateSupportTicketPageState extends State<CreateSupportTicketPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _descriptionNode = FocusNode();

  String? _selectedRequestId;
  String? _selectedRequestNumber;
  String? _selectedRequestLabel; // for subject prefill

  final String _selectedPriority = 'high';
  bool _isLoading = false;

  @override
  void dispose() {
    _descriptionNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _selectedRequestId = widget.serviceRequestId;
    _selectedRequestNumber = widget.requestNumber;
    if (widget.subject != null) {
      _subjectCtrl.text = widget.subject!;
    } else if (widget.serviceRequestId != null) {
      _selectedRequestLabel = widget.serviceName;
      final reqNum = widget.requestNumber ?? widget.serviceRequestId;
      if (widget.serviceName != null) {
        _subjectCtrl.text = '$reqNum - ${widget.serviceName}';
      } else {
        _subjectCtrl.text = '$reqNum';
      }
    }
  }

  void _showBookingPicker() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BookingPickerSheet(
        initialSelectedId: _selectedRequestId,
        onSelected: (booking) {
          setState(() {
            _selectedRequestId = booking?.id.toString();
            _selectedRequestNumber = booking?.requestNumber;
            _selectedRequestLabel = booking != null ? (booking.serviceName ?? booking.serviceCategoryName) : null;
          });
          if (booking != null) {
            final requestNum = booking.requestNumber ?? booking.id.toString();
            final serviceName = booking.serviceName ?? booking.serviceCategoryName;
            _subjectCtrl.text = '$requestNum - $serviceName';
          }
          Navigator.pop(context);
          if (booking != null) {
            _descriptionNode.requestFocus();
          }
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final repo = locator<SupportTicketRepository>();
      final response = await repo.createSupportTicket(
        subject: _subjectCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        priority: _selectedPriority,
        category: widget.category ?? (_selectedRequestId == null ? 'other' : 'service'),
        status: 'open',
        serviceRequestId: _selectedRequestId,
      );

      final ticketId = (response['data']?['id'] ?? response['data']?['ticket_id'] ?? response['id'])?.toString();

      if (mounted) {
        Navigator.pop(context, true);
        _showTicketCreatedDialog(ticketId);
      }
    } catch (e) {
      if (mounted) {
        DialogHelper.showError(title: 'Error', message: e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showTicketCreatedDialog(String? ticketId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64.w,
                height: 64.w,
                decoration: BoxDecoration(color: kSuccessColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(Icons.check_rounded, color: kSuccessColor, size: 32.sp),
              ),
              SizedBox(height: 16.h),
              Text('Ticket Created', style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 18.sp)),
              SizedBox(height: 8.h),
              Text(
                'Your support ticket has been submitted successfully.',
                style: kTextNormal(color: kTextSecondaryColor),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              CustomButton(
                title: 'Done',
                onPressed: () => Navigator.pop(ctx),
                backgroundColor: kSuccessColor,
                borderRadius: BorderRadius.circular(12.r),
                height: 46.h,
                width: double.infinity,
              ),
              if (ticketId != null) ...[
                SizedBox(height: 10.h),
                CustomButton(
                  title: 'View Ticket',
                  iconData: Icons.open_in_new_rounded,
                  onPressed: () {
                    Navigator.pop(ctx);
                    AppNavigator.to(AppRoutes.supportTicketDetail, arguments: ticketId);
                  },
                  backgroundColor: Colors.transparent,
                  textColor: kPrimaryColor,
                  iconColor: kPrimaryColor,
                  borderSide: BorderSide(color: kPrimaryColor.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(12.r),
                  height: 46.h,
                  width: double.infinity,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhiteColor,
      resizeToAvoidBottomInset: true,
      appBar: const CustomAppBar(title: 'New Ticket', centerTitle: true),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: AppPadding.screenHorizontal,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSpacing.lVertical,

                Center(
                  child: InkWell(
                    onTap: widget.serviceRequestId != null ? null : _showBookingPicker,
                    borderRadius: AppRadius.l,
                    child: Container(
                      width: 1.sw,
                      padding: AppPadding.symmetric(h: 20, v: 24),
                      decoration: BoxDecoration(
                        color: _selectedRequestId != null ? kPrimaryColor.withValues(alpha: 0.05) : kGreyColor1.withValues(alpha: 0.5),
                        borderRadius: AppRadius.xl,
                        border: Border.all(
                          color: _selectedRequestId != null ? kPrimaryColor.withValues(alpha: 0.2) : kGreyColor.withValues(alpha: 0.1),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: AppPadding.all(16),
                            decoration: BoxDecoration(
                              color: (_selectedRequestId != null ? kPrimaryColor : kGreyColor).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _selectedRequestId != null ? Icons.assignment_turned_in_rounded : Icons.assignment_add,
                              size: 32.sp,
                              color: _selectedRequestId != null ? kPrimaryColor : kGreyColor4,
                            ),
                          ),
                          AppSpacing.mVertical,
                          Text(
                            _selectedRequestId == null
                                ? 'Tap to select Associated Booking'
                                : '${_selectedRequestNumber ?? _selectedRequestId} - ${_selectedRequestLabel ?? 'Booking Selected'}',
                            textAlign: TextAlign.center,
                            style: kTextBold(color: _selectedRequestId == null ? kTextSecondaryColor : kTextPrimaryColor).copyWith(fontSize: 16.sp),
                          ),
                          if (_selectedRequestId != null) ...[
                            AppSpacing.xsVertical,
                            Text('Associated Service Request', style: kTextMedium0(color: kTextSecondaryColor)),
                            if (widget.serviceRequestId == null) ...[
                              AppSpacing.mVertical,
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                                decoration: BoxDecoration(color: kPrimaryColor, borderRadius: AppRadius.m),
                                child: Text(
                                  'Change Booking',
                                  style: kTextBold(color: kWhiteColor).copyWith(fontSize: 12.sp),
                                ),
                              ),
                            ],
                          ] else ...[
                            AppSpacing.sVertical,
                            Text(
                              'Relate this ticket to a previous service',
                              textAlign: TextAlign.center,
                              style: kTextNormal0(color: kTextHintColor),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                AppSpacing.lVertical,

                _FormCard(
                  title: 'Ticket Information',
                  icon: Icons.info_outline_rounded,
                  children: [
                    CustomTextField(
                      labelText: 'Subject',
                      isRequired: true,
                      controller: _subjectCtrl,
                      hintText: 'E.g. Issue with booking process',
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    AppSpacing.lVertical,
                    CustomTextField(
                      labelText: 'Description',
                      isRequired: true,
                      controller: _descriptionCtrl,
                      focusNode: _descriptionNode,
                      hintText: 'Please detail your issue here...',
                      maxLines: 6,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ],
                ),

                AppSpacing.lVertical,
                CustomButton(
                  title: 'Submit Ticket',
                  isLoading: _isLoading,
                  onPressed: _submit,
                  borderRadius: AppRadius.m,
                  width: double.infinity,
                ),
                SizedBox(height: 24.h + MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<Widget> children;
  final bool isRequired;

  const _FormCard({required this.title, this.icon, required this.children}) : isRequired = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 18.sp, color: kPrimaryColor), AppSpacing.sHorizontal],
            Text(
              title,
              style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 15.sp),
            ),
            if (isRequired)
              Text(
                ' *',
                style: kTextBold(color: kErrorColor).copyWith(fontSize: 15.sp),
              ),
          ],
        ),
        AppSpacing.lVertical,
        ...children,
      ],
    );
  }
}

class _BookingPickerSheet extends StatefulWidget {
  final String? initialSelectedId;
  final Function(ServiceRequestModel?) onSelected;

  const _BookingPickerSheet({this.initialSelectedId, required this.onSelected});

  @override
  State<_BookingPickerSheet> createState() => _BookingPickerSheetState();
}

class _BookingPickerSheetState extends State<_BookingPickerSheet> {
  final _searchCtrl = TextEditingController();
  final List<ServiceRequestModel> _bookings = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  static const _perPage = 10;

  @override
  void initState() {
    super.initState();
    _fetchPage(1);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int page) async {
    if (page == 1) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isLoadingMore = true);
    }
    try {
      final response = await locator<ServiceRequestRepository>().getServiceRequests(
        page: page,
        perPage: _perPage,
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      );
      setState(() {
        if (page == 1) _bookings.clear();
        _bookings.addAll(response.requests);
        _currentPage = page;
        _hasMore = response.hasMore;
      });
    } catch (_) {
      // Silently fail
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onSearchChanged(String _) {
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) _fetchPage(1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.85.sh,
      decoration: BoxDecoration(color: kWhiteColor, borderRadius: AppRadius.topOnly(28)),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: AppPadding.m,
              child: Column(
                children: [
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(10)),
                  ),
                  AppSpacing.mVertical,
                  Text('Select Associated Booking', style: kTextSemiBold1()),
                  AppSpacing.lVertical,
                  CustomTextField(
                    hintText: 'Search by ID, Category or Partner...',
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    prefixIcon: Icon(Icons.search_rounded, color: kPrimaryColor, size: 20.sp),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2))
                  : _bookings.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: AppPadding.screenHorizontal,
                      // +1 for None row, +1 for load more footer
                      itemCount: _bookings.length + 2,
                      itemBuilder: (context, index) {
                        // None option
                        if (index == 0) {
                          return _ItemCard(
                            title: 'None',
                            subtitle: 'Not related to any specific booking',
                            isSelected: widget.initialSelectedId == null,
                            onTap: () => widget.onSelected(null),
                            icon: Icons.not_interested_rounded,
                          );
                        }

                        // Load more footer
                        if (index == _bookings.length + 1) {
                          if (!_hasMore) return SizedBox(height: 40.h);
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            child: _isLoadingMore
                                ? const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2))
                                : Center(
                                    child: TextButton.icon(
                                      onPressed: () => _fetchPage(_currentPage + 1),
                                      icon: Icon(Icons.expand_more_rounded, color: kPrimaryColor, size: 18.sp),
                                      label: Text('Load more', style: kTextSemiBold(color: kPrimaryColor)),
                                    ),
                                  ),
                          );
                        }

                        final booking = _bookings[index - 1];
                        final isSelected = widget.initialSelectedId == booking.id.toString();
                        return _ItemCard(
                          title: booking.serviceName ?? booking.serviceCategoryName,
                          subtitle: '${booking.startDateText ?? booking.startDate ?? ''} • ${booking.startTimeText ?? ''}',
                          status: booking.statusLabel,
                          statusColor: _getStatusColor(booking.status),
                          isSelected: isSelected,
                          onTap: () => widget.onSelected(booking),
                          icon: Icons.medical_services_outlined,
                          provider: booking.providerName,
                          serviceMode: booking.serviceModeText ?? booking.serviceMode ?? '',
                          serviceType: booking.serviceTypeText ?? booking.serviceType ?? '',
                          amount: booking.totalAmount?.toString() ?? '0',
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.search_off_rounded, size: 48.sp, color: kGreyColor3),
        SizedBox(height: 12.h),
        Text(_searchCtrl.text.isEmpty ? 'No bookings found' : 'No bookings found for "${_searchCtrl.text}"', style: kTextMedium0(color: kGreyColor)),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'in_progress':
        return kPrimaryColor;
      case 'completed':
        return kSuccessColor;
      case 'cancelled':
        return kErrorColor;
      default:
        return kWarningColor;
    }
  }
}

class _ItemCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? status;
  final Color? statusColor;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;
  final String? provider;
  final String? serviceMode;
  final String? serviceType;
  final String? amount;

  const _ItemCard({
    required this.title,
    required this.subtitle,
    this.status,
    this.statusColor,
    required this.isSelected,
    required this.onTap,
    required this.icon,
    this.provider,
    this.serviceMode,
    this.serviceType,
    this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.l,
        child: Container(
          padding: AppPadding.all(16),
          decoration: BoxDecoration(
            color: kWhiteColor,
            borderRadius: AppRadius.l,
            border: Border.all(color: isSelected ? kPrimaryColor : kGreyColor.withValues(alpha: 0.1), width: isSelected ? 1.5 : 1.0),
            boxShadow: [
              BoxShadow(
                color: kBlackColor.withValues(alpha: isSelected ? 0.05 : 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: AppPadding.all(10),
                decoration: BoxDecoration(color: (isSelected ? kPrimaryColor : kGreyColor3).withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, color: isSelected ? kPrimaryColor : kGreyColor5, size: 20.sp),
              ),
              AppSpacing.mHorizontal,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(title, style: kTextSemiBold1(), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        AppSpacing.sHorizontal,
                        if (status != null)
                          Text(
                            status!,
                            style: kTextSemiBold0(color: statusColor ?? kGreyColor).copyWith(fontSize: 10.sp),
                          ),
                      ],
                    ),
                    AppSpacing.xsVertical,
                    Text(subtitle, style: kTextNormal0(color: kTextSecondaryColor)),
                    if (serviceMode != null || serviceType != null) ...[
                      AppSpacing.sVertical,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6.w,
                              runSpacing: 4.h,
                              children: [
                                if (serviceMode != null && serviceMode!.isNotEmpty) _MiniTag(label: serviceMode!),
                                if (serviceType != null && serviceType!.isNotEmpty) _MiniTag(label: serviceType!),
                              ],
                            ),
                          ),
                          if (amount != null && amount != '0') ...[
                            SizedBox(width: 8.w),
                            Text('₹$amount', style: kTextSemiBold1(color: kPrimaryColor)),
                          ],
                        ],
                      ),
                    ],
                    if (provider != null) ...[
                      AppSpacing.sVertical,
                      Row(
                        children: [
                          Icon(Icons.person_pin_rounded, size: 12.sp, color: kPrimaryColor),
                          AppSpacing.xsHorizontal,
                          Expanded(
                            child: Text(
                              'Provider: $provider',
                              style: kTextMedium0(color: kPrimaryColor).copyWith(fontSize: 11.sp),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected) ...[AppSpacing.sHorizontal, Icon(Icons.check_circle_rounded, color: kPrimaryColor, size: 20.sp)],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  const _MiniTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: kGreyColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: kBorderColor),
      ),
      child: Text(
        label.toUpperCase(),
        style: kTextMedium0(color: kTextSecondaryColor).copyWith(fontSize: 8.sp, letterSpacing: 0.5),
      ),
    );
  }
}
