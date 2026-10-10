import 'package:adhisaat_health_care/core/services/file_downloading_service.dart';
import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_requests/data/repositories/provider_request_repository.dart';
import 'package:adhisaat_health_care/features/user/health_records/model/health_record_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

class HealthRecordsSheet extends StatefulWidget {
  final int? customerProfileId;
  final int? familyMemberId;

  const HealthRecordsSheet({super.key, this.customerProfileId, this.familyMemberId});

  @override
  State<HealthRecordsSheet> createState() => _HealthRecordsSheetState();
}

class _HealthRecordsSheetState extends State<HealthRecordsSheet> {
  bool _isLoading = true;
  String? _error;
  List<HealthRecordModel> _records = [];

  static const _blue = Color(0xFF2D62ED);
  static const _greyText = Color(0xFF6B7280);
  static const _greyBg = Color(0xFFF7F8FC);

  @override
  void initState() {
    super.initState();
    _fetchRecords();
  }

  Future<void> _fetchRecords() async {
    try {
      final repo = locator<ProviderRequestRepository>();
      final data = await repo.getHealthRecords(
        customerProfileId: widget.customerProfileId,
        familyMemberId: widget.familyMemberId,
      );
      if (mounted) setState(() { _records = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; });
    }
  }

  String _fmtDate(String raw) {
    try {
      final d = DateTime.parse(raw);
      return DateFormat('dd MMM yyyy').format(d);
    } catch (_) {
      return raw;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'prescription': return const Color(0xFF7C3AED);
      case 'x_ray': return const Color(0xFF0891B2);
      case 'scan': return const Color(0xFF0891B2);
      case 'discharge_summary': return kErrorColor;
      case 'report': return _blue;
      default: return _greyText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.78.sh,
      decoration: BoxDecoration(
        color: _greyBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        children: [
          // ── Drag handle ────────────────────────────────────────────
          SizedBox(height: 12.h),
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          // ── Header ─────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2D62ED), Color(0xFF1A4FD0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: _blue.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(Icons.medical_information_rounded, color: Colors.white, size: 20.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Health Records', style: kTextBold2().copyWith(fontSize: 18.sp)),
                      Text(
                        'Medical history & reports',
                        style: kTextNormal0(color: _greyText).copyWith(fontSize: 12.sp),
                      ),
                    ],
                  ),
                ),
                if (!_isLoading && _records.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      '${_records.length} record${_records.length > 1 ? 's' : ''}',
                      style: kTextSemiBold0(color: _blue).copyWith(fontSize: 11.sp),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Container(height: 1, color: Colors.grey.withValues(alpha: 0.12)),
          // ── Content ────────────────────────────────────────────────
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline_rounded, size: 48.sp, color: kErrorColor),
            SizedBox(height: 12.h),
            Text(_error!, style: kTextMedium(color: kErrorColor), textAlign: TextAlign.center),
            SizedBox(height: 16.h),
            TextButton.icon(
              onPressed: () { setState(() { _isLoading = true; _error = null; }); _fetchRecords(); },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ]),
        ),
      );
    }
    if (_records.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.folder_open_rounded, size: 48.sp, color: _blue.withValues(alpha: 0.4)),
          ),
          SizedBox(height: 16.h),
          Text('No Records Found', style: kTextSemiBold1(color: _greyText)),
          SizedBox(height: 6.h),
          Text(
            'Patient has not shared any health records yet.',
            style: kTextNormal0(color: _greyText).copyWith(fontSize: 12.sp),
            textAlign: TextAlign.center,
          ),
        ]),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
      itemCount: _records.length,
      itemBuilder: (_, i) => _RecordCard(
        record: _records[i],
        typeColor: _typeColor(_records[i].recordType),
        formattedDate: _fmtDate(_records[i].recordDate),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final HealthRecordModel record;
  final Color typeColor;
  final String formattedDate;

  const _RecordCard({
    required this.record,
    required this.typeColor,
    required this.formattedDate,
  });

  static const _greyText = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final rec = record;
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border(left: BorderSide(color: typeColor, width: 3.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Center(
                child: Text(getRecordTypeIcon(rec.recordType), style: TextStyle(fontSize: 20.sp)),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(rec.recordTitle, style: kTextSemiBold1(), maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: 3.h),
                Row(children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      getRecordTypeLabel(rec.recordType),
                      style: kTextNormal0(color: typeColor).copyWith(fontSize: 10.sp),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Icon(Icons.calendar_today_rounded, size: 10.sp, color: _greyText),
                  SizedBox(width: 3.w),
                  Text(formattedDate, style: kTextNormal0(color: _greyText).copyWith(fontSize: 11.sp)),
                ]),
              ]),
            ),
          ]),
          if (rec.doctorName != null || rec.hospitalName != null) ...[
            SizedBox(height: 10.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 4.h,
              children: [
                if (rec.doctorName != null)
                  _InfoChip(icon: Icons.person_outlined, label: rec.doctorName!),
                if (rec.hospitalName != null)
                  _InfoChip(icon: Icons.local_hospital_outlined, label: rec.hospitalName!),
              ],
            ),
          ],
          if (rec.notes != null && rec.notes!.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.all(10.w),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: Text(
                rec.notes!,
                style: kTextNormal0(color: _greyText).copyWith(fontSize: 12.sp, height: 1.5),
              ),
            ),
          ],
          if (rec.documentUrl != null) ...[
            SizedBox(height: 12.h),
            GestureDetector(
              onTap: () => FileDownloadService()
                  .downloadAndViewFile(url: rec.documentUrl!, originalName: rec.recordTitle),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 9.h),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: kPrimaryColor.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.attach_file_rounded, size: 14.sp, color: kPrimaryColor),
                    SizedBox(width: 6.w),
                    Text(
                      'View Attachment',
                      style: kTextSemiBold(color: kPrimaryColor).copyWith(fontSize: 13.sp),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10.sp, color: const Color(0xFF6B7280)),
        SizedBox(width: 4.w),
        Text(
          label,
          style: kTextNormal0(color: const Color(0xFF6B7280)).copyWith(fontSize: 11.sp),
        ),
      ]),
    );
  }
}
