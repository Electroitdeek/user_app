import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/api/api_endpoints.dart';
import 'package:adhisaat_health_care/core/storage/local_storage_service.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/features/user/profile/data/user_profile_repository.dart';
import 'package:adhisaat_health_care/features/user/refer_earn/model/system_setting_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'refer_earn_event.dart';
part 'refer_earn_state.dart';

class ReferEarnBloc extends Bloc<ReferEarnEvent, ReferEarnState> {
  final ApiClient _apiClient;
  final UserProfileRepository _profileRepo;

  ReferEarnBloc(this._apiClient, this._profileRepo) : super(ReferEarnInitial()) {
    on<LoadReferEarnData>(_onLoad);
  }

  Future<void> _onLoad(LoadReferEarnData event, Emitter emit) async {
    emit(ReferEarnLoading());
    try {
      // Fetch both in parallel
      final results = await Future.wait([
        _apiClient.get(ApiEndpoints.systemSettings),
        _profileRepo.getProfile(),
      ]);

      final settingsResponse = SystemSettingsResponse.fromJson(
        results[0] as Map<String, dynamic>,
      );
      final profile = results[1];

      final rewardAmount = settingsResponse.referralRewardAmount();

      // referral_code may come from profile API or be generated from userId
      final storage = locator<LocalStorageService>();
      final referralCode = (profile as dynamic).referralCode as String? ??
          'ADHI${storage.userId ?? ''}';

      emit(ReferEarnLoaded(
        referralCode: referralCode,
        rewardAmount: rewardAmount,
        userName: profile.name,
      ));
    } catch (e) {
      emit(ReferEarnError(e.toString()));
    }
  }
}
