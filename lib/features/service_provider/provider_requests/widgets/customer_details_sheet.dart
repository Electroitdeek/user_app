import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/utils/date_utils.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/models/provider_service_request_model.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CustomerDetailsSheet extends StatelessWidget {
  final ProviderServiceRequestModel request;

  const CustomerDetailsSheet({super.key, required this.request});

  static const _navy = Color(0xFF123B61);
  static const _grey = Color(0xFF6B7280);
  static const _greyBorder = Color(0xFFE5E7EB);

  // Format API date string "1997-05-06" → "06 May 1997"
  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    return AppDateFormatter.dateShort(raw);
  }

  int? _age(String? dob) {
    if (dob == null || dob.isEmpty) return null;
    try {
      final d = DateTime.parse(dob);
      final now = DateTime.now();
      int age = now.year - d.year;
      if (now.month < d.month || (now.month == d.month && now.day < d.day)) age--;
      return age;
    } catch (_) {
      return null;
    }
  }

  String _cap(String? s) {
    if (s == null || s.isEmpty) return '—';
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final cp = request.customerProfile;
    final user = cp?.user;
    final fm = request.familyMember;
    final addr = request.customerAddress;

    final patientName = fm?.fullName.isNotEmpty == true ? fm!.fullName : (cp?.fullName ?? user?.name ?? '');
    final bookerName = cp?.fullName ?? user?.name ?? '';
    final isFamilyBooking = fm != null && fm.fullName.isNotEmpty;

    final patientGender = fm?.gender ?? user?.gender;
    final patientDob = fm?.dateOfBirth ?? user?.dateOfBirth;
    final patientAge = _age(patientDob);

    final areaCity = [addr?.area, addr?.city].where((s) => s != null && s.isNotEmpty).join(', ');

    return SafeArea(
      child: Container(
        height: 0.88.sh,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          children: [
            // ── Handle ──
            Container(
              margin: EdgeInsets.symmetric(vertical: 12.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(color: _greyBorder, borderRadius: BorderRadius.circular(2.r)),
            ),

            // ── Header ──
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: _navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(Icons.person_pin_outlined, color: _navy, size: 20.sp),
                  ),
                  SizedBox(width: 12.w),
                  Text('Patient Profile', style: kTextBold2()),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close_rounded, size: 22.sp, color: _grey),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: _greyBorder),

            // ── Content ──
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 32.h),
                children: [
                  // ── Patient avatar + name ──
                  _buildAvatarCard(
                    patientName,
                    patientGender,
                    patientAge,
                    isFamilyBooking,
                    bookerName,
                    fm?.relationship,
                  ),
                  SizedBox(height: 16.h),

                  // ── Patient info ──
                  _buildSection(
                    label: 'Patient Details',
                    icon: Icons.personal_injury_outlined,
                    color: const Color(0xFF1D4ED8),
                    children: [
                      if (patientGender != null) _row(Icons.wc_rounded, 'Gender', _cap(patientGender)),
                      if (patientAge != null) _row(Icons.cake_outlined, 'Age', '$patientAge years'),
                      if (patientDob != null)
                        _row(Icons.calendar_month_outlined, 'Date of Birth', _fmtDate(patientDob)),
                      // if (isFamilyBooking && fm!.relationship != null)
                      //   _row(Icons.family_restroom_rounded, 'Relation to Booker', _cap(fm.relationship)),
                      // if (fm?.mobileNumber?.isNotEmpty == true)
                      //   _row(Icons.phone_rounded, 'Contact', fm!.mobileNumber!),
                    ],
                  ),
                  SizedBox(height: 12.h),

                  // ── Booking info ──
                  _buildSection(
                    label: 'Booking Details',
                    icon: Icons.assignment_outlined,
                    color: _navy,
                    children: [
                      // if (user?.mobileNumber?.isNotEmpty == true)
                      //   _row(Icons.phone_rounded, 'Booked By', user!.mobileNumber!),
                      if (areaCity.isNotEmpty) _row(Icons.location_on_outlined, 'Area', areaCity),
                      _row(Icons.tag_rounded, 'Request Id', request.requestNumber),
                      // if (request.bookingId != null)
                      //   _row(Icons.confirmation_number_outlined, 'Booking ID',
                      //       '${request.bookingNumber}'),
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

  Widget _buildAvatarCard(
    String name,
    String? gender,
    int? age,
    bool isFamilyBooking,
    String bookerName,
    String? relation,
  ) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isMale = gender?.toLowerCase() == 'male';

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_navy.withValues(alpha: 0.05), _navy.withValues(alpha: 0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _navy.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 60.w,
            height: 60.w,
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: _navy.withValues(alpha: 0.2), width: 2),
            ),
            child: request.customerProfileImageUrl != null
                ? ClipOval(child: AppCachedImage(imageUrl: request.customerProfileImageUrl, isOval: true))
                : Center(
                    child: Text(initial, style: kTextBold2(color: _navy)),
                  ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: kTextBold1(), overflow: TextOverflow.ellipsis),
                SizedBox(height: 4.h),
                Wrap(
                  spacing: 6.w,
                  runSpacing: 4.h,
                  children: [
                    if (gender != null)
                      _pill(
                        isMale ? Icons.male_rounded : Icons.female_rounded,
                        _cap(gender),
                        isMale ? const Color(0xFF2563EB) : const Color(0xFFDB2777),
                      ),
                    if (age != null) _pill(Icons.person_outline_rounded, '$age yrs', _navy),
                    if (isFamilyBooking && relation != null)
                      _pill(Icons.family_restroom_rounded, _cap(relation), const Color(0xFF7C3AED)),
                  ],
                ),
                if (isFamilyBooking) ...[
                  SizedBox(height: 6.h),
                  Text(
                    'Booked by $bookerName',
                    style: kTextNormal0(color: _grey).copyWith(fontSize: 11.sp),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String label,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _greyBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 8.h),
            child: Row(
              children: [
                Icon(icon, size: 14.sp, color: color),
                SizedBox(width: 6.w),
                Text(
                  label,
                  style: kTextSemiBold0(color: color).copyWith(fontSize: 12.sp),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _greyBorder),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 4.h),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14.sp, color: _grey),
          SizedBox(width: 10.w),
          SizedBox(
            width: 110.w,
            child: Text(
              label,
              style: kTextNormal0(color: _grey).copyWith(fontSize: 12.sp),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: kTextSemiBold0().copyWith(fontSize: 13.sp),
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20.r)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10.sp, color: color),
          SizedBox(width: 3.w),
          Text(
            label,
            style: kTextMedium(color: color).copyWith(fontSize: 10.sp),
          ),
        ],
      ),
    );
  }
}
