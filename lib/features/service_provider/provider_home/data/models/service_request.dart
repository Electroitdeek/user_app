class ServiceRequest {
  final String id;
  final String patientName;
  final int age;
  final String serviceType;
  final String address;
  final String distance;
  final String time;
  final String date;
  final double payment;
  final double latitude;
  final double longitude;

  /// True when this booking came from the Emergency flow.
  /// When true, the provider must push live GPS to Firestore after accepting.
  final bool isEmergency;

  /// Numeric booking ID used as the Firestore document key for tracking.
  final int bookingId;
  final String? shiftType;
  final String? patientPhone;
  final List<int> subBlockIds;

  ServiceRequest({
    required this.id,
    required this.patientName,
    required this.age,
    required this.serviceType,
    required this.address,
    required this.distance,
    required this.time,
    required this.date,
    required this.payment,
    required this.latitude,
    required this.longitude,
    this.isEmergency = false,
    this.bookingId = 0,
    this.shiftType,
    this.patientPhone,
    this.subBlockIds = const [],
  });

  factory ServiceRequest.fromProviderRequest(dynamic r) {
    // r is ProviderServiceRequestModel — typed import avoided to prevent circular deps
    return ServiceRequest(
      id: r.id.toString(),
      patientName: r.customerName ?? '',
      serviceType: r.serviceCategoryName ?? '',
      address: r.address ?? '',
      distance: r.distanceKm.toString(),
      age: 0,
      time: r.startTime ?? '',
      date: r.startDate ?? '',
      payment: (r.totalAmount ?? 0.0).toDouble(),
      latitude: r.serviceLatitude,
      longitude: r.serviceLongitude,
      isEmergency: r.isEmergency == 1,
      bookingId: r.bookingId ?? 0,
      shiftType: r.shiftType,
      patientPhone: r.customerPhone,
      subBlockIds: (r.subBlocks as List).map<int>((b) => b.id as int).where((id) => id > 0).toList(),
    );
  }

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    // Support both 'id' (API) and 'request_id' (notification payload)
    final rawId = json['request_id']?.toString() ?? json['id']?.toString() ?? '';
    
    // For emergency notifications: provider_name is actually the patient/customer name
    // Map the notification payload fields to proper model fields
    final patientName = json['patient_name'] ?? 
        json['customer_name'] ?? 
        json['provider_name'] ?? // emergency payload uses this for patient name
        '';
    
    return ServiceRequest(
      id: rawId,
      patientName: patientName,
      serviceType: json['service_type'] ?? json['category_name'] ?? 'Emergency Service',
      address: json['address'] ?? json['customer_address'] ?? '',
      distance: (double.tryParse(json['distance']?.toString() ?? '0') ?? 0.0).toString(),
      age: json['patient_age'] ?? json['customer_age'] ?? 0,
      time: (DateTime.tryParse(json['request_time'] ?? '') ?? DateTime.now()).toString(),
      date: json['date'] ?? '',
      payment: (json['payment'] as num?)?.toDouble() ?? 0.0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 
          double.tryParse(json['customer_latitude']?.toString() ?? '') ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 
          double.tryParse(json['customer_longitude']?.toString() ?? '') ?? 0.0,
      // is_emergency can arrive as bool, int (1/0), or String 'true'/'false'
      isEmergency: json['is_emergency'] == true ||
          json['is_emergency'] == 1 ||
          json['is_emergency']?.toString().toLowerCase() == 'true' ||
          json['type']?.toString() == 'emergency_request',
      bookingId: (json['booking_id'] as num?)?.toInt() ??
          int.tryParse(rawId) ?? 0,
      shiftType: json['shift_type_text'] ?? json['shift_type'],
      patientPhone: json['patient_phone'] ?? json['customer_phone'],
      subBlockIds: (json['sub_blocks'] as List<dynamic>? ?? [])
          .map((b) => (b['id'] as num?)?.toInt() ?? 0)
          .where((id) => id > 0)
          .toList(),
    );
  }
}