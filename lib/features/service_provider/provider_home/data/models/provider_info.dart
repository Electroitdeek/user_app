class ProviderInfo {
  final String name;
  final String role;
  final String? photoUrl;
  final double rating;
  final int totalReviews;
  final int completedServices;

  ProviderInfo({
    required this.name,
    required this.role,
    this.photoUrl,
    required this.rating,
    required this.totalReviews,
    required this.completedServices,
  });

  String get initials {
    final parts = name.split(' ');
    return parts.length >= 2 ? '${parts[0][0]}${parts[1][0]}'.toUpperCase() : name[0].toUpperCase();
  }
}
