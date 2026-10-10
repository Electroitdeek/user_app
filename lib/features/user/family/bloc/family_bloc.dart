import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/family_repository.dart';
import '../model/family_member_model.dart';
import 'family_event.dart';
import 'family_state.dart';

class FamilyBloc extends Bloc<FamilyEvent, FamilyState> {
  final FamilyRepository _repository;

  FamilyBloc(this._repository) : super(FamilyInitial()) {
    on<LoadFamilyMembers>(_onLoadFamilyMembers);
    on<AddFamilyMember>(_onAddFamilyMember);
    on<UpdateFamilyMember>(_onUpdateFamilyMember);
    on<DeleteFamilyMember>(_onDeleteFamilyMember);
  }

  Future<void> _onLoadFamilyMembers(LoadFamilyMembers event, Emitter<FamilyState> emit) async {
    emit(FamilyLoading());
    try {
      final members = await _repository.getFamilyMembers();
      emit(FamilyLoaded(members));
    } catch (e) {
      emit(FamilyError(e.toString()));
    }
  }

  Future<void> _onAddFamilyMember(AddFamilyMember event, Emitter<FamilyState> emit) async {
    final current = state is FamilyLoaded
        ? (state as FamilyLoaded).members
        : (state is FamilyActionSuccess ? (state as FamilyActionSuccess).members : <FamilyMemberModel>[]);
    emit(FamilyLoading());
    try {
      await _repository.addOrUpdateFamilyMember(event.member);
      final members = await _repository.getFamilyMembers();
      emit(FamilyActionSuccess('Family member added successfully', members));
    } catch (e) {
      emit(FamilyError(e.toString()));
      emit(FamilyLoaded(current));
    }
  }

  Future<void> _onUpdateFamilyMember(UpdateFamilyMember event, Emitter<FamilyState> emit) async {
    final current = state is FamilyLoaded
        ? (state as FamilyLoaded).members
        : (state is FamilyActionSuccess ? (state as FamilyActionSuccess).members : <FamilyMemberModel>[]);
    emit(FamilyLoading());
    try {
      await _repository.addOrUpdateFamilyMember(event.member);
      final members = await _repository.getFamilyMembers();
      emit(FamilyActionSuccess('Family member updated successfully', members));
    } catch (e) {
      emit(FamilyError(e.toString()));
      emit(FamilyLoaded(current));
    }
  }

  Future<void> _onDeleteFamilyMember(DeleteFamilyMember event, Emitter<FamilyState> emit) async {
    final current = state is FamilyLoaded
        ? (state as FamilyLoaded).members
        : (state is FamilyActionSuccess ? (state as FamilyActionSuccess).members : <FamilyMemberModel>[]);
    emit(FamilyLoading());
    try {
      await _repository.deleteFamilyMember(event.id);
      final members = await _repository.getFamilyMembers();
      emit(FamilyActionSuccess('Family member deleted successfully', members));
    } catch (e) {
      emit(FamilyError(e.toString()));
      emit(FamilyLoaded(current));
    }
  }
}
