import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/features/user/payment/data/payment_repository.dart';
import 'service_availability_provider.dart';

final activePromoBannersProvider = FutureProvider.autoDispose<List<AvailablePromoCode>>((ref) async {
  // Wait for service availability check to complete so that cityAdminId is set in storage.
  try {
    await ref.read(serviceAvailabilityProvider.future);
  } catch (_) {
    // Ignore availability errors and try fetching fallback promo codes
  }

  final repo = locator<PaymentRepository>();

  final allPromos = await repo.getAvailablePromoCodes();
  return allPromos
      .where((p) => p.bannerImage != null && p.bannerImage!.trim().isNotEmpty && p.isActive && !p.isExpired)
      .toList();
});
