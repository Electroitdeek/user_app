import 'dart:io';

import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_edge_insets.dart';
import 'package:adhisaat_health_care/core/theme/screen_dimensions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/navigation/app_navigator.dart';
import '../../../core/theme/app_text_styles.dart';

class ChooseFileBottomSheet extends StatelessWidget {
  final bool showFiles;
  final bool showCamera;
  final bool showGallery;

  const ChooseFileBottomSheet({super.key, this.showFiles = true, this.showCamera = true, this.showGallery = true});

  static Future<File?>? show({bool showFiles = true, bool showCamera = true, bool showGallery = true}) async {
    return await showModalBottomSheet(
      context: AppNavigator.context!,
      backgroundColor: kWhiteColor,
      barrierColor: kBlackColor.withValues(alpha: 0.5),
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => ChooseFileBottomSheet(showFiles: showFiles, showCamera: showCamera, showGallery: showGallery),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: AppPadding.all(24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(color: kGreyColor4.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
                ),
              ),
              AppSpacing.lVertical,

              Text(
                'Select Source',
                style: kHeadingSmall(color: kTextPrimaryColor).copyWith(fontSize: 18.sp),
              ),
              AppSpacing.sVertical,
              Text(
                'Choose how you want to upload the document',
                style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 13.sp),
              ),
              AppSpacing.xlVertical,

              if (showCamera)
                _ActionTile(
                  icon: Icons.camera_alt_rounded,
                  title: 'Camera',
                  subtitle: 'Capture a photo directly',
                  onTap: () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);

                    if (pickedFile != null && context.mounted) {
                      Navigator.pop(context, File(pickedFile.path));
                    }
                  },
                ),

              if (showGallery) ...[
                if (showCamera) AppSpacing.mVertical,
                _ActionTile(
                  icon: Icons.photo_library_rounded,
                  title: 'Gallery',
                  subtitle: 'Pick from your photo library',
                  onTap: () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

                    if (pickedFile != null && context.mounted) {
                      Navigator.pop(context, File(pickedFile.path));
                    }
                  },
                ),
              ],

              if (showFiles) ...[
                if (showCamera || showGallery) AppSpacing.mVertical,
                _ActionTile(
                  icon: Icons.folder_open_rounded,
                  title: 'Files',
                  subtitle: 'Select PDF or other documents',
                  onTap: () async {
                    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
                    if (result != null && result.files.single.path != null && context.mounted) {
                      Navigator.pop(context, File(result.files.single.path!));
                    }
                  },
                ),
              ],
              AppSpacing.mVertical,
            ],
          ),
        ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: AppPadding.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: kGreyColor4.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: AppPadding.all(12),
              decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.08), shape: BoxShape.circle),
              child: Icon(icon, color: kPrimaryColor, size: 22.sp),
            ),
            AppSpacing.mHorizontal,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: kTextSemiBold(color: kTextPrimaryColor).copyWith(fontSize: 15.sp),
                  ),
                  Text(
                    subtitle,
                    style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: kTextHintColor.withValues(alpha: 0.5), size: 20.sp),
          ],
        ),
      ),
    );
  }
}
