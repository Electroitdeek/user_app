import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/models/user_profile_model.dart';
import '../data/user_profile_repository.dart';

// ── Events ────────────────────────────────────────────────────────────────────

abstract class UserProfileEvent {}

class LoadUserProfile extends UserProfileEvent {}

class RefreshUserProfile extends UserProfileEvent {}

// ── States ────────────────────────────────────────────────────────────────────

abstract class UserProfileState {}

class UserProfileInitial extends UserProfileState {}

class UserProfileLoading extends UserProfileState {}

class UserProfileLoaded extends UserProfileState {
  final UserProfileModel profile;
  final bool isRefreshing;
  UserProfileLoaded(this.profile, {this.isRefreshing = false});
}

class UserProfileError extends UserProfileState {
  final String message;
  UserProfileError(this.message);
}

// ── BLoC ──────────────────────────────────────────────────────────────────────

class UserProfileBloc extends Bloc<UserProfileEvent, UserProfileState> {
  final UserProfileRepository _repository;

  UserProfileBloc(this._repository) : super(UserProfileInitial()) {
    on<LoadUserProfile>(_onLoad);
    on<RefreshUserProfile>(_onRefresh);
  }

  Future<void> _onLoad(LoadUserProfile event, Emitter<UserProfileState> emit) async {
    emit(UserProfileLoading());
    try {
      final profile = await _repository.getProfile();
      emit(UserProfileLoaded(profile));
    } catch (e) {
      emit(UserProfileError(e.toString()));
    }
  }

  Future<void> _onRefresh(RefreshUserProfile event, Emitter<UserProfileState> emit) async {
    if (state is UserProfileLoaded) {
      final current = (state as UserProfileLoaded).profile;
      emit(UserProfileLoaded(current, isRefreshing: true));
    }
    try {
      final profile = await _repository.getProfile();
      emit(UserProfileLoaded(profile));
    } catch (e) {
      emit(UserProfileError(e.toString()));
    }
  }
}