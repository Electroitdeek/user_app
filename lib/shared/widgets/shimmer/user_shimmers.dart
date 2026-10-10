import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import 'provider_shimmers.dart';

class UserHomeShimmer extends StatelessWidget {
  const UserHomeShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header shimmer is usually dynamic, but let's shimmer the content
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              children: [
                SizedBox(height: 8.h),
                ShimmerBox(height: 48.h, borderRadius: 12), // Search Bar
                SizedBox(height: 16.h),
                const BannerShimmer(), // Emergency Banner
                SizedBox(height: 12.h),
                const BannerShimmer(), // Book Service Banner
                SizedBox(height: 24.h),
                 _SectionShimmer(titleWidth: 150.w, child: BookingCardShimmer()), // Active Section
                SizedBox(height: 24.h),
                 _SectionShimmer(titleWidth: 120.w, child: BookingCardShimmer()), // Upcoming Section
                SizedBox(height: 24.h),
                _SectionShimmer(titleWidth: 130.w, child: ServicesGridShimmer()), // Services Grid
                SizedBox(height: 24.h),
                 _SectionShimmer(titleWidth: 140.w, child: BookingCardShimmer()), // Recent Section
                SizedBox(height: 40.h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ServicesGridShimmer extends StatelessWidget {
  const ServicesGridShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12.h,
        crossAxisSpacing: 12.w,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (_, _) => const ServiceCardShimmer(),
    );
  }
}

class ServiceCardShimmer extends StatelessWidget {
  const ServiceCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade50,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Placeholder
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                ),
              ),
            ),
            // Info Placeholder
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 100.w,
                    height: 14.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Container(
                        width: 12.w,
                        height: 12.w,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      ),
                      SizedBox(width: 4.w),
                      Container(
                        width: 60.w,
                        height: 10.h,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3.r),
                        ),
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
}

class _SectionShimmer extends StatelessWidget {
  final double titleWidth;
  final Widget child;

  const _SectionShimmer({required this.titleWidth, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerBox(width: titleWidth, height: 18.h, borderRadius: 4),
        SizedBox(height: 12.h),
        child,
      ],
    );
  }
}

class BannerShimmer extends StatelessWidget {
  const BannerShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1),
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade50,
        child: Row(
          children: [
            Container(
              width: 68.w,
              height: 68.w,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 140.w,
                    height: 18.h,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    width: 180.w,
                    height: 14.h,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BookingCardShimmer extends StatelessWidget {
  const BookingCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFEDF0F7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade200,
          highlightColor: Colors.grey.shade50,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent strip
                Container(width: 4.w, color: Colors.white),
                // Card content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 10.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: icon + name + pills
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44.r,
                              height: 44.r,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 140.w,
                                    height: 15.h,
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                                  ),
                                  SizedBox(height: 8.h),
                                  // Status pill + type badge
                                  Row(
                                    children: [
                                      Container(
                                        width: 80.w,
                                        height: 22.h,
                                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6.r)),
                                      ),
                                      SizedBox(width: 6.w),
                                      Container(
                                        width: 55.w,
                                        height: 18.h,
                                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5.r)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        // Body block (mimics state body container)
                        Container(
                          width: double.infinity,
                          height: 70.h,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                        SizedBox(height: 10.h),
                        // Footer: "View Details" placeholder
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              width: 75.w,
                              height: 11.h,
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileShimmer extends StatelessWidget {
  const ProfileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          SizedBox(height: 20.h),
          ShimmerBox(width: 100.h, height: 100.h, borderRadius: 50),
          SizedBox(height: 16.h),
          ShimmerBox(width: 150.w, height: 20.h),
          SizedBox(height: 8.h),
          ShimmerBox(width: 200.w, height: 14.h),
          SizedBox(height: 32.h),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            separatorBuilder: (_, _) => SizedBox(height: 12.h),
            itemBuilder: (_, _) => ShimmerBox(height: 60.h, borderRadius: 12),
          ),
        ],
      ),
    );
  }
}
class BookingHistoryShimmer extends StatelessWidget {
  const BookingHistoryShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(16.w),
      itemCount: 5,
      separatorBuilder: (_, _) => SizedBox(height: 4.h),
      itemBuilder: (_, _) => const BookingCardShimmer(),
    );
  }
}

class WalletShimmer extends StatelessWidget {
  const WalletShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          ShimmerBox(height: 140.h, borderRadius: 20), // Balance Card
          SizedBox(height: 16.h),
          ShimmerBox(height: 140.h, borderRadius: 20), // Bonus Card
          SizedBox(height: 24.h),
          Row(
            children: [
              ShimmerBox(width: 100.w, height: 24.h), // History Title
            ],
          ),
          SizedBox(height: 16.h),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 8,
            separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
            itemBuilder: (_, _) => Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 180.w, height: 18.h),
                        SizedBox(height: 10.h),
                        ShimmerBox(width: 120.w, height: 14.h),
                      ],
                    ),
                  ),
                  ShimmerBox(width: 70.w, height: 18.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HealthRecordShimmer extends StatelessWidget {
  const HealthRecordShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Member Switcher Shimmer
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: SizedBox(
              height: 100.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                itemCount: 5,
                separatorBuilder: (_, _) => SizedBox(width: 12.w),
                itemBuilder: (_, _) => Column(
                  children: [
                    ShimmerBox(width: 56.w, height: 56.w, borderRadius: 28),
                    SizedBox(height: 8.h),
                    ShimmerBox(width: 40.w, height: 10.h),
                  ],
                ),
              ),
            ),
          ),
          // Filter Bar Shimmer
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: SizedBox(
              height: 40.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 4,
                separatorBuilder: (_, _) => SizedBox(width: 12.w),
                itemBuilder: (_, _) => ShimmerBox(width: 80.w, height: 32.h, borderRadius: 20),
              ),
            ),
          ),
          SizedBox(height: 24.h),
          // Records Shimmer
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: 3,
            separatorBuilder: (_, _) => SizedBox(height: 16.h),
            itemBuilder: (_, _) => ShimmerBox(height: 180.h, borderRadius: 24),
          ),
        ],
      ),
    );
  }
}
