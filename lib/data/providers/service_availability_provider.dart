import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import '../repositories/auth_repository.dart';
import '../models/service_availability_model.dart';
import '../../features/user/address/bloc/selected_address_provider.dart';

final serviceAvailabilityProvider = FutureProvider<ServiceAvailabilityResponse?>((ref) async {
  final address = ref.watch(selectedAddressProvider);
  return locator<AuthRepository>().checkServiceAvailability(address?.pinCode ?? '');
});