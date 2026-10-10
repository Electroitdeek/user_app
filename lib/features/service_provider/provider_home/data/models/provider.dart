class Provider {
  final String id;
  final String name;
  final String photo;
  final double rating;

  Provider({required this.id, required this.name, required this.photo, required this.rating});

  factory Provider.fromJson(Map<String, dynamic> json) {
    return Provider(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      photo: json['photo'] ?? '',
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0.0,
    );
  }
}
