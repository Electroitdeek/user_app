import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/theme/app_edge_insets.dart';
import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import '../../../../shared/widgets/common/custom_refresh_indicator.dart';
import '../bloc/user_feedback_bloc.dart';
import '../../../service_provider/feedback/data/model/feedback_model.dart';
import 'user_add_feedback_bottom_sheet.dart';

class AppFeedbackPage extends StatelessWidget {
  const AppFeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: Text('App Feedback', style: kTextBold1()),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: kTextPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: BlocBuilder<UserFeedbackBloc, UserFeedbackState>(
        builder: (context, state) {
          final feedback = state is UserFeedbackLoaded ? state.feedback : null;
          return FloatingActionButton.extended(
            onPressed: () => showUserAddFeedbackBottomSheet(
              context,
              context.read<UserFeedbackBloc>(),
              existingFeedback: feedback,
            ),
            backgroundColor: kPrimaryColor,
            icon: Icon(feedback != null ? Icons.edit_rounded : Icons.add, color: Colors.white),
            label: Text(feedback != null ? 'Edit Feedback' : 'Add Feedback', style: kTextSemiBold(color: Colors.white)),
          );
        },
      ),
      body: BlocBuilder<UserFeedbackBloc, UserFeedbackState>(
        builder: (context, state) {
          if (state is UserFeedbackLoading) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          } else if (state is UserFeedbackError) {
            return _buildErrorState(context, state.message);
          } else if (state is UserFeedbackLoaded) {
            final feedback = state.feedback;
            if (feedback == null) {
              return _buildEmptyState();
            }
            return CustomRefreshIndicator(
              onRefresh: () async {
                context.read<UserFeedbackBloc>().add(FetchUserFeedback());
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppPadding.all(20),
                child: _FullFeedbackView(feedback: feedback),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: 64.sp,
            color: kTextSecondaryColor.withValues(alpha: 0.3),
          ),
          SizedBox(height: 16.h),
          Text(
            'No feedback submitted yet',
            style: kTextSemiBold1(color: kTextSecondaryColor),
          ),
          SizedBox(height: 8.h),
          Text(
            'Share your experience with us to help us improve.',
            textAlign: TextAlign.center,
            style: kTextNormal0(color: kTextSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48.sp, color: kErrorColor),
          SizedBox(height: 16.h),
          Text(message, style: kTextMedium()),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () => context.read<UserFeedbackBloc>().add(FetchUserFeedback()),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _FullFeedbackView extends StatelessWidget {
  final FeedbackModel feedback;

  const _FullFeedbackView({required this.feedback});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: 10.h),
        Container(
          padding: AppPadding.all(24),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24.r),
            boxShadow: [
              BoxShadow(
                color: kPrimaryColor.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'YOUR RATING',
                style: kTextBold0(color: kTextSecondaryColor.withValues(alpha: 0.6)).copyWith(letterSpacing: 1.2),
              ),
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return Icon(
                    index < feedback.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: index < feedback.rating ? Colors.orange : kDividerColor,
                    size: 36.sp,
                  );
                }),
              ),
              SizedBox(height: 8.h),
              Text(
                _getRatingText(feedback.rating),
                style: kTextBold2(color: kPrimaryColor),
              ),
              SizedBox(height: 32.h),
              const Divider(height: 1),
              SizedBox(height: 24.h),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'FEEDBACK TYPE',
                  style: kTextBold0(color: kTextSecondaryColor.withValues(alpha: 0.6)).copyWith(letterSpacing: 1.2),
                ),
              ),
              SizedBox(height: 8.h),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    feedback.feedbackType.replaceAll('_', ' ').toUpperCase(),
                    style: kTextBold0(color: kPrimaryColor),
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'DESCRIPTION',
                  style: kTextBold0(color: kTextSecondaryColor.withValues(alpha: 0.6)).copyWith(letterSpacing: 1.2),
                ),
              ),
              SizedBox(height: 12.h),
              Container(
                width: double.infinity,
                padding: AppPadding.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FC),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Text(
                  feedback.feedbackText,
                  style: kTextNormal1(color: kTextPrimaryColor),
                ),
              ),
              SizedBox(height: 24.h),
              const Divider(height: 1),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.access_time_rounded, size: 14.sp, color: kTextHintColor),
                  SizedBox(width: 6.w),
                  Text(
                    'Submitted on ${AppDateFormatter.dateFromApi(feedback.createdAt)}',
                    style: kTextNormal0(color: kTextHintColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1: return 'Needs Work';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Very Good';
      case 5: return 'Excellent';
      default: return '';
    }
  }
}
