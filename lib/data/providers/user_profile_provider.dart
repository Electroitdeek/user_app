import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../di/locator.dart';
import '../../features/user/profile/data/user_profile_repository.dart';
import '../models/user_profile_model.dart';

/// Holds the current user's profile data.
/// - Set via `ref.read(userProfileProvider.notifier).state = profile`
/// - Read via `ref.watch(userProfileProvider)` — returns `UserProfileModel?`
final userProfileProvider = StateProvider<UserProfileModel?>((ref) => null);

/// Async provider that fetches the profile from API.
/// Use `ref.invalidate(userProfileFetchProvider)` to re-fetch.
final userProfileFetchProvider = FutureProvider<UserProfileModel?>((ref) async {
  try {
    final repo = locator<UserProfileRepository>();
    final profile = await repo.getProfile();
    // Also update the synchronous state provider
    ref.read(userProfileProvider.notifier).state = profile;
    return profile;
  } catch (_) {
    return null;
  }
});
