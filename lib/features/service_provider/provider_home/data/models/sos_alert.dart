class SOSAlert {
  final String id;
  final String userId;
  final String userName;
  final String location;
  final String type; // 'user' or 'provider'

  SOSAlert({
    required this.id,
    required this.userId,
    required this.userName,
    required this.location,
    required this.type,
  });

  factory SOSAlert.fromJson(Map<String, dynamic> json) {
    return SOSAlert(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? '',
      location: json['location'] ?? '',
      type: json['type'] ?? '',
    );
  }
}
