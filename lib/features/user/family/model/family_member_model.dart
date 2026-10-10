class FamilyMemberModel {
  final int? id;
  final String fullName;
  final String relationship;
  final String dateOfBirth; // API uses YYYY-MM-DD
  final String gender;
  final String? bloodGroup;
  final String? mobileNumber;

  const FamilyMemberModel({
    this.id,
    required this.fullName,
    required this.relationship,
    required this.dateOfBirth,
    required this.gender,
    this.bloodGroup,
    this.mobileNumber,
  });

  factory FamilyMemberModel.fromJson(Map<String, dynamic> json) {
    return FamilyMemberModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      fullName: json['full_name']?.toString() ?? '',
      relationship: json['relationship']?.toString() ?? '',
      dateOfBirth: json['date_of_birth']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      bloodGroup: json['blood_group']?.toString(),
      mobileNumber: json['mobile_number']?.toString(),
    );
  }

  Map<String, dynamic> toFormMap() {
    final map = <String, dynamic>{
      'full_name': fullName,
      'relationship': relationship,
      'date_of_birth': dateOfBirth,
      'gender': gender,
    };
    if (id != null) {
      map['id'] = id.toString();
    }
    if (bloodGroup != null) {
      map['blood_group'] = bloodGroup;
    }
    if (mobileNumber != null) {
      map['mobile_number'] = mobileNumber;
    }
    return map;
  }

  FamilyMemberModel copyWith({
    int? id,
    String? fullName,
    String? relationship,
    String? dateOfBirth,
    String? gender,
    String? bloodGroup,
    String? mobileNumber,
  }) {
    return FamilyMemberModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      relationship: relationship ?? this.relationship,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      mobileNumber: mobileNumber ?? this.mobileNumber,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FamilyMemberModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
