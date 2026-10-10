import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/message_service.dart';
import '../../../../di/locator.dart';
import '../../../../shared/widgets/buttons/custom_button.dart';
import '../../../../shared/widgets/inputs/custom_text_field.dart';
import '../../service_booking/data/rating_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry-point — call this from anywhere to show the feedback sheet.
// ─────────────────────────────────────────────────────────────────────────────
Future<bool?> showFeedbackBottomSheet({
  required BuildContext context,
  required int bookingId,
  int? bookingSubBlockId,
  String? providerName,
  String? serviceName,
  VoidCallback? onSuccess,
  bool isEditing = false,
  int? initialRating,
  int? initialPunctuality,
  int? initialBehavior,
  int? initialSkill,
  String? initialComment,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FeedbackBottomSheet(
      bookingId: bookingId,
      bookingSubBlockId: bookingSubBlockId,
      providerName: providerName,
      serviceName: serviceName,
      onSuccess: onSuccess,
      isEditing: isEditing,
      initialRating: initialRating,
      initialPunctuality: initialPunctuality,
      initialBehavior: initialBehavior,
      initialSkill: initialSkill,
      initialComment: initialComment,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Sheet Widget
// ─────────────────────────────────────────────────────────────────────────────
class _FeedbackBottomSheet extends StatefulWidget {
  final int bookingId;
  final int? bookingSubBlockId;
  final String? providerName;
  final String? serviceName;
  final VoidCallback? onSuccess;
  final bool isEditing;
  final int? initialRating;
  final int? initialPunctuality;
  final int? initialBehavior;
  final int? initialSkill;
  final String? initialComment;

  const _FeedbackBottomSheet({
    required this.bookingId,
    this.bookingSubBlockId,
    this.providerName,
    this.serviceName,
    this.onSuccess,
    this.isEditing = false,
    this.initialRating,
    this.initialPunctuality,
    this.initialBehavior,
    this.initialSkill,
    this.initialComment,
  });

  @override
  State<_FeedbackBottomSheet> createState() => _FeedbackBottomSheetState();
}

class _FeedbackBottomSheetState extends State<_FeedbackBottomSheet> {
  // ── Rating values ──
  int _overallRating = 0;
  int _punctualityRating = 0;
  int _behaviorRating = 0;
  int _skillRating = 0;

  // ── Comment ──
  final _commentCtrl = TextEditingController();

  // ── Complaint toggle ──
  final bool _isComplaint = false;
  String? _complaintType;
  final _subjectCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  String _priority = 'low';
  final String _status = 'open';

  // ── State ──
  bool _isSubmitting = false;
  String? _errorMessage;

  static const _complaintTypes = [
    ('service_quality', 'Service Quality'),
    ('behavior', 'Provider Behavior'),
    ('fraud', 'Fraud'),
    ('safety', 'Safety Issue'),
    ('payment', 'Payment Issue'),
    ('other', 'Other'),
  ];

  @override
  void initState() {
    super.initState();
    _overallRating = widget.initialRating ?? 0;
    _punctualityRating = widget.initialPunctuality ?? 0;
    _behaviorRating = widget.initialBehavior ?? 0;
    _skillRating = widget.initialSkill ?? 0;
    if (widget.initialComment != null) _commentCtrl.text = widget.initialComment!;
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _subjectCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    if (_overallRating == 0) return false;
    if (_isComplaint) {
      if (_complaintType == null) return false;
      if (_subjectCtrl.text.trim().isEmpty) return false;
      if (_descriptionCtrl.text.trim().isEmpty) return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_isFormValid) {
      setState(
        () => _errorMessage = _overallRating == 0
            ? 'Please select an overall rating.'
            : _isComplaint && _complaintType == null
            ? 'Please select a complaint type.'
            : 'Please fill in all complaint fields.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repo = locator<RatingRepository>();
      final success = await repo.submitRating(
        bookingId: widget.bookingId,
        bookingSubBlockId: widget.bookingSubBlockId,
        rating: _overallRating,
        feedbackComment: _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
        punctualityRating: _punctualityRating > 0 ? _punctualityRating : null,
        behaviorRating: _behaviorRating > 0 ? _behaviorRating : null,
        skillRating: _skillRating > 0 ? _skillRating : null,
        isComplaint: _isComplaint,
        complaintType: _isComplaint ? _complaintType : null,
        complaintSubject: _isComplaint ? _subjectCtrl.text.trim() : null,
        complaintDescription: _isComplaint ? _descriptionCtrl.text.trim() : null,
        status: _isComplaint ? _status : null,
        priority: _isComplaint ? _priority : null,
      );

      if (!mounted) return;

      if (success) {
        widget.onSuccess?.call();
        Navigator.of(context).pop(true);
        MessageService.showSuccess(widget.isEditing ? 'Rating updated! Thank you.' : 'Feedback submitted! Thank you.');
      } else {
        setState(() => _errorMessage = 'Failed to submit feedback. Please try again.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: MediaQuery.of(context).viewInsets,
      // Sheet takes up to 92% of screen height
      height: 0.92.sh,
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        children: [
          // ── 1. Drag handle — always visible at very top ──────────────
          _DragHandle(),

          // ── 2. Sticky header — "Rate Your Experience" ────────────────
          _Header(providerName: widget.providerName, serviceName: widget.serviceName, isEditing: widget.isEditing),

          Divider(height: 1, color: kDividerColor),

          // ── 3. Scrollable form content ───────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                20.w,
                16.h,
                20.w,
                // Add extra bottom padding when keyboard is up so content
                // isn't hidden behind it
                16.h + bottomInset,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Overall rating ─────────────────────────────────
                  _SectionLabel(label: 'Overall Experience', isRequired: true),
                  SizedBox(height: 10.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 16.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [kWarningColor.withValues(alpha: 0.06), kWarningColor.withValues(alpha: 0.02)],
                      ),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: kWarningColor.withValues(alpha: 0.18)),
                    ),
                    child: Column(
                      children: [
                        _StarRatingRow(
                          rating: _overallRating,
                          size: 40,
                          onChanged: (v) => setState(() {
                            _overallRating = v;
                            _errorMessage = null;
                          }),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          child: _overallRating > 0
                              ? Padding(
                                  padding: EdgeInsets.only(top: 12.h),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                                    decoration: BoxDecoration(
                                      color: _ratingColor(_overallRating).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20.r),
                                    ),
                                    child: Text(
                                      _ratingLabel(_overallRating),
                                      style: kTextBold0(color: _ratingColor(_overallRating)).copyWith(fontSize: 13.sp),
                                    ),
                                  ),
                                )
                              : Padding(
                                  padding: EdgeInsets.only(top: 10.h),
                                  child: Text('Tap a star to rate', style: kTextNormal0(color: kTextSecondaryColor)),
                                ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 22.h),

                  // ── Sub-ratings ───────────────────────────────────
                  _SectionLabel(label: 'Rate Specific Aspects', showOptional: true),
                  SizedBox(height: 12.h),
                  _SubRatingTile(
                    icon: Icons.access_time_rounded,
                    label: 'Punctuality',
                    rating: _punctualityRating,
                    onChanged: (v) => setState(() => _punctualityRating = v),
                  ),
                  SizedBox(height: 10.h),
                  _SubRatingTile(
                    icon: Icons.handshake_rounded,
                    label: 'Behavior',
                    rating: _behaviorRating,
                    onChanged: (v) => setState(() => _behaviorRating = v),
                  ),
                  SizedBox(height: 10.h),
                  _SubRatingTile(icon: Icons.build_rounded, label: 'Skill', rating: _skillRating, onChanged: (v) => setState(() => _skillRating = v)),

                  SizedBox(height: 20.h),

                  // ── Comment ───────────────────────────────────────
                  _SectionLabel(label: 'Additional Comments', showOptional: true),
                  SizedBox(height: 8.h),
                  CustomTextField(
                    controller: _commentCtrl,
                    hintText: 'Share your experience...',
                    maxLines: 3,
                    backgroundColor: kScaffoldColor,
                    borderRadius: 12,
                  ),

                  SizedBox(height: 20.h),

                  // // ── Complaint toggle ──────────────────────────────
                  // _ComplaintToggle(
                  //   value: _isComplaint,
                  //   onChanged: (v) => setState(() {
                  //     _isComplaint = v;
                  //     if (!v) {
                  //       _complaintType = null;
                  //       _subjectCtrl.clear();
                  //       _descriptionCtrl.clear();
                  //     }
                  //   }),
                  // ),

                  // ── Complaint section (animated expand) ───────────
                  AnimatedSize(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOut,
                    child: _isComplaint
                        ? _ComplaintSection(
                            selectedType: _complaintType,
                            complaintTypes: _complaintTypes,
                            selectedPriority: _priority,
                            subjectCtrl: _subjectCtrl,
                            descriptionCtrl: _descriptionCtrl,
                            onTypeSelected: (t) => setState(() {
                              _complaintType = t;
                              _errorMessage = null;
                            }),
                            onPrioritySelected: (p) => setState(() {
                              _priority = p;
                            }),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // ── Error message ─────────────────────────────────
                  if (_errorMessage != null) ...[SizedBox(height: 12.h), _ErrorBanner(message: _errorMessage!)],

                  // Spacer so last item isn't flush against the sticky button
                  SizedBox(height: 8.h),
                ],
              ),
            ),
          ),

          // ── 4. Sticky submit button — always visible at bottom ───────
          Container(
            decoration: BoxDecoration(
              color: kWhiteColor,
              border: Border(top: BorderSide(color: kDividerColor)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -3))],
            ),
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h + MediaQuery.of(context).padding.bottom),
            child: CustomButton(
              width: double.infinity,
              onPressed: _isSubmitting ? null : _submit,
              title: _isSubmitting ? 'Submitting...' : (widget.isEditing ? 'Update Feedback' : 'Submit Feedback'),
              iconData: _isSubmitting ? null : Icons.send_rounded,
              isLoading: _isSubmitting,
              backgroundColor: _isFormValid ? kPrimaryColor : kButtonDisabledColor,
              textColor: kWhiteColor,
            ),
          ),
        ],
      ),
    );
  }

  String _ratingLabel(int r) => const {1: 'Poor', 2: 'Fair', 3: 'Good', 4: 'Very Good', 5: 'Excellent'}[r]!;

  Color _ratingColor(int r) => r <= 2
      ? kErrorColor
      : r == 3
      ? kWarningColor
      : kSuccessColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 12.h, bottom: 4.h),
      child: Center(
        child: Container(
          width: 40.w,
          height: 4.h,
          decoration: BoxDecoration(color: kGreyColor3, borderRadius: BorderRadius.circular(4.r)),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String? providerName;
  final String? serviceName;
  final bool isEditing;

  const _Header({this.providerName, this.serviceName, this.isEditing = false});

  @override
  Widget build(BuildContext context) {
    final subtitle = isEditing
        ? 'Update your rating and feedback below.'
        : providerName != null
        ? 'How was your service by $providerName?'
        : serviceName != null
        ? 'How was your $serviceName experience?'
        : 'Your feedback helps us improve.';

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 14.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(color: kWarningColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10.r)),
            child: Icon(Icons.star_rounded, color: kWarningColor, size: 20.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEditing ? 'Update Your Rating' : 'Rate Your Experience', style: kTextBold1()),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: kTextNormal0(color: kTextSecondaryColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Close button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: kScaffoldColor,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: kDividerColor),
              ),
              child: Icon(Icons.close_rounded, size: 16.sp, color: kTextSecondaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isRequired;
  final bool showOptional;

  const _SectionLabel({required this.label, this.isRequired = false, this.showOptional = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: kTextSemiBold()),
        if (isRequired) ...[SizedBox(width: 3.w), Text('*', style: kTextSemiBold(color: kErrorColor))],
        if (showOptional) ...[
          SizedBox(width: 6.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
            decoration: BoxDecoration(color: kScaffoldColor, borderRadius: BorderRadius.circular(5.r)),
            child: Text('Optional', style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 10.sp)),
          ),
        ],
      ],
    );
  }
}

// ── Star rating row (large, for overall) ─────────────────────────────────────
class _StarRatingRow extends StatelessWidget {
  final int rating;
  final double size;
  final ValueChanged<int> onChanged;

  const _StarRatingRow({required this.rating, required this.onChanged, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final starValue = i + 1;
        final selected = starValue <= rating;
        return GestureDetector(
          onTap: () => onChanged(starValue),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6.w),
            child: AnimatedScale(
              scale: selected ? 1.0 : 0.88,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              child: Icon(
                selected ? Icons.star_rounded : Icons.star_outline_rounded,
                color: selected ? kWarningColor : kGreyColor4,
                size: size.sp,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Sub-rating tile (small, labelled) ────────────────────────────────────────
class _SubRatingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int rating;
  final ValueChanged<int> onChanged;

  const _SubRatingTile({required this.icon, required this.label, required this.rating, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final rated = rating > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
      decoration: BoxDecoration(
        color: rated ? kWarningColor.withValues(alpha: 0.05) : kScaffoldColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: rated ? kWarningColor.withValues(alpha: 0.30) : kDividerColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8.r)),
            child: Icon(icon, size: 16.sp, color: kPrimaryColor),
          ),
          SizedBox(width: 10.w),
          Text(label, style: kTextMedium()),
          const Spacer(),
          Row(
            children: List.generate(5, (i) {
              final v = i + 1;
              return GestureDetector(
                onTap: () => onChanged(v),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.only(left: 3.w),
                  child: Icon(
                    v <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: v <= rating ? kWarningColor : kGreyColor4,
                    size: 21.sp,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── Complaint section ─────────────────────────────────────────────────────────
class _ComplaintSection extends StatelessWidget {
  final String? selectedType;
  final List<(String, String)> complaintTypes;
  final String selectedPriority;
  final TextEditingController subjectCtrl;
  final TextEditingController descriptionCtrl;
  final ValueChanged<String> onTypeSelected;
  final ValueChanged<String> onPrioritySelected;

  const _ComplaintSection({
    required this.selectedType,
    required this.complaintTypes,
    required this.selectedPriority,
    required this.subjectCtrl,
    required this.descriptionCtrl,
    required this.onTypeSelected,
    required this.onPrioritySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16.h),

        // Complaint type chips
        _SectionLabel(label: 'Complaint Type', isRequired: true),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: complaintTypes.map((ct) {
            final isSelected = selectedType == ct.$1;
            return GestureDetector(
              onTap: () => onTypeSelected(ct.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
                decoration: BoxDecoration(
                  color: isSelected ? kErrorColor : kScaffoldColor,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: isSelected ? kErrorColor : kBorderColor),
                ),
                child: Text(ct.$2, style: kTextSemiBold0(color: isSelected ? kWhiteColor : kTextSecondaryColor)),
              ),
            );
          }).toList(),
        ),

        SizedBox(height: 14.h),

        // Subject
        _SectionLabel(label: 'Subject', isRequired: true),
        SizedBox(height: 8.h),
        CustomTextField(controller: subjectCtrl, hintText: 'Brief subject of your complaint', backgroundColor: kScaffoldColor, borderRadius: 12),

        SizedBox(height: 14.h),

        // Description
        _SectionLabel(label: 'Description', isRequired: true),
        SizedBox(height: 8.h),
        CustomTextField(
          controller: descriptionCtrl,
          hintText: 'Describe the issue in detail...',
          maxLines: 4,
          backgroundColor: kScaffoldColor,
          borderRadius: 12,
        ),

        SizedBox(height: 14.h),

        // Priority
        _SectionLabel(label: 'Priority'),
        SizedBox(height: 8.h),
        Row(
          children: [
            _PriorityChip(
              label: 'Low',
              value: 'low',
              isSelected: selectedPriority == 'low',
              color: kSuccessColor,
              onTap: () => onPrioritySelected('low'),
            ),
            SizedBox(width: 8.w),
            _PriorityChip(
              label: 'Medium',
              value: 'medium',
              isSelected: selectedPriority == 'medium',
              color: kWarningColor,
              onTap: () => onPrioritySelected('medium'),
            ),
            SizedBox(width: 8.w),
            _PriorityChip(
              label: 'High',
              value: 'high',
              isSelected: selectedPriority == 'high',
              color: kErrorColor,
              onTap: () => onPrioritySelected('high'),
            ),
          ],
        ),
      ],
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _PriorityChip({required this.label, required this.value, required this.isSelected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: isSelected ? color : kScaffoldColor,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: isSelected ? color : kBorderColor),
        ),
        child: Text(label, style: kTextSemiBold0(color: isSelected ? kWhiteColor : kTextSecondaryColor)),
      ),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: kErrorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: kErrorColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 16.sp, color: kErrorColor),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(message, style: kTextNormal0(color: kErrorColor)),
          ),
        ],
      ),
    );
  }
}
