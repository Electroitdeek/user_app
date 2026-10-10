import 'package:adhisaat_health_care/di/locator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/system_settings_model.dart';
import '../repositories/system_settings_repository.dart';

final systemSettingsProvider = FutureProvider<SystemSettingsResponse>((ref) async {
  final repository = locator<SystemSettingsRepository>();
  return await repository.getSystemSettings();
});

final freeServiceDistanceProvider = Provider<double>((ref) {
  final settings = ref.watch(systemSettingsProvider).value?.data ?? [];
  final setting = settings.where((s) => s.settingKey == 'free_service_distance_km').firstOrNull;
  if (setting != null) {
    return double.tryParse(setting.settingValue) ?? 5.0;
  }
  return 5.0;
});

final maxSearchRadiusProvider = Provider<double>((ref) {
  final settings = ref.watch(systemSettingsProvider).value?.data ?? [];
  final setting = settings.where((s) => s.settingKey == 'max_search_radius_km').firstOrNull;
  if (setting != null) {
    return double.tryParse(setting.settingValue) ?? 50.0;
  }
  return 50.0;
});

final radiusIncreaseStepProvider = Provider<double>((ref) {
  final settings = ref.watch(systemSettingsProvider).value?.data ?? [];
  final setting = settings.where((s) => s.settingKey == 'radius_increase_step_km').firstOrNull;
  if (setting != null) {
    return double.tryParse(setting.settingValue) ?? 5.0;
  }
  return 5.0;
});

final proceduralBufferHoursProvider = Provider<int>((ref) {
  final settings = ref.watch(systemSettingsProvider).value?.data ?? [];
  final setting = settings.where((s) => s.settingKey == 'procedural_booking_buffer_time').firstOrNull;
  return int.tryParse(setting?.settingValue ?? '') ?? 3;
});

final longDurationBufferHoursProvider = Provider<int>((ref) {
  final settings = ref.watch(systemSettingsProvider).value?.data ?? [];
  final setting = settings.where((s) => s.settingKey == 'long_duration_booking_buffer_time').firstOrNull;
  return int.tryParse(setting?.settingValue ?? '') ?? 8;
});

/// Minutes before a booking's scheduled start at which patient privacy details
/// (name, phone, exact address) unlock for the provider. Default 180 min (3h).
final bookingStartReminderMinutesProvider = Provider<int>((ref) {
  final settings = ref.watch(systemSettingsProvider).value?.data ?? [];
  final setting = settings.where((s) => s.settingKey == 'booking_start_reminder_minutes').firstOrNull;
  return int.tryParse(setting?.settingValue ?? '') ?? 180;
});
