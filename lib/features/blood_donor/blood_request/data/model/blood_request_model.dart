class BloodRequest {
  final int? id;
  final String patientName;
  final String patientAge;
  final String bloodGroupRequired;
  final String unitsRequired;
  final String urgencyLevel;
  final String requiredByDate;
  final String hospitalName;
  final String hospitalAddress;
  final String hospitalCity;
  final String hospitalState;
  final String hospitalContact;
  final double? hospitalLatitude;
  final double? hospitalLongitude;
  final String? diseaseCondition;
  final String? additionalNotes;
  final String contactPersonName;
  final String contactPersonMobile;
  final String contactPersonRelation;
  final String? requestStatus;
  final String? createdAt;

  BloodRequest({
    this.id,
    required this.patientName,
    required this.patientAge,
    required this.bloodGroupRequired,
    required this.unitsRequired,
    required this.urgencyLevel,
    required this.requiredByDate,
    required this.hospitalName,
    required this.hospitalAddress,
    required this.hospitalCity,
    required this.hospitalState,
    required this.hospitalContact,
    this.hospitalLatitude,
    this.hospitalLongitude,
    this.diseaseCondition,
    this.additionalNotes,
    required this.contactPersonName,
    required this.contactPersonMobile,
    required this.contactPersonRelation,
    this.requestStatus,
    this.createdAt,
  });

  factory BloodRequest.fromJson(Map<String, dynamic> json) {
    return BloodRequest(
      id: json['id'],
      patientName: json['patient_name'] ?? '',
      patientAge: json['patient_age']?.toString() ?? '',
      bloodGroupRequired: json['blood_group_required'] ?? '',
      unitsRequired: json['units_required']?.toString() ?? '',
      urgencyLevel: json['urgency_level'] ?? '',
      requiredByDate: json['required_by_date'] ?? '',
      hospitalName: json['hospital_name'] ?? '',
      hospitalAddress: json['hospital_address'] ?? '',
      hospitalCity: json['hospital_city'] ?? '',
      hospitalState: json['hospital_state'] ?? '',
      hospitalContact: json['hospital_contact'] ?? '',
      hospitalLatitude: json['hospital_latitude'] != null ? double.tryParse(json['hospital_latitude'].toString()) : null,
      hospitalLongitude: json['hospital_longitude'] != null ? double.tryParse(json['hospital_longitude'].toString()) : null,
      diseaseCondition: json['disease_condition'],
      additionalNotes: json['additional_notes'],
      contactPersonName: json['contact_person_name'] ?? '',
      contactPersonMobile: json['contact_person_mobile'] ?? '',
      contactPersonRelation: json['contact_person_relation'] ?? '',
      requestStatus: json['request_status'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toFormData() {
    final data = {
      'patient_name': patientName,
      'patient_age': patientAge,
      'blood_group_required': bloodGroupRequired,
      'units_required': unitsRequired,
      'urgency_level': urgencyLevel,
      'required_by_date': requiredByDate,
      'hospital_name': hospitalName,
      'hospital_address': hospitalAddress,
      'hospital_city': hospitalCity,
      'hospital_state': hospitalState,
      'hospital_contact': hospitalContact,
      'contact_person_name': contactPersonName,
      'contact_person_mobile': contactPersonMobile,
      'contact_person_relation': contactPersonRelation,
    };

    if (id != null) data['id'] = id.toString();
    if (hospitalLatitude != null) data['hospital_latitude'] = hospitalLatitude.toString();
    if (hospitalLongitude != null) data['hospital_longitude'] = hospitalLongitude.toString();
    if (diseaseCondition != null) data['disease_condition'] = diseaseCondition!;
    if (additionalNotes != null) data['additional_notes'] = additionalNotes!;

    return data;
  }
}