import 'package:equatable/equatable.dart';

import '../model/family_member_model.dart';

abstract class FamilyEvent extends Equatable {
  const FamilyEvent();

  @override
  List<Object?> get props => [];
}

class LoadFamilyMembers extends FamilyEvent {}

class AddFamilyMember extends FamilyEvent {
  final FamilyMemberModel member;
  const AddFamilyMember(this.member);

  @override
  List<Object?> get props => [member];
}

class UpdateFamilyMember extends FamilyEvent {
  final FamilyMemberModel member;
  const UpdateFamilyMember(this.member);

  @override
  List<Object?> get props => [member];
}

class DeleteFamilyMember extends FamilyEvent {
  final int id;
  const DeleteFamilyMember(this.id);

  @override
  List<Object?> get props => [id];
}
