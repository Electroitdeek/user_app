import '../../service_booking/data/service_category_repository.dart';

/// Model for a single customer address.
class UserAddressModel {
  final int? id;
  final String? mongoId;
  final String? addressType; // 'home', 'work', 'other'
  final String fullAddress;
  final String? area;
  final String? city;
  final String? state;
  final String? pinCode;
  final String? latitude;
  final String? longitude;
  final bool isDefault;

  const UserAddressModel({
    this.id,
    this.mongoId,
    this.addressType,
    required this.fullAddress,
    this.area,
    this.city,
    this.state,
    this.pinCode,
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  factory UserAddressModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['mongoId'] ?? json['id'];
    final mongoId = rawId is String && rawId.isNotEmpty ? rawId : null;
    final intId = json['id'] is int
        ? json['id'] as int
        : json['id'] is num
        ? (json['id'] as num).toInt()
        : mongoId == null
        ? null
        : rememberCatalogId(mongoId);
    final label = (json['address_type'] ?? json['label'] ?? '').toString().trim().toLowerCase();
    return UserAddressModel(
      id: intId,
      mongoId: mongoId,
      addressType: label.isEmpty ? null : label,
      fullAddress: json['full_address']?.toString() ?? json['fullAddress']?.toString() ?? '',
      area: json['area']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      pinCode: json['pin_code']?.toString() ?? json['pincode']?.toString(),
      latitude: json['latitude']?.toString(),
      longitude: json['longitude']?.toString(),
      isDefault: json['is_default'] == true || json['is_default'] == 1 || json['isDefault'] == true,
    );
  }

  Map<String, dynamic> toFormMap() => {
    if (id != null) 'id': id.toString(),
    if (addressType != null) 'address_type': addressType,
    'full_address': fullAddress,
    if (area != null) 'area': area,
    if (city != null) 'city': city,
    if (state != null) 'state': state,
    if (pinCode != null) 'pin_code': pinCode,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    'is_default': isDefault ? '1' : '0',
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'mongoId': mongoId,
    'address_type': addressType,
    'full_address': fullAddress,
    'area': area,
    'city': city,
    'state': state,
    'pin_code': pinCode,
    'latitude': latitude,
    'longitude': longitude,
    'is_default': isDefault,
  };

  UserAddressModel copyWith({
    int? id,
    String? mongoId,
    String? addressType,
    String? fullAddress,
    String? area,
    String? city,
    String? state,
    String? pinCode,
    String? latitude,
    String? longitude,
    bool? isDefault,
  }) => UserAddressModel(
    id: id ?? this.id,
    mongoId: mongoId ?? this.mongoId,
    addressType: addressType ?? this.addressType,
    fullAddress: fullAddress ?? this.fullAddress,
    area: area ?? this.area,
    city: city ?? this.city,
    state: state ?? this.state,
    pinCode: pinCode ?? this.pinCode,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    isDefault: isDefault ?? this.isDefault,
  );

  /// Street line, or area, city and pin when the street line is empty.
  String get displayAddress {
    if (fullAddress.trim().isNotEmpty) return fullAddress.trim();
    return [area, city, state, pinCode]
        .where((part) => part != null && part.trim().isNotEmpty)
        .map((part) => part!.trim())
        .join(', ');
  }

  /// Display label – e.g. "Home • Jaipur"
  String get shortLabel {
    final parts = <String>[
      if (addressType != null && addressType!.isNotEmpty)
        addressType![0].toUpperCase() + addressType!.substring(1),
      if (city != null && city!.isNotEmpty) city!,
    ];
    return parts.join(' • ');
  }
}
