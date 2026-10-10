import 'package:equatable/equatable.dart';

import '../model/family_member_model.dart';

abstract class FamilyState extends Equatable {
  const FamilyState();

  @override
  List<Object?> get props => [];
}

class FamilyInitial extends FamilyState {}

class FamilyLoading extends FamilyState {}

class FamilyLoaded extends FamilyState {
  final List<FamilyMemberModel> members;

  const FamilyLoaded(this.members);

  @override
  List<Object?> get props => [members];
}

class FamilyActionSuccess extends FamilyState {
  final String message;
  final List<FamilyMemberModel> members;

  const FamilyActionSuccess(this.message, this.members);

  @override
  List<Object?> get props => [message, members];
}

class FamilyError extends FamilyState {
  final String message;

  const FamilyError(this.message);

  @override
  List<Object?> get props => [message];
}
