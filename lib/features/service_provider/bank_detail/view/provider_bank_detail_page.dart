import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:adhisaat_health_care/core/navigation/app_routes.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/data/models/provider_models/bank_detail_model.dart';
import 'package:adhisaat_health_care/data/repositories/provider_repository.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/features/service_provider/bank_detail/bloc/provider_bank_detail_bloc.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/widgets/common/custom_refresh_indicator.dart';

class ProviderBankDetailPage extends StatelessWidget {
  const ProviderBankDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProviderBankDetailBloc(locator<ProviderRepository>())..add(FetchBankDetail()),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: CustomAppBar(
          title: 'Bank Details',
          actions: [
            BlocBuilder<ProviderBankDetailBloc, ProviderBankDetailState>(
              builder: (context, state) {
                if (state is BankDetailLoaded) {
                  return IconButton(
                    icon: const Icon(Icons.edit_rounded, color: kPrimaryColor),
                    onPressed: () async {
                      final result = await AppNavigator.to(
                        AppRoutes.providerBankDetailAddEdit,
                        arguments: state.bankDetail,
                      );
                      if (result == true && context.mounted) {
                        context.read<ProviderBankDetailBloc>().add(FetchBankDetail());
                      }
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        body: BlocBuilder<ProviderBankDetailBloc, ProviderBankDetailState>(
          builder: (context, state) {
            if (state is BankDetailLoading) {
              return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
            }
            if (state is BankDetailError) {
              return _buildErrorState(context, state.message);
            }
            if (state is BankDetailEmpty) {
              return _buildEmptyState(context);
            }
            if (state is BankDetailLoaded) {
              return _buildBankDetailsContent(context, state.bankDetail);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildBankDetailsContent(BuildContext context, BankDetail bank) {
    return CustomRefreshIndicator(
      onRefresh: () async => context.read<ProviderBankDetailBloc>().add(FetchBankDetail()),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            _buildBankCard(bank),
            SizedBox(height: 20.h),
            _buildInfoSection(bank),
          ],
        ),
      ),
    );
  }

  Widget _buildBankCard(BankDetail bank) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kPrimaryColor, Color(0xFF6A5AE0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.r),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: CircleAvatar(radius: 60, backgroundColor: Colors.white.withValues(alpha: 0.05)),
            ),
            Positioned(
              left: -10,
              bottom: -10,
              child: CircleAvatar(radius: 40, backgroundColor: Colors.white.withValues(alpha: 0.05)),
            ),
            Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: Icon(Icons.account_balance_rounded, color: Colors.white, size: 24.sp),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BANK NAME',
                              style: kTextNormal0().copyWith(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 9.sp,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              bank.bankName.toUpperCase(),
                              style: kTextBold1().copyWith(
                                color: Colors.white,
                                fontSize: 13.sp,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (bank.isVerified) ...[
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, color: const Color(0xFF10B981), size: 12.sp),
                              SizedBox(width: 4.w),
                              Text(
                                'VERIFIED',
                                style: kTextBold0().copyWith(
                                  color: const Color(0xFF10B981),
                                  fontSize: 9.sp,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 18.h),
                  Text(
                    'ACCOUNT NUMBER',
                    style: kTextBold().copyWith(color: Colors.white.withValues(alpha: 0.8), fontSize: 9.sp),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    bank.accountNumber,
                    style: kTextBold2().copyWith(color: Colors.white, fontSize: 16.sp, letterSpacing: 1.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 18.h),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ACCOUNT HOLDER',
                        style: kTextBold().copyWith(color: Colors.white.withValues(alpha: 0.8), fontSize: 9.sp),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        bank.accountHolderName.toUpperCase(),
                        style: kTextSemiBold1().copyWith(color: Colors.white, fontSize: 13.sp, letterSpacing: 1.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(BankDetail bank) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(icon: Icons.pin_rounded, label: 'IFSC Code', value: bank.ifscCode, color: kPrimaryColor),
          _buildInfoRow(
            icon: Icons.location_on_rounded,
            label: 'Branch Name',
            value: bank.branchName,
            color: const Color(0xFFF59E0B),
          ),
          _buildInfoRow(
            icon: Icons.category_rounded,
            label: 'Account Type',
            value: bank.accountType.toUpperCase(),
            color: const Color(0xFF8B5CF6),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isLast = false,
  }) {
    if (value.isEmpty) return SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, color: color, size: 20.sp),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: kTextNormal0().copyWith(color: Colors.grey[500], fontSize: 11.sp),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      value,
                      style: kTextSemiBold1().copyWith(fontSize: 14.sp, color: const Color(0xFF1E293B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, indent: 64.w, endIndent: 20.w),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.05), shape: BoxShape.circle),
              child: Icon(Icons.account_balance_outlined, size: 64, color: kPrimaryColor.withValues(alpha: 0.3)),
            ),
            const SizedBox(height: 32),
            Text('No Bank Details', style: kTextBold2()),
            const SizedBox(height: 12),
            Text(
              'Your bank details are missing. Please add your bank details for payment processing.',
              style: kTextNormal1().copyWith(color: Colors.grey[600], height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await AppNavigator.to(AppRoutes.providerBankDetailAddEdit);
                  if (result == true && context.mounted) {
                    context.read<ProviderBankDetailBloc>().add(FetchBankDetail());
                  }
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Bank Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.05), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
            ),
            const SizedBox(height: 24),
            Text('Something went wrong', style: kTextBold1()),
            const SizedBox(height: 12),
            Text(
              error,
              style: kTextNormal0().copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.read<ProviderBankDetailBloc>().add(FetchBankDetail()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
