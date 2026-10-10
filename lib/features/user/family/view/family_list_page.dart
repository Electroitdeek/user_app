import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/features/user/family/bloc/family_event.dart';
import 'package:adhisaat_health_care/features/user/family/bloc/family_state.dart';
import 'package:adhisaat_health_care/features/user/family/data/family_repository.dart';
import 'package:adhisaat_health_care/shared/widgets/buttons/custom_button.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_edge_insets.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/screen_dimensions.dart';
import '../../../../core/utils/message_service.dart';
import '../../../../shared/widgets/dialogs/dialog_helpers.dart';
import '../bloc/family_bloc.dart';
import '../model/family_member_model.dart';

class FamilyListPage extends StatelessWidget {
  const FamilyListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FamilyBloc>(create: (_) => FamilyBloc(locator<FamilyRepository>())..add(LoadFamilyMembers()), child: const _FamilyListBody());
  }
}

class _FamilyListBody extends StatelessWidget {
  const _FamilyListBody();

  Future<void> _addOrEdit(BuildContext context, {FamilyMemberModel? existing}) async {
    final result = await Navigator.of(context).pushNamed(AppRoutes.familyAddEdit, arguments: existing);
    if (result == true && context.mounted) {
      context.read<FamilyBloc>().add(LoadFamilyMembers());
    }
  }

  void _confirmDelete(BuildContext context, FamilyMemberModel member) async {
    final result = await DialogHelper.showConfirmation(
      title: 'Remove Member',
      message: 'Are you sure you want to remove ${member.fullName}? This will disconnect their records from your profile.',
      confirmText: 'Remove',
      isDangerous: true,
    );

    if (result == true && context.mounted) {
      if (member.id != null) {
        context.read<FamilyBloc>().add(DeleteFamilyMember(member.id!));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhiteColor,
      appBar: CustomAppBar(
        title: 'Family Members',
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: kBorderColor, height: 1),
        ),
      ),
      body: SafeArea(
        child: BlocConsumer<FamilyBloc, FamilyState>(
          listener: (context, state) {
            if (state is FamilyActionSuccess) {
              MessageService.showSuccess(state.message);
            } else if (state is FamilyError) {
              MessageService.showError(state.message);
            }
          },
          builder: (context, state) {
            if (state is FamilyLoading) {
              return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
            }

            List<FamilyMemberModel> members = [];
            if (state is FamilyLoaded) {
              members = state.members;
            } else if (state is FamilyActionSuccess) {
              members = state.members;
            } else if (state is FamilyError) {
              return _ErrorView(
                message: state.message,
                onRetry: () {
                  context.read<FamilyBloc>().add(LoadFamilyMembers());
                },
              );
            }

            if (members.isEmpty) {
              return _EmptyView(onAdd: () => _addOrEdit(context));
            }

            return ListView.separated(
              padding: AppPadding.m,
              itemCount: members.length,
              separatorBuilder: (context, index) => AppSpacing.mVertical,
              itemBuilder: (context, index) {
                final member = members[index];
                return _MemberCard(
                  member: member,
                  onEdit: () => _addOrEdit(context, existing: member),
                  onDelete: () => _confirmDelete(context, member),
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: BlocBuilder<FamilyBloc, FamilyState>(
        builder: (context, state) {
          List<FamilyMemberModel> members = [];
          if (state is FamilyLoaded) members = state.members;
          if (state is FamilyActionSuccess) members = state.members;

          if (members.isEmpty && state is! FamilyLoading) return const SizedBox.shrink();

          return Container(
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: kWhiteColor,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, -4))],
            ),
            child: CustomButton(
              onPressed: () => _addOrEdit(context),
              title: 'Add Family Member',
              iconData: Icons.add_rounded,
              width: double.infinity,
              borderRadius: BorderRadius.circular(30.r),
            ),
          );
        },
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final FamilyMemberModel member;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MemberCard({required this.member, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(member.fullName);
    final color = _getRelationColor(member.relationship.toLowerCase());

    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFEEEFF1), width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Color accent strip on left
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4.w,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20.r), bottomLeft: Radius.circular(20.r)),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onEdit,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w + 4.w, 16.h, 16.w, 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Member Avatar
                        Container(
                          width: 52.w,
                          height: 52.w,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: kTextBold(color: color).copyWith(fontSize: 17.sp, letterSpacing: 0.5),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member.fullName,
                                style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 16.sp),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 6.h),
                              Wrap(
                                spacing: 6.w,
                                runSpacing: 4.h,
                                children: [
                                  _PillBadge(label: member.relationship, color: color),
                                  if (member.bloodGroup != null && member.bloodGroup!.isNotEmpty)
                                    _PillBadge(label: member.bloodGroup!, color: kSecondaryColor),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        // Edit + Delete buttons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ActionButton(icon: Icons.edit_outlined, label: 'EDIT', color: kSecondaryColor, onTap: onEdit),
                            SizedBox(width: 8.w),
                            _ActionButton(icon: Icons.delete_outline_rounded, label: 'REMOVE', color: kErrorColor, onTap: onDelete),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 14.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      decoration: BoxDecoration(color: const Color(0xFFF7F8FA), borderRadius: BorderRadius.circular(12.r)),
                      child: Wrap(
                        spacing: 16.w,
                        runSpacing: 8.h,
                        children: [
                          _InfoItem(icon: Icons.cake_rounded, value: AppDateFormatter.dateFromApi(member.dateOfBirth)),
                          _InfoItem(icon: Icons.person_outline_rounded, value: member.gender.capitalizeFirst()),
                          if (member.mobileNumber?.isNotEmpty == true) _InfoItem(icon: Icons.phone_android_rounded, value: member.mobileNumber!),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    List<String> parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Color _getRelationColor(String relation) {
    if (relation.contains('son') || relation.contains('daughter')) return const Color(0xFF6C63FF);
    if (relation.contains('spouse') || relation.contains('wife') || relation.contains('husband')) return const Color(0xFF00BFA5);
    if (relation.contains('parent') || relation.contains('father') || relation.contains('mother')) return kPrimaryColor;
    return const Color(0xFF5C6BC0);
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
            ),
            child: Icon(icon, color: color.withValues(alpha: 0.75), size: 18.sp),
          ),
          SizedBox(height: 3.h),
          Text(
            label,
            style: kTextBold(color: color.withValues(alpha: 0.7)).copyWith(fontSize: 8.sp),
          ),
        ],
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _PillBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20.r)),
      child: Text(
        label.toUpperCase(),
        style: kTextBold(color: color).copyWith(fontSize: 9.sp, letterSpacing: 0.5),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String value;

  const _InfoItem({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16.sp, color: kTextHintColor),
        AppSpacing.sHorizontal,
        Text(
          value,
          style: kTextMedium(color: kTextSecondaryColor).copyWith(fontSize: 13.sp),
        ),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: AppPadding.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.group_outlined, size: 64, color: kPrimaryColor.withValues(alpha: 0.5)),
              AppSpacing.lVertical,
              Text('No Family Members', style: kTextSemiBold2(), textAlign: TextAlign.center),
              AppSpacing.sVertical,
              Text(
                'Add your family members to easily book services for them.',
                style: kTextNormal(color: kTextSecondaryColor),
                textAlign: TextAlign.center,
              ),
              AppSpacing.xxlVertical,
              CustomButton(onPressed: onAdd, title: 'Add Family Member', iconData: Icons.add_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: AppPadding.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.error_outline_rounded, size: 64, color: kErrorColor),
              AppSpacing.lVertical,
              Text('Oops!', style: kTextSemiBold2(), textAlign: TextAlign.center),
              AppSpacing.sVertical,
              Text(
                message,
                style: kTextNormal(color: kTextSecondaryColor),
                textAlign: TextAlign.center,
              ),
              AppSpacing.xxxlVertical,
              CustomButton(onPressed: onRetry, title: 'Try Again', iconData: Icons.refresh_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
