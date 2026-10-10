import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../family/data/family_repository.dart';
import '../../family/model/family_member_model.dart';
import '../data/health_record_repository.dart';
import '../model/health_record_model.dart';

part 'health_record_event.dart';
part 'health_record_state.dart';

class HealthRecordBloc extends Bloc<HealthRecordEvent, HealthRecordState> {
  final HealthRecordRepository _healthRepo;
  final FamilyRepository _familyRepo;

  HealthRecordBloc({required HealthRecordRepository healthRepo, required FamilyRepository familyRepo})
    : _healthRepo = healthRepo,
      _familyRepo = familyRepo,
      super(HealthRecordInitial()) {
    on<HealthRecordInitialLoad>(_onInitialLoad);
    on<HealthRecordRefreshFamilyMembers>(_onRefreshFamilyMembers);
    on<HealthRecordMemberSwitched>(_onMemberSwitched);
    on<HealthRecordFilterChanged>(_onFilterChanged);
    on<HealthRecordSaveRequested>(_onSaveRequested);
    on<HealthRecordDeleteRequested>(_onDeleteRequested);
  }

  // ── Initial Load ─────────────────────────────────────────────────────────

  Future<void> _onInitialLoad(HealthRecordInitialLoad event, Emitter<HealthRecordState> emit) async {
    emit(HealthRecordLoading());
    try {
      final results = await Future.wait([_familyRepo.getFamilyMembers(), _healthRepo.getHealthRecords()]);
      emit(
        HealthRecordLoaded(
          familyMembers: results[0] as List<FamilyMemberModel>,
          allRecords: results[1] as List<HealthRecordModel>,
          selectedFamilyMemberId: null,
        ),
      );
    } catch (e) {
      emit(HealthRecordError(e.toString()));
    }
  }

  // ── Refresh Family Members (called after returning from FamilyAddEditPage) ─

  Future<void> _onRefreshFamilyMembers(
    HealthRecordRefreshFamilyMembers event,
    Emitter<HealthRecordState> emit,
  ) async {
    final current = _resolveLoaded(state);
    if (current == null) return;

    try {
      final freshMembers = await _familyRepo.getFamilyMembers();
      emit(current.copyWith(familyMembers: freshMembers));
    } catch (_) {
      // Silently fail — keep existing list
    }
  }

  // ── Member Switch ─────────────────────────────────────────────────────────

  Future<void> _onMemberSwitched(HealthRecordMemberSwitched event, Emitter<HealthRecordState> emit) async {
    final current = _resolveLoaded(state);
    if (current == null) return;

    // Show switch immediately with empty records
    emit(current.copyWith(selectedFamilyMemberId: event.familyMemberId, allRecords: [], activeFilter: 'all'));

    try {
      final records = await _healthRepo.getHealthRecords(familyMemberId: event.familyMemberId);
      emit(
        current.copyWith(selectedFamilyMemberId: event.familyMemberId, allRecords: records, activeFilter: 'all'),
      );
    } catch (e) {
      emit(HealthRecordError(e.toString()));
    }
  }

  // ── Filter ────────────────────────────────────────────────────────────────

  void _onFilterChanged(HealthRecordFilterChanged event, Emitter<HealthRecordState> emit) {
    final current = _resolveLoaded(state);
    if (current != null) emit(current.copyWith(activeFilter: event.filter));
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _onSaveRequested(HealthRecordSaveRequested event, Emitter<HealthRecordState> emit) async {
    final previous = _resolveLoaded(state);
    emit(HealthRecordSaving(previousLoaded: previous));
    try {
      await _healthRepo.saveHealthRecord(
        familyMemberId: event.familyMemberId,
        recordType: event.recordType,
        recordTitle: event.recordTitle,
        recordDate: event.recordDate,
        hospitalName: event.hospitalName,
        doctorName: event.doctorName,
        notes: event.notes,
        documentFile: event.documentFile,
      );
      final records = await _healthRepo.getHealthRecords(familyMemberId: event.familyMemberId);
      final updatedLoaded = (previous ?? HealthRecordLoaded(familyMembers: [], allRecords: [])).copyWith(
        allRecords: records,
        selectedFamilyMemberId: event.familyMemberId,
      );
      emit(HealthRecordSaveSuccess(updatedLoaded));
    } catch (e) {
      emit(HealthRecordSaveFailure(e.toString(), previousLoaded: previous));
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _onDeleteRequested(HealthRecordDeleteRequested event, Emitter<HealthRecordState> emit) async {
    final current = _resolveLoaded(state);
    if (current == null) return;

    emit(HealthRecordDeleting(deletingId: event.id, previousLoaded: current));
    try {
      await _healthRepo.deleteHealthRecord(id: event.id);
      emit(
        HealthRecordDeleteSuccess(
          current.copyWith(allRecords: current.allRecords.where((r) => r.id != event.id).toList()),
        ),
      );
    } catch (e) {
      emit(HealthRecordDeleteFailure(e.toString(), previousLoaded: current));
    }
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  HealthRecordLoaded? _resolveLoaded(HealthRecordState s) => switch (s) {
    HealthRecordLoaded s => s,
    HealthRecordSaving s => s.previousLoaded,
    HealthRecordSaveSuccess s => s.loaded,
    HealthRecordSaveFailure s => s.previousLoaded,
    HealthRecordDeleting s => s.previousLoaded,
    HealthRecordDeleteSuccess s => s.loaded,
    HealthRecordDeleteFailure s => s.previousLoaded,
    _ => null,
  };
}
