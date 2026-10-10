import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/common/app_cached_image.dart';

/// One sub-service row: name + optional icon + optional description.
class SubServiceItem {
  final String name;
  final String? imageUrl;
  final String? description;

  const SubServiceItem({required this.name, this.imageUrl, this.description});
}

class SubServicesListSheet extends StatelessWidget {
  final String title;
  final List<SubServiceItem> services;
  final String? imageUrl;
  final String? description;

  const SubServicesListSheet({
    super.key,
    required this.title,
    required this.services,
    this.imageUrl,
    this.description,
  });

  static void showServices(
    BuildContext context, {
    required String title,
    required List<SubServiceItem> services,
    String? imageUrl,
    String? description,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SubServicesListSheet(
        title: title,
        services: services,
        imageUrl: imageUrl,
        description: description,
      ),
    );
  }

  static String? _clean(String? html) {
    if (html == null || html.trim().isEmpty) return null;
    final text = html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    return text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    final cleanDescription = _clean(description);
    final hasDescription = cleanDescription != null;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.78),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                margin: EdgeInsets.only(top: 10.h, bottom: 6.h),
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(2.r)),
              ),
            ),
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 6.h, 12.w, 0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10.r),
                    child: imageUrl != null && imageUrl!.isNotEmpty
                        ? AppCachedImage(imageUrl: imageUrl!, width: 42.w, height: 42.w, fit: BoxFit.cover)
                        : _PlaceholderIcon(title),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: kTextBold2(), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          '${services.length} service${services.length == 1 ? '' : 's'}',
                          style: kTextNormal0(color: kTextSecondaryColor),
                        ),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            // Main service description
            if (hasDescription)
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 0),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: kPrimaryColor.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 15.sp, color: kPrimaryColor),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          cleanDescription,
                          style: kTextNormal0(color: kTextSecondaryColor).copyWith(height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Divider(color: kDividerColor, height: 24.h),
            // Services list
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
                itemCount: services.length,
                separatorBuilder: (_, i) => Divider(color: kDividerColor.withValues(alpha: 0.6), height: 18.h),
                itemBuilder: (_, i) {
                  final s = services[i];
                  final desc = _clean(s.description);
                  final hasDesc = desc != null;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sub-service icon
                      Container(
                        width: 45.w,
                        height: 45.w,
                        padding: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                          color: kAccentColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: kAccentColor.withValues(alpha: 0.15)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.r),
                          child: s.imageUrl != null && s.imageUrl!.isNotEmpty
                              ? AppCachedImage(imageUrl: s.imageUrl!, width: 45.w, height: 45.w, fit: BoxFit.cover)
                              : _PlaceholderIcon(s.name, size: 45.w),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name, style: kTextSemiBold0()),
                            if (hasDesc) ...[
                              SizedBox(height: 2.h),
                              Text(
                                desc,
                                style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 11.5.sp),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderIcon extends StatelessWidget {
  final String title;
  final double size;

  const _PlaceholderIcon(this.title, {this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.w,
      height: size.w,
      decoration: BoxDecoration(
        color: kAccentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Center(
        child: Text(title.isNotEmpty ? title[0].toUpperCase() : 'S', style: kTextBold1(color: kPrimaryColor)),
      ),
    );
  }
}
