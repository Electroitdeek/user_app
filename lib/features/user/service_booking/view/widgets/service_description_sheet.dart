import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../shared/widgets/common/app_cached_image.dart';

/// Bottom sheet showing the full (HTML) description of a service.
///
/// Backend stores rich text (`<p>`, `<h3>`, `<ul><li>`, …) — rendered with
/// [HtmlWidget] so any markup the API sends is displayed correctly.
void showServiceDescriptionSheet(
  BuildContext context, {
  required String name,
  String? iconUrl,
  IconData? fallbackIcon,
  required String? htmlDescription,
}) {
  showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: kWhiteColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.only(topLeft: Radius.circular(24.r), topRight: Radius.circular(24.r)),
    ),
    builder: (ctx) {
      final html = htmlDescription?.trim() ?? '';
      return DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx2, scrollController) => SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: EdgeInsets.only(top: 12.h, bottom: 4.h),
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(2.r)),
                ),
              ),
              // Header
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 12.w, 12.h),
                child: Row(
                  children: [
                    Container(
                      width: 44.w,
                      height: 44.w,
                      decoration: BoxDecoration(
                        color: kAccentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: iconUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10.r),
                              child: AppCachedImage(
                                imageUrl: iconUrl,
                                fit: BoxFit.cover,
                                errorWidgetBuilder: Icon(
                                  fallbackIcon ?? Icons.medical_services_rounded,
                                  color: kPrimaryColor,
                                  size: 22.sp,
                                ),
                              ),
                            )
                          : Icon(
                              fallbackIcon ?? Icons.medical_services_rounded,
                              color: kPrimaryColor,
                              size: 22.sp,
                            ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        name,
                        style: kTextBold1(color: kPrimaryColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Padding(
                        padding: EdgeInsets.all(8.w),
                        child: Icon(Icons.close, color: kTextSecondaryColor, size: 22.sp),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: kBorderColor, height: 1),
              // Body
              Expanded(
                child: html.isEmpty
                    ? Center(
                        child: Text('No description available', style: kTextNormal0(color: kTextHintColor)),
                      )
                    : SingleChildScrollView(
                        controller: scrollController,
                        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
                        child: HtmlWidget(
                          html,
                          textStyle: kTextNormal0(
                            color: kTextSecondaryColor,
                          ).copyWith(fontSize: 13.sp, height: 1.5),
                          customStylesBuilder: (element) {
                            switch (element.localName) {
                              case 'h1':
                              case 'h2':
                              case 'h3':
                              case 'h4':
                                return {'color': '#123B61', 'font-size': '15px', 'margin': '14px 0 6px'};
                              case 'li':
                                return {'margin': '0 0 8px'};
                              case 'p':
                                return {'margin': '0 0 10px'};
                            }
                            return null;
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
