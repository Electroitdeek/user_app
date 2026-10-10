class Booking {
  final String id;
  final String serviceType;
  final DateTime scheduledTime;
  final String status;

  Booking({required this.id, required this.serviceType, required this.scheduledTime, required this.status});

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] ?? '',
      serviceType: json['service_type'] ?? '',
      scheduledTime: DateTime.tryParse(json['scheduled_time'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? '',
    );
  }
}
