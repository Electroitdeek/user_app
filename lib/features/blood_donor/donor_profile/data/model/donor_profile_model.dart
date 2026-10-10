import '../../../../../data/models/user_profile_model.dart';

class DonorProfile {
  final int? id;
  final String? name;
  final String? email;
  final String? mobile;
  final String? bloodGroup;
  final String? gender;
  final String? dateOfBirth;
  final double? weightKg;
  final bool? isAvailable;
  final String? preferredContactMethod;
  final bool? showContactPublicly;
  final bool? receiveNotifications;
  final String? city;
  final String? state;
  final String? lastDonationDate;

  DonorProfile({
    this.id,
    this.name,
    this.email,
    this.mobile,
    this.bloodGroup,
    this.gender,
    this.dateOfBirth,
    this.weightKg,
    this.isAvailable,
    this.preferredContactMethod,
    this.showContactPublicly,
    this.receiveNotifications,
    this.city,
    this.state,
    this.lastDonationDate,
  });

  factory DonorProfile.fromJson(Map<String, dynamic> json) {
    // The API returns user fields at the top level and donor-specific fields inside 'donor_profile'
    final donorData = json['donor_profile'] ?? {};

    return DonorProfile(
      id: donorData['id'] ?? json['id'],
      name: json['name'],
      email: json['email'],
      mobile: json['mobile_number'] ?? json['mobile'],
      bloodGroup: json['blood_group'],
      gender: json['gender'],
      dateOfBirth: json['date_of_birth'],
      weightKg: donorData['weight_kg'] != null
          ? double.tryParse(donorData['weight_kg'].toString())
          : null,
      isAvailable:
          donorData['is_available'] == 1 ||
          donorData['is_available'] == true ||
          donorData['is_available'] == '1',
      preferredContactMethod: donorData['preferred_contact_method'],
      showContactPublicly:
          donorData['show_contact_publicly'] == 1 ||
          donorData['show_contact_publicly'] == true ||
          donorData['show_contact_publicly'] == '1',
      receiveNotifications:
          donorData['receive_notifications'] == 1 ||
          donorData['receive_notifications'] == true ||
          donorData['receive_notifications'] == '1',
      city: json['city'],
      state: json['state'],
      lastDonationDate: donorData['last_donation_date'],
    );
  }

  factory DonorProfile.fromUserProfileModel(UserProfileModel user) {
    return DonorProfile(
      name: user.name,
      email: user.email,
      mobile: user.mobileNumber,
      bloodGroup: user.bloodGroup,
      gender: user.gender,
      dateOfBirth: user.dateOfBirth,
      city: user.city,
      state: user.state,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'weight_kg': weightKg?.toString(),
      'is_available': isAvailable == true ? '1' : '0',
      'preferred_contact_method': preferredContactMethod,
      'show_contact_publicly': showContactPublicly == true ? '1' : '0',
      'receive_notifications': receiveNotifications == true ? '1' : '0',
      'gender': gender,
      'date_of_birth': dateOfBirth,
      'blood_group': bloodGroup,
    };
  }

  DonorProfile copyWith({
    int? id,
    String? name,
    String? email,
    String? mobile,
    String? bloodGroup,
    String? gender,
    String? dateOfBirth,
    double? weightKg,
    bool? isAvailable,
    String? preferredContactMethod,
    bool? showContactPublicly,
    bool? receiveNotifications,
    String? city,
    String? state,
    String? lastDonationDate,
  }) {
    return DonorProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      weightKg: weightKg ?? this.weightKg,
      isAvailable: isAvailable ?? this.isAvailable,
      preferredContactMethod:
          preferredContactMethod ?? this.preferredContactMethod,
      showContactPublicly: showContactPublicly ?? this.showContactPublicly,
      receiveNotifications: receiveNotifications ?? this.receiveNotifications,
      city: city ?? this.city,
      state: state ?? this.state,
      lastDonationDate: lastDonationDate ?? this.lastDonationDate,
    );
  }
}
