class SystemSetting {
  final int id;
  final String key;
  final String value;
  final String type;
  final String description;

  const SystemSetting({
    required this.id,
    required this.key,
    required this.value,
    required this.type,
    required this.description,
  });

  factory SystemSetting.fromJson(Map<String, dynamic> json) => SystemSetting(
        id: json['id'] ?? 0,
        key: json['setting_key'] ?? '',
        value: json['setting_value'] ?? '',
        type: json['setting_type'] ?? 'string',
        description: json['description'] ?? '',
      );

  int get intValue => int.tryParse(value) ?? 0;
  double get doubleValue => double.tryParse(value) ?? 0;
}

class SystemSettingsResponse {
  final bool status;
  final List<SystemSetting> settings;

  const SystemSettingsResponse({required this.status, required this.settings});

  factory SystemSettingsResponse.fromJson(Map<String, dynamic> json) =>
      SystemSettingsResponse(
        status: json['status'] == true,
        settings: (json['data'] as List<dynamic>? ?? [])
            .map((e) => SystemSetting.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Convenience: find by key
  SystemSetting? get(String key) =>
      settings.cast<SystemSetting?>().firstWhere((s) => s?.key == key, orElse: () => null);

  int referralRewardAmount() => get('referral_reward_amount')?.intValue ?? 0;
}
