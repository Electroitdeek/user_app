import 'package:dio/dio.dart';

// ── Professional document entry (Registration Certificate, etc.) ────────────
class ProfessionalDocument {
  final String? documentType;
  final String? documentName;
  final String? documentNumber;
  final String? issueDate; // yyyy-MM-dd
  final String? expiryDate; // yyyy-MM-dd
  final String? filePath; // local file path

  ProfessionalDocument({
    this.documentType,
    this.documentName,
    this.documentNumber,
    this.issueDate,
    this.expiryDate,
    this.filePath,
  });

  ProfessionalDocument copyWith({
    String? documentType,
    String? documentName,
    String? documentNumber,
    String? issueDate,
    String? expiryDate,
    String? filePath,
  }) => ProfessionalDocument(
    documentType: documentType ?? this.documentType,
    documentName: documentName ?? this.documentName,
    documentNumber: documentNumber ?? this.documentNumber,
    issueDate: issueDate ?? this.issueDate,
    expiryDate: expiryDate ?? this.expiryDate,
    filePath: filePath ?? this.filePath,
  );
}

// ── Main request model ────────────────────────────────────────────────────────
class ProviderProfileRequest {
  final int? userId;
  // Personal
  final String? name, mobile, whatsapp, email, dob, gender, bloodGroup;
  final String? aadharNo, panNo;

  // Professional
  final String? qualification; // NEW – Highest Qualification
  final String? registrationNumber; // NEW – Professional Reg. No.
  final String? councilName; // NEW – Council / Board Name
  final String? previousWorkplace; // NEW – Previous Workplace
  final String? preferredArea; // NEW – Preferred Working Area
  final String? experience;

  // Address
  final String? addressType, address, area, city, state, pinCode;
  final String? lat, long;
  final int? cityAdminId;

  // Service categories & availability
  final List<String>? serviceCategoryIds;
  final List<String>? dutyTypes;
  final List<String>? skills;

  // Documents (files) – NEW
  final String? aadharCardPath; // local path
  final String? panCardPath; // local path
  final String? profileImagePath; // local path
  final List<ProfessionalDocument>? professionalDocuments; // NEW
  final String? referralCode; // NEW
  final String? referredBy; // NEW

  // Bank Details
  final String? accountHolderName;
  final String? accountNumber;
  final String? ifscCode;
  final String? bankName;
  final String? branchName;
  final String? accountType;

  ProviderProfileRequest({
    this.name,
    this.mobile,
    this.whatsapp,
    this.email,
    this.dob,
    this.gender,
    this.bloodGroup,
    this.aadharNo,
    this.panNo,
    this.qualification,
    this.registrationNumber,
    this.councilName,
    this.previousWorkplace,
    this.preferredArea,
    this.experience,
    this.serviceCategoryIds,
    this.dutyTypes,
    this.skills,
    this.addressType,
    this.address,
    this.area,
    this.city,
    this.state,
    this.pinCode,
    this.lat,
    this.long,
    this.cityAdminId,
    this.aadharCardPath,
    this.panCardPath,
    this.profileImagePath,
    this.professionalDocuments,
    this.userId,
    this.referralCode,
    this.referredBy,
    this.accountHolderName,
    this.accountNumber,
    this.ifscCode,
    this.bankName,
    this.branchName,
    this.accountType,
  });

  /// Builds a [FormData] for multipart upload.
  /// Array fields (service_ids, duty_type, skills) are added as individual
  /// entries so every item arrives on the server — FormData.fromMap can
  /// silently drop duplicates when a Dart Map is used.
  Future<FormData> toFormData() async {
    final fd = FormData();

    void f(String key, String? value) {
      if (value != null) fd.fields.add(MapEntry(key, value));
    }

    f('user_id', userId?.toString());
    f('city_admin_id', cityAdminId?.toString());
    f('name', name);
    f('mobile_number', mobile);
    f('whatsapp_number', whatsapp);
    f('email', email);
    f('date_of_birth', dob);
    f('gender', gender);
    f('blood_group', bloodGroup);
    f('aadhar_no', aadharNo);
    f('pan_number', panNo);
    f('highest_qualification', qualification);
    f('professional_registration_number', registrationNumber);
    f('council_board_name', councilName);
    f('previous_workplace', previousWorkplace);
    f('preferred_working_area', preferredArea);
    f('address_type', addressType);
    f('full_address', address);
    f('area', area);
    f('city', city);
    f('state', state);
    f('pin_code', pinCode);
    f('latitude', lat);
    f('longitude', long);
    f('total_experience', experience);
    f('referral_code', referralCode);
    f('referred_by_id', referredBy);
    f('account_holder_name', accountHolderName);
    f('account_number', accountNumber);
    f('ifsc_code', ifscCode);
    f('bank_name', bankName);
    f('branch_name', branchName);
    f('account_type', accountType);
    if (accountNumber != null && accountNumber!.isNotEmpty) {
      fd.fields.add(const MapEntry('is_primary', '1'));
    }
    fd.fields.add(const MapEntry('declaration', '1'));

    // Array fields — indexed so all values reach the server
    final serviceIds = serviceCategoryIds ?? [];
    for (int i = 0; i < serviceIds.length; i++) {
      fd.fields.add(MapEntry('service_ids[$i]', serviceIds[i]));
    }
    final dutyTypeList = dutyTypes ?? [];
    for (int i = 0; i < dutyTypeList.length; i++) {
      fd.fields.add(MapEntry('duty_type[$i]', dutyTypeList[i]));
    }
    final skillsList = skills ?? [];
    for (int i = 0; i < skillsList.length; i++) {
      fd.fields.add(MapEntry('skills[$i]', skillsList[i]));
    }

    // Files
    if (aadharCardPath != null) {
      fd.files.add(MapEntry('aadhar_file_path', await MultipartFile.fromFile(
        aadharCardPath!, filename: aadharCardPath!.split('/').last,
      )));
    }
    if (panCardPath != null) {
      fd.files.add(MapEntry('pan_file_path', await MultipartFile.fromFile(
        panCardPath!, filename: panCardPath!.split('/').last,
      )));
    }
    if (profileImagePath != null) {
      fd.files.add(MapEntry('profile_image', await MultipartFile.fromFile(
        profileImagePath!, filename: profileImagePath!.split('/').last,
      )));
    }

    // Professional documents (indexed array)
    if (professionalDocuments != null) {
      for (int i = 0; i < professionalDocuments!.length; i++) {
        final doc = professionalDocuments![i];
        f('documents[$i][document_type]', doc.documentType);
        f('documents[$i][document_name]', doc.documentName);
        f('documents[$i][document_number]', doc.documentNumber);
        f('documents[$i][issue_date]', doc.issueDate);
        f('documents[$i][expiry_date]', doc.expiryDate);
        if (doc.filePath != null) {
          fd.files.add(MapEntry('documents[$i][document_file]',
              await MultipartFile.fromFile(doc.filePath!, filename: doc.filePath!.split('/').last)));
        }
      }
    }

    return fd;
  }

  /// Sync version for non-file fields (used by bloc when no files are present).
  // Map<String, dynamic> toJson() {
  //   return {
  //     if (name != null) 'name': name,
  //     if (mobile != null) 'mobile_number': mobile,
  //     if (whatsapp != null) 'whatsapp_number': whatsapp,
  //     if (email != null) 'email': email,
  //     if (dob != null) 'date_of_birth': dob,
  //     if (gender != null) 'gender': gender,
  //     if (bloodGroup != null) 'blood_group': bloodGroup,
  //     if (aadharNo != null) 'aadhar_no': aadharNo,
  //     if (panNo != null) 'pan_number': panNo,
  //     if (qualification != null) 'highest_qualification': qualification,
  //     if (registrationNumber != null) 'registration_number': registrationNumber,
  //     if (councilName != null) 'council_name': councilName,
  //     if (previousWorkplace != null) 'previous_workplace': previousWorkplace,
  //     if (preferredArea != null) 'preferred_working_area': preferredArea,
  //     if (addressType != null) 'address_type': addressType,
  //     if (address != null) 'full_address': address,
  //     if (area != null) 'area': area,
  //     if (city != null) 'city': city,
  //     if (state != null) 'state': state,
  //     if (pinCode != null) 'pin_code': pinCode,
  //     if (lat != null) 'latitude': lat,
  //     if (long != null) 'longitude': long,
  //     if (experience != null) 'total_experience': experience,
  //     'declaration': '1',
  //     if (profileImagePath != null) 'profile_image': profileImagePath,
  //     if (serviceCategoryIds != null)
  //       'service_category_ids[]': serviceCategoryIds,
  //     if (dutyTypes != null) 'duty_type[]': dutyTypes,
  //     if (skills != null) 'skills[]': skills,
  //   };
  // }
}
