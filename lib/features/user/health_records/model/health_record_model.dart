class HealthRecordModel {
  final int id;
  final int customerProfileId;
  final int? familyMemberId;
  final String recordType;
  final String recordTitle;
  final String recordDate;
  final String? hospitalName;
  final String? doctorName;
  final String? notes;
  final String? documentUrl;
  final String? createdAt;

  const HealthRecordModel({
    required this.id,
    required this.customerProfileId,
    this.familyMemberId,
    required this.recordType,
    required this.recordTitle,
    required this.recordDate,
    this.hospitalName,
    this.doctorName,
    this.notes,
    this.documentUrl,
    this.createdAt,
  });

  factory HealthRecordModel.fromJson(Map<String, dynamic> json) {
    return HealthRecordModel(
      id: json['id'],
      customerProfileId: json['customer_profile_id'],
      familyMemberId: json['family_member_id'],
      recordType: json['record_type'] ?? '',
      recordTitle: json['record_title'] ?? '',
      recordDate: json['record_date'] ?? '',
      hospitalName: json['hospital_name'],
      doctorName: json['doctor_name'],
      notes: json['notes'],
      documentUrl: json['document_url'] != null ? json['document_full_url'] : null,
      createdAt: json['created_at'],
    );
  }
}

// ─── Record Types Metadata ────────────────────────────────────────────────────

const List<Map<String, String>> kRecordTypes = [
  {'value': 'report', 'label': 'Report', 'icon': '📝'},
  {'value': 'prescription', 'label': 'Prescription', 'icon': '💊'},
  {'value': 'discharge_summary', 'label': 'Discharge Summary', 'icon': '🏥'},
  {'value': 'x_ray', 'label': 'X-Ray', 'icon': '🩻'},
  {'value': 'scan', 'label': 'Scan / Imaging', 'icon': '🖼️'},
  {'value': 'other', 'label': 'Other', 'icon': '📄'},
];

String getRecordTypeLabel(String value) =>
    kRecordTypes.firstWhere((e) => e['value'] == value, orElse: () => {'label': value})['label']!;

String getRecordTypeIcon(String value) =>
    kRecordTypes.firstWhere((e) => e['value'] == value, orElse: () => {'icon': '📄'})['icon']!;
