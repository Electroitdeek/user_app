import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/shared/widgets/buttons/custom_button.dart';
import 'package:adhisaat_health_care/shared/widgets/inputs/custom_text_field.dart';
import 'package:adhisaat_health_care/core/utils/message_service.dart';
import '../bloc/user_feedback_bloc.dart';
import '../../../../features/service_provider/feedback/data/model/feedback_model.dart';

Future<void> showUserAddFeedbackBottomSheet(BuildContext context, UserFeedbackBloc feedbackBloc, {FeedbackModel? existingFeedback}) {
  return showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => BlocProvider.value(
      value: feedbackBloc,
      child: _UserAddFeedbackBottomSheet(existingFeedback: existingFeedback),
    ),
  );
}

class _UserAddFeedbackBottomSheet extends StatefulWidget {
  final FeedbackModel? existingFeedback;
  const _UserAddFeedbackBottomSheet({this.existingFeedback});

  @override
  State<_UserAddFeedbackBottomSheet> createState() => _UserAddFeedbackBottomSheetState();
}

class _UserAddFeedbackBottomSheetState extends State<_UserAddFeedbackBottomSheet> {
  int _rating = 0;
  String _feedbackType = 'general';
  final _feedbackTextCtrl = TextEditingController();

  final List<String> _feedbackTypes = ['general', 'feature_request', 'bug_report', 'improvement'];

  @override
  void initState() {
    super.initState();
    if (widget.existingFeedback != null) {
      _rating = widget.existingFeedback!.rating;
      _feedbackType = _feedbackTypes.contains(widget.existingFeedback!.feedbackType) 
          ? widget.existingFeedback!.feedbackType 
          : 'general';
      _feedbackTextCtrl.text = widget.existingFeedback!.feedbackText;
    }
  }

  @override
  void dispose() {
    _feedbackTextCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return BlocListener<UserFeedbackBloc, UserFeedbackState>(
      listener: (context, state) {
        if (state is UserFeedbackSubmitSuccess) {
          Navigator.pop(context);
          MessageService.showSuccess('Feedback submitted successfully!');
        } else if (state is UserFeedbackSubmitError) {
          MessageService.showError(state.message);
        }
      },
      child: Container(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h + bottomInset),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: kDividerColor,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Text(widget.existingFeedback != null ? 'Update Feedback' : 'Submit App Feedback', style: kTextBold1()),
              SizedBox(height: 8.h),
              Text(
                'Tell us how you like the Adhisaat app.',
                style: kTextNormal0(color: kTextSecondaryColor),
              ),
              SizedBox(height: 24.h),
              Text('Rating', style: kTextSemiBold()),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () => setState(() => _rating = index + 1),
                    icon: Icon(
                      index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: index < _rating ? Colors.orange : kDividerColor,
                      size: 40.sp,
                    ),
                  );
                }),
              ),
              SizedBox(height: 24.h),
              Text('Feedback Type', style: kTextSemiBold()),
              SizedBox(height: 8.h),
              DropdownButtonFormField<String>(
                initialValue: _feedbackType,
                items: _feedbackTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.replaceAll('_', ' ').toUpperCase(), style: kTextNormal()),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _feedbackType = value!),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF7F8FC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                ),
              ),
              SizedBox(height: 24.h),
              Text('Feedback Description', style: kTextSemiBold()),
              SizedBox(height: 8.h),
              CustomTextField(
                controller: _feedbackTextCtrl,
                hintText: 'Describe your experience...',
                maxLines: 4,
                backgroundColor: const Color(0xFFF7F8FC),
                borderRadius: 12,
              ),
              SizedBox(height: 32.h),
              BlocBuilder<UserFeedbackBloc, UserFeedbackState>(
                builder: (context, state) {
                  final isLoading = state is UserFeedbackSubmitLoading;
                  return CustomButton(
                    onPressed: isLoading || _rating == 0 || _feedbackTextCtrl.text.isEmpty
                        ? null
                        : () {
                            context.read<UserFeedbackBloc>().add(
                                  SubmitUserFeedback(
                                    rating: _rating,
                                    feedbackType: _feedbackType,
                                    feedbackText: _feedbackTextCtrl.text,
                                  ),
                                );
                          },
                    title: isLoading ? 'Submitting...' : (widget.existingFeedback != null ? 'Update Feedback' : 'Submit Feedback'),
                    isLoading: isLoading,
                    backgroundColor: kPrimaryColor,
                    textColor: Colors.white,
                    width: double.infinity,
                    height: 50.h,
                    borderRadius: BorderRadius.circular(12.r),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
