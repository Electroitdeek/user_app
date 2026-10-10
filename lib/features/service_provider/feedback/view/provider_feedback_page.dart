import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:adhisaat_health_care/shared/widgets/common/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/theme/app_edge_insets.dart';
import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import '../bloc/feedback_bloc.dart';
import '../data/model/feedback_model.dart';
import './add_feedback_bottom_sheet.dart';

class ProviderFeedbackPage extends StatelessWidget {
  const ProviderFeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: const CustomAppBar(title: 'Feedback & Reviews'),
      floatingActionButton: BlocBuilder<FeedbackBloc, FeedbackState>(
        builder: (context, state) {
          final feedback = state is FeedbackLoaded ? state.feedback : null;
          return FloatingActionButton.extended(
            onPressed: () => showAddFeedbackBottomSheet(
              context,
              context.read<FeedbackBloc>(),
              existingFeedback: feedback,
            ),
            backgroundColor: kPrimaryColor,
            icon: Icon(feedback != null ? Icons.edit_rounded : Icons.add, color: Colors.white),
            label: Text(feedback != null ? 'Edit Feedback' : 'Add Feedback', style: kTextSemiBold(color: Colors.white)),
          );
        },
      ),
      body: BlocBuilder<FeedbackBloc, FeedbackState>(
        builder: (context, state) {
          if (state is FeedbackLoading) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          } else if (state is FeedbackError) {
            return _buildErrorState(context, state.message);
          } else if (state is FeedbackLoaded) {
            final feedback = state.feedback;
            if (feedback == null) {
              return _buildEmptyState();
            }
            return CustomRefreshIndicator(
              onRefresh: () async {
                context.read<FeedbackBloc>().add(FetchFeedback());
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
            Icons.chat_bubble_outline_rounded,
            size: 64.sp,
            color: kTextSecondaryColor.withValues(alpha: 0.3),
          ),
          SizedBox(height: 16.h),
          Text(
            'No feedback yet',
            style: kTextSemiBold1(color: kTextSecondaryColor),
          ),
          SizedBox(height: 8.h),
          Text(
            'Keep up the good work! Feedbacks from users\nwill appear here.',
            textAlign: TextAlign.center,
            style: kTextNormal0(color: kTextSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: AppPadding.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48.sp, color: kErrorColor),
            SizedBox(height: 16.h),
            Text('Failed to load feedback', style: kTextBold1()),
            SizedBox(height: 8.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: kTextNormal0(color: kTextSecondaryColor),
            ),
            SizedBox(height: 24.h),
            ElevatedButton(
              onPressed: () => context.read<FeedbackBloc>().add(FetchFeedback()),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Retry', style: kTextSemiBold(color: Colors.white)),
            ),
          ],
        ),
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
