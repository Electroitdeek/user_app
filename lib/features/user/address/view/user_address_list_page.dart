import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/theme/screen_dimensions.dart';
import 'package:adhisaat_health_care/features/user/address/bloc/selected_address_provider.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_edge_insets.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/message_service.dart';
import '../../../../di/locator.dart';
import '../../../../shared/widgets/buttons/custom_button.dart';
import '../../../../shared/widgets/dialogs/dialog_helpers.dart';
import '../../home/view/search_address_page.dart';
import '../bloc/user_address_bloc.dart';
import '../data/user_address_repository.dart';
import '../model/user_address_model.dart';

class UserAddressListPage extends StatelessWidget {
  const UserAddressListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UserAddressBloc>(
      create: (_) => UserAddressBloc(locator<UserAddressRepository>())..add(LoadAddresses()),
      child: const _AddressListBody(),
    );
  }
}

class _AddressListBody extends StatelessWidget {
  const _AddressListBody();

  Future<void> _openSheet(BuildContext context, {UserAddressModel? existing}) async {
    if (existing == null) {
      await AppNavigator.push(const SearchAddressPage(hideSavedAddresses: true, forAddressBook: true));
    } else {
      await Navigator.of(context).pushNamed(AppRoutes.userAddressAddEdit, arguments: existing);
    }

    if (context.mounted) {
      context.read<UserAddressBloc>().add(LoadAddresses());
    }
  }

  Future<void> _onRefresh(BuildContext context) async {
    final bloc = context.read<UserAddressBloc>();
    bloc.add(LoadAddresses());
    // Keep the refresh spinner until the reload settles.
    await bloc.stream.firstWhere((s) => s is! UserAddressLoading);
  }

  void _confirmDelete(BuildContext context, UserAddressModel address) async {
    final result = await DialogHelper.showConfirmation(
      title: 'Delete Address',
      message: 'Are you sure you want to delete this address?',
      confirmText: 'Delete',
      isDangerous: true,
    );

    if (result == true && context.mounted) {
      context.read<UserAddressBloc>().add(DeleteAddress(address.id!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhiteColor,
      appBar: CustomAppBar(title: 'My Addresses', centerTitle: false),
      body: SafeArea(
        child: BlocConsumer<UserAddressBloc, UserAddressState>(
          listener: (context, state) {
            if (state is UserAddressActionSuccess) {
              MessageService.showSuccess(state.message);
            } else if (state is UserAddressActionFailure) {
              DialogHelper.showError(title: 'Cannot Delete Address', message: state.message);
            } else if (state is UserAddressError) {
              MessageService.showError(state.message);
            }
          },
          builder: (context, state) {
            // Loading
            if (state is UserAddressLoading || state is UserAddressInitial) {
              return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
            }

            // Error
            if (state is UserAddressError) {
              return _ErrorView(message: state.message, onRetry: () => context.read<UserAddressBloc>().add(LoadAddresses()));
            }

            // Get addresses from either Loaded or ActionSuccess state
            final addresses = _addressesFrom(state);

            // Empty
            if (addresses.isEmpty) {
              return RefreshIndicator(
                color: kPrimaryColor,
                onRefresh: () => _onRefresh(context),
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: _EmptyView(onAdd: () => _openSheet(context)),
                    ),
                  ),
                ),
              );
            }

            // List
            return RefreshIndicator(
              color: kPrimaryColor,
              onRefresh: () => _onRefresh(context),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppPadding.only(left: 16, right: 16, top: 16, bottom: 110),
                itemCount: addresses.length,
                separatorBuilder: (context, index) => AppSpacing.mVertical,
                itemBuilder: (context, i) {
                  final addr = addresses[i];
                  final canAddressDelete = addresses.length > 1 && !addr.isDefault;
                  return Consumer(
                    builder: (context, ref, _) {
                      return _AddressCard(
                        address: addr,
                        onTap: () {
                          ref.read(selectedAddressProvider.notifier).selectAddress(addr);
                          Navigator.of(context).pop();
                        },
                        onEdit: () => _openSheet(context, existing: addr),
                        onDelete: canAddressDelete ? () => _confirmDelete(context, addr) : null,
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: BlocBuilder<UserAddressBloc, UserAddressState>(
        builder: (context, state) {
          final hasAddresses = _addressesFrom(state).isNotEmpty;
          if (!hasAddresses) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _openSheet(context),
            backgroundColor: kPrimaryColor,
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            icon: const Icon(Icons.add_location_alt_rounded, color: kWhiteColor),
            label: Text('Add New', style: kTextSemiBold(color: kWhiteColor)),
          );
        },
      ),
    );
  }

  List<UserAddressModel> _addressesFrom(UserAddressState state) {
    if (state is UserAddressLoaded) return state.addresses;
    if (state is UserAddressActionSuccess) return state.addresses;
    if (state is UserAddressActionFailure) return state.addresses;
    return [];
  }
}

// ──────────────────────────────────────────────────────────
// Address Card
// ──────────────────────────────────────────────────────────

class _AddressCard extends StatelessWidget {
  final UserAddressModel address;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _AddressCard({required this.address, required this.onTap, required this.onEdit, required this.onDelete});

  IconData get _typeIcon {
    switch (address.addressType?.toLowerCase()) {
      case 'work':
        return Icons.work_rounded;
      case 'other':
        return Icons.place_rounded;
      default:
        return Icons.home_rounded;
    }
  }

  Color get _typeColor {
    switch (address.addressType?.toLowerCase()) {
      case 'work':
        return const Color(0xFF8B5CF6);
      case 'other':
        return const Color(0xFF06B6D4);
      default:
        return kPrimaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: address.isDefault ? kPrimaryColor.withValues(alpha: 0.15) : const Color(0xFFF3F4F6), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: address.isDefault ? kPrimaryColor.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type icon badge
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(color: _typeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12.r)),
                    child: Icon(_typeIcon, color: _typeColor, size: 22.sp),
                  ),
                  SizedBox(width: 14.w),

                  // Address info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              address.addressType != null ? address.addressType![0].toUpperCase() + address.addressType!.substring(1) : 'Address',
                              style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 15.sp),
                            ),
                            if (address.isDefault) ...[
                              SizedBox(width: 8.w),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                decoration: BoxDecoration(color: kSuccessColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20.r)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 4.w,
                                      height: 4.w,
                                      decoration: const BoxDecoration(color: kSuccessColor, shape: BoxShape.circle),
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      'Default',
                                      style: kTextSemiBold0(color: kSuccessColor).copyWith(fontSize: 9.sp),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          address.fullAddress,
                          style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 13.sp, height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (address.city != null || address.state != null) ...[
                          AppSpacing.xsVertical,
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 13, color: kTextHintColor),
                              AppSpacing.xsHorizontal,
                              Text(
                                [address.city, address.state, address.pinCode].where((s) => s != null && s.isNotEmpty).join(', '),
                                style: kTextNormal0(color: kTextHintColor),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Action row
            Divider(height: 1, color: const Color(0xFFF3F4F6)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              child: Row(
                children: [
                  _SubActionBtn(icon: Icons.edit_outlined, label: 'Edit', onTap: onEdit),
                  const Spacer(),
                  if (onDelete != null)
                    _SubActionBtn(icon: Icons.delete_outline_rounded, label: 'Delete', color: kErrorColor.withValues(alpha: 0.7), onTap: onDelete!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SubActionBtn({required this.icon, required this.label, required this.onTap, this.color = kTextSecondaryColor});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ),
      icon: Icon(icon, size: 16.sp, color: color),
      label: Text(label, style: kTextSemiBold0(color: color)),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Empty State
// ──────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppPadding.xl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.06), shape: BoxShape.circle),
              child: Icon(Icons.location_off_rounded, size: 52, color: kPrimaryColor.withValues(alpha: 0.5)),
            ),
            AppSpacing.lVertical,
            Text('No Addresses Saved', style: kTextBold2()),
            AppSpacing.sVertical,
            Text(
              'Add your address to make booking services even faster.',
              style: kTextNormal(color: kTextSecondaryColor),
              textAlign: TextAlign.center,
            ),
            AppSpacing.xxlVertical,
            CustomButton(onPressed: onAdd, title: 'Add Address', iconData: Icons.add_rounded, iconColor: kWhiteColor, backgroundColor: kPrimaryColor),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Error State
// ──────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppPadding.xl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 52, color: kErrorColor.withValues(alpha: 0.6)),
            AppSpacing.lVertical,
            Text('Something went wrong', style: kTextBold2()),
            AppSpacing.sVertical,
            Text(
              message,
              style: kTextNormal(color: kTextSecondaryColor),
              textAlign: TextAlign.center,
              maxLines: 3,
            ),
            AppSpacing.xxxlVertical,
            CustomButton(onPressed: onRetry, title: 'Retry', iconData: Icons.refresh_rounded, iconColor: kWhiteColor, backgroundColor: kPrimaryColor),
          ],
        ),
      ),
    );
  }
}
