import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../di/locator.dart';
import '../../home/view/search_address_page.dart';
import '../bloc/selected_address_provider.dart';
import '../bloc/user_address_bloc.dart';
import '../model/user_address_model.dart';

class AddressSelectionBottomSheet extends StatelessWidget {
  final String? parentRoute;
  const AddressSelectionBottomSheet({super.key, this.parentRoute});

  static Future<void> show(BuildContext context, {String? parentRoute}) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      routeSettings: const RouteSettings(name: AppRoutes.addressSelectionSheet),
      builder: (_) => AddressSelectionBottomSheet(parentRoute: parentRoute),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UserAddressBloc(locator())..add(LoadAddresses()),
      child: _BottomSheetBody(parentRoute: parentRoute),
    );
  }
}

class _BottomSheetBody extends ConsumerWidget {
  final String? parentRoute;
  const _BottomSheetBody({this.parentRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedAddress = ref.watch(selectedAddressProvider);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: EdgeInsets.only(top: 12.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(10)),
              ),
            ),

            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 12.w, 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text('Select Service Address', style: kTextBold2(color: kTextPrimaryColor))),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: kTextPrimaryColor, size: 24.sp),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Add New Address Button
            InkWell(
              onTap: () async {
                await AppNavigator.push(const SearchAddressPage(hideSavedAddresses: true, forAddressBook: true));
                // Refresh list when returning — a new address may have been added.
                if (context.mounted) {
                  context.read<UserAddressBloc>().add(LoadAddresses());
                }
              },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(Icons.add_location_alt_rounded, color: kPrimaryColor, size: 20.sp),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(child: Text('Add a new address', style: kTextSemiBold(color: kPrimaryColor))),
                    SizedBox(width: 4.w),
                    Icon(Icons.chevron_right_rounded, color: kPrimaryColor, size: 20.sp),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),

            // List of Addresses
            Expanded(
              child: BlocBuilder<UserAddressBloc, UserAddressState>(
                builder: (context, state) {
                  if (state is UserAddressLoading || state is UserAddressInitial) {
                    return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                  }

                  if (state is UserAddressError) {
                    return _ErrorStateView(message: state.message);
                  }

                  final addresses = switch (state) {
                    UserAddressLoaded(:final addresses) => addresses,
                    UserAddressActionSuccess(:final addresses) => addresses,
                    UserAddressActionFailure(:final addresses) => addresses,
                    _ => <UserAddressModel>[],
                  };
                  if (addresses.isEmpty) {
                    return const _EmptyStateView();
                  }

                  return ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                    itemCount: addresses.length,
                    separatorBuilder: (_, _) => SizedBox(height: 12.h),
                    itemBuilder: (context, i) {
                      final address = addresses[i];
                      final isSelected = selectedAddress?.id == address.id;
                      return _AddressCard(
                        address: address,
                        isSelected: isSelected,
                        onTap: () {
                          ref.read(selectedAddressProvider.notifier).selectAddress(address);
                          Navigator.of(context).pop();
                        },
                      );
                    },
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

class _AddressCard extends StatelessWidget {
  final UserAddressModel address;
  final bool isSelected;
  final VoidCallback onTap;

  const _AddressCard({required this.address, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor.withValues(alpha: 0.04) : kWhiteColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: isSelected ? kPrimaryColor : kBorderColor, width: isSelected ? 1.5 : 1),
          boxShadow: [if (isSelected) BoxShadow(color: kPrimaryColor.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: (isSelected ? kPrimaryColor : kGreyColor).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                address.addressType == 'home'
                    ? Icons.home_rounded
                    : address.addressType == 'work'
                    ? Icons.work_rounded
                    : Icons.location_on_rounded,
                color: isSelected ? kPrimaryColor : kTextSecondaryColor,
                size: 24.sp,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        (address.addressType ?? 'OTHER').toUpperCase(),
                        style: kTextBold(
                          color: isSelected ? kPrimaryColor.withValues(alpha: 0.7) : kTextHintColor,
                        ).copyWith(fontSize: 10.sp, letterSpacing: 0.5),
                      ),
                      if (address.isDefault) ...[
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(color: kSuccessColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4.r)),
                          child: Text(
                            'DEFAULT',
                            style: kTextBold(color: kSuccessColor).copyWith(fontSize: 8.sp),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '${address.area ?? ''}${address.area != null && address.city != null ? ", " : ""}${address.city ?? ''}',
                    style: kTextBold(color: isSelected ? kPrimaryColor : kTextPrimaryColor).copyWith(fontSize: 15.sp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    address.displayAddress,
                    style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 11.sp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: kPrimaryColor, size: 24.sp)
            else
              Icon(Icons.circle_outlined, color: kBorderColor, size: 24.sp),
          ],
        ),
      ),
    );
  }
}

class _ErrorStateView extends StatelessWidget {
  final String message;
  const _ErrorStateView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: kErrorColor, size: 48.sp),
            SizedBox(height: 16.h),
            Text('Oops! Something went wrong', style: kTextBold1(), textAlign: TextAlign.center),
            SizedBox(height: 8.h),
            Text(
              message,
              style: kTextNormal(color: kTextSecondaryColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateView extends StatelessWidget {
  const _EmptyStateView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_off_rounded, color: kTextHintColor, size: 48.sp),
          SizedBox(height: 16.h),
          Text('No addresses found', style: kTextBold1(color: kTextSecondaryColor)),
          SizedBox(height: 4.h),
          Text('Add an address to see it here', style: kTextNormal(color: kTextHintColor)),
        ],
      ),
    );
  }
}
