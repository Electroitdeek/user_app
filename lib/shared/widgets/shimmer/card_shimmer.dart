import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

class ListShimmer extends StatelessWidget {
  final int itemCount;

  const ListShimmer({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: Shimmer.fromColors(
            baseColor: const Color(0xFFECECEC),
            highlightColor: const Color(0xFFF4F4F4),
            child: const _NotifShimmerCard(),
          ),
        );
      },
    );
  }
}

class _NotifShimmerCard extends StatelessWidget {
  const _NotifShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFEEEEEE), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 2.h),
                Container(
                  height: 14.h,
                  width: 140.w,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6.r)),
                ),
                SizedBox(height: 8.h),
                Container(
                  height: 11.h,
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6.r)),
                ),
                SizedBox(height: 5.h),
                Container(
                  height: 11.h,
                  width: 160.w,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6.r)),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                height: 10.h,
                width: 38.w,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
