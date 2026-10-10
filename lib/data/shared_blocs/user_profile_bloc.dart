import 'package:adhisaat_health_care/data/models/user_profile_model.dart';
import 'package:adhisaat_health_care/data/repositories/provider_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/storage/local_storage_service.dart';
import '../../di/locator.dart';

part 'user_profile_event.dart';
part 'user_profile_state.dart';

class UserBloc extends Bloc<UserEvent, UserState> {
  final ProviderRepository _repository;
  final storage = locator<LocalStorageService>();

  UserBloc(this._repository, {UserProfileModel? initialUser})
    : super(initialUser != null ? UserLoaded(initialUser) : UserInitial()) {
    on<LoadUserProfile>(_onLoadUserProfile);
    on<UpdateUserProfile>(_onUpdateUserProfile);
    on<RefreshUserProfile>(_onRefreshUserProfile);
  }

  Future<void> _onLoadUserProfile(LoadUserProfile event, Emitter<UserState> emit) async {
    // if (state is UserLoaded) {
    //   // Already loaded, do nothing
    //   return;
    // }
    emit(UserLoading());

    try {
      // Try to get from cache first
      final cachedData = await storage.getUserProfile();

      if (cachedData != null) {
        final user = UserProfileModel.fromJson(cachedData);
        emit(UserLoaded(user));

        // Optionally fetch fresh data in background if needed
        if (event.forceRefresh) {
          await _fetchFreshProfile(emit);
        }
      } else {
        // No cache, fetch from API
        await _fetchFreshProfile(emit);
      }
    } catch (e) {
      emit(UserError(e.toString()));
    }
  }

  Future<void> _fetchFreshProfile(Emitter<UserState> emit) async {
    try {
      final profile = await _repository.getProfile();

      // Cache the response
      await storage.saveUserProfile(profile.toJson());

      emit(UserLoaded(profile));
    } catch (e) {
      emit(UserError(e.toString()));
    }
  }

  void _onUpdateUserProfile(UpdateUserProfile event, Emitter<UserState> emit) async {
    // Update cache
    await storage.saveUserProfile(event.user.toJson());
    emit(UserLoaded(event.user));
  }

  Future<void> _onRefreshUserProfile(RefreshUserProfile event, Emitter<UserState> emit) async {
    // Keep current state while refreshing
    final currentUser = state is UserLoaded ? (state as UserLoaded).user : null;

    try {
      await _fetchFreshProfile(emit);
    } catch (e) {
      // If refresh fails, keep old data
      if (currentUser != null) {
        emit(UserLoaded(currentUser));
      } else {
        emit(UserError(e.toString()));
      }
    }
  }
}
