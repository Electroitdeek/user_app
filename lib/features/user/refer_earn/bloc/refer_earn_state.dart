part of 'refer_earn_bloc.dart';
abstract class ReferEarnState {}
class ReferEarnInitial extends ReferEarnState {}
class ReferEarnLoading extends ReferEarnState {}
class ReferEarnLoaded extends ReferEarnState {
  final String referralCode;
  final int rewardAmount;
  final String userName;
  ReferEarnLoaded({
    required this.referralCode,
    required this.rewardAmount,
    required this.userName,
  });
}
class ReferEarnError extends ReferEarnState {
  final String message;
  ReferEarnError(this.message);
}
