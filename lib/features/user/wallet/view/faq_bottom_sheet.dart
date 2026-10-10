import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/api/api_endpoints.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/di/locator.dart';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class FaqBottomSheet extends StatefulWidget {
  final String category;

  const FaqBottomSheet({super.key, required this.category});

  static Future<void> show(BuildContext context, {required String category}) {
    return showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FaqBottomSheet(category: category),
    );
  }

  @override
  State<FaqBottomSheet> createState() => _FaqBottomSheetState();
}

class _FaqBottomSheetState extends State<FaqBottomSheet> {
  final _api = locator<ApiClient>();
  bool _isLoading = true;
  String? _error;
  List<dynamic> _faqs = [];

  @override
  void initState() {
    super.initState();
    _fetchFaqs();
  }

  Future<void> _fetchFaqs() async {
    try {
      // Because the curl uses --form, we will use POST
      final result = await _api.post(ApiEndpoints.faqs, {
        'category': widget.category,
      });

      final isSuccess = result['success'] == true || result['status'] == true;
      if (isSuccess && result['data'] != null) {
        setState(() {
          _faqs = result['data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = result['message'] ?? 'Failed to load FAQs';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kScaffoldColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        border: Border(bottom: BorderSide(color: kBorderColor)),
      ),
      child: Column(
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            margin: EdgeInsets.only(bottom: 16.h),
            decoration: BoxDecoration(
              color: kGreyColor4,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.help_outline_rounded, color: kPrimaryColor, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'Frequently Asked Questions',
                  style: kTextBold1(),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: kTextPrimaryColor, size: 22.sp),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: kPrimaryColor),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, color: kErrorColor, size: 40.sp),
            SizedBox(height: 12.h),
            Text(_error!, style: kTextMedium(color: kTextSecondaryColor)),
            SizedBox(height: 16.h),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _fetchFaqs();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: TextButton.styleFrom(foregroundColor: kPrimaryColor),
            ),
          ],
        ),
      );
    }

    if (_faqs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.speaker_notes_off_outlined, color: kPrimaryColor.withValues(alpha: 0.5), size: 40.sp),
            ),
            SizedBox(height: 16.h),
            Text('No FAQs Available', style: kTextSemiBold1()),
            SizedBox(height: 8.h),
            Text(
              'There are no frequently asked questions for this category yet.',
              style: kTextNormal(color: kTextSecondaryColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      itemCount: _faqs.length,
      separatorBuilder: (_, _) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        final item = _faqs[index];
        return _FaqTile(
          question: item['question']?.toString() ?? 'Unknown Question',
          answer: item['answer']?.toString() ?? 'No answer provided.',
        );
      },
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: kTextSemiBold(color: kTextPrimaryColor),
        ),
        collapsedIconColor: kPrimaryColor,
        iconColor: kPrimaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        childrenPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
        expandedAlignment: Alignment.centerLeft,
        children: [
          Text(
            answer,
            style: kTextNormal(color: kTextSecondaryColor).copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}
