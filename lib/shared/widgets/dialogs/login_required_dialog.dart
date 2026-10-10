import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../features/auth/login/bloc/auth_bloc.dart';

class LoginRequiredDialog extends StatelessWidget {
  final String title;
  final String message;

  const LoginRequiredDialog({
    super.key,
    this.title = 'Login Required',
    this.message = 'Please login to access this feature and manage your healthcare services.',
  });

  static Future<bool> show(BuildContext context, {String? title, String? message}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => LoginRequiredDialog(
        title: title ?? 'Login Required',
        message: message ?? 'Please login to access this feature and manage your healthcare services.',
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: kBlackColor.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_person_rounded,
                color: kPrimaryColor,
                size: 40.w,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              title,
              style: kHeadingSmall(color: kTextPrimaryColor),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              message,
              style: kTextMedium(color: kTextSecondaryColor),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        side: BorderSide(color: kGreyColor3),
                      ),
                    ),
                    child: Text(
                      'Later',
                      style: kTextMedium(color: kGreyColor6),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, true);
                      context.read<AuthBloc>().add(LogoutRequested());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      foregroundColor: kWhiteColor,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Login Now',
                      style: kTextBold(color: kWhiteColor),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
