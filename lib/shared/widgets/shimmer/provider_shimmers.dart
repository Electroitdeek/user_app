import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsets? margin;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: Container(
        width: width ?? double.infinity,
        height: height ?? 20.h,
        margin: margin,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius.r),
        ),
      ),
    );
  }
}

class DashboardShimmer extends StatelessWidget {
  const DashboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 16.h),
          // Top bar shimmer
          Row(
            children: [
              ShimmerBox(width: 44.h, height: 44.h, borderRadius: 22),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 120.w, height: 16.h),
                    SizedBox(height: 6.h),
                    ShimmerBox(width: 80.w, height: 12.h),
                  ],
                ),
              ),
              ShimmerBox(width: 32.h, height: 32.h, borderRadius: 16),
            ],
          ),
          SizedBox(height: 24.h),
          // Availability Card Shimmer
          ShimmerBox(height: 90.h, borderRadius: 18),
          SizedBox(height: 24.h),
          // Recent Request Shimmer
          ShimmerBox(width: 150.w, height: 18.h, margin: EdgeInsets.only(bottom: 12.h)),
          ShimmerBox(height: 120.h, borderRadius: 20),
          SizedBox(height: 24.h),
          // Earnings Section
          ShimmerBox(width: 100.w, height: 18.h, margin: EdgeInsets.only(bottom: 12.h)),
          Row(
            children: [
              Expanded(child: ShimmerBox(height: 80.h, borderRadius: 16)),
              SizedBox(width: 10.w),
              Expanded(child: ShimmerBox(height: 80.h, borderRadius: 16)),
            ],
          ),
          SizedBox(height: 24.h),
          // Booking Overview
          ShimmerBox(width: 150.w, height: 18.h, margin: EdgeInsets.only(bottom: 12.h)),
          ShimmerBox(height: 180.h, borderRadius: 20),
          SizedBox(height: 40.h),
        ],
      ),
    );
  }
}

class RequestListShimmer extends StatelessWidget {
  const RequestListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.all(16.w),
      itemCount: 6,
      separatorBuilder: (_, _) => SizedBox(height: 12.h),
      itemBuilder: (context, index) => ShimmerBox(height: 140.h, borderRadius: 14),
    );
  }
}

class AvailabilityShimmer extends StatelessWidget {
  const AvailabilityShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        children: [
          ShimmerBox(height: 100.h, borderRadius: 28),
          SizedBox(height: 24.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              7,
              (_) => ShimmerBox(width: 42.w, height: 70.h, borderRadius: 12),
            ),
          ),
          SizedBox(height: 24.h),
          ShimmerBox(height: 300.h, borderRadius: 32),
          SizedBox(height: 24.h),
          ShimmerBox(height: 150.h, borderRadius: 24),
        ],
      ),
    );
  }
}
class EarningsListShimmer extends StatelessWidget {
  const EarningsListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.all(16.w),
      itemCount: 6,
      separatorBuilder: (_, _) => SizedBox(height: 12.h),
      itemBuilder: (_, _) => Column(
        children: [
          ShimmerBox(height: 180.h, borderRadius: 14),
        ],
      ),
    );
  }
}
