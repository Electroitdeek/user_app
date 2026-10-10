class Helpers {
  Helpers._();

  static String initials(String name) {
    try {
      final parts = name.split(' ');
      return parts.length >= 2 ? '${parts[0][0]}${parts[1][0]}'.toUpperCase() : name[0].toUpperCase();
    } on FormatException {
      return name.isNotEmpty ? name[0].toUpperCase() : "N";
    }
  }

  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}
