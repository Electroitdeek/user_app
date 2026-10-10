part of 'health_record_bloc.dart';

sealed class HealthRecordState {}

final class HealthRecordInitial extends HealthRecordState {}

final class HealthRecordLoading extends HealthRecordState {}

final class HealthRecordLoaded extends HealthRecordState {
  final List<FamilyMemberModel> familyMembers;
  final int? selectedFamilyMemberId;
  final List<HealthRecordModel> allRecords;
  final String activeFilter;

  HealthRecordLoaded({
    required this.familyMembers,
    this.selectedFamilyMemberId,
    required this.allRecords,
    this.activeFilter = 'all',
  });

  List<HealthRecordModel> get filteredRecords => activeFilter == 'all'
      ? allRecords
      : allRecords.where((r) => r.recordType == activeFilter).toList();

  FamilyMemberModel? get selectedMember => selectedFamilyMemberId == null
      ? null
      : familyMembers.where((m) => m.id == selectedFamilyMemberId).firstOrNull;

  HealthRecordLoaded copyWith({
    List<FamilyMemberModel>? familyMembers,
    Object? selectedFamilyMemberId = _sentinel,
    List<HealthRecordModel>? allRecords,
    String? activeFilter,
  }) {
    return HealthRecordLoaded(
      familyMembers: familyMembers ?? this.familyMembers,
      selectedFamilyMemberId: selectedFamilyMemberId == _sentinel
          ? this.selectedFamilyMemberId
          : selectedFamilyMemberId as int?,
      allRecords: allRecords ?? this.allRecords,
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }
}

const _sentinel = Object();

final class HealthRecordError extends HealthRecordState {
  final String message;
  HealthRecordError(this.message);
}

// ── Save States ──────────────────────────────────────────────────────────────

final class HealthRecordSaving extends HealthRecordState {
  final HealthRecordLoaded? previousLoaded;
  HealthRecordSaving({this.previousLoaded});
}

final class HealthRecordSaveSuccess extends HealthRecordState {
  final HealthRecordLoaded loaded;
  HealthRecordSaveSuccess(this.loaded);
}

final class HealthRecordSaveFailure extends HealthRecordState {
  final String message;
  final HealthRecordLoaded? previousLoaded;
  HealthRecordSaveFailure(this.message, {this.previousLoaded});
}

// ── Delete States ────────────────────────────────────────────────────────────

final class HealthRecordDeleting extends HealthRecordState {
  final int deletingId;
  final HealthRecordLoaded previousLoaded;
  HealthRecordDeleting({required this.deletingId, required this.previousLoaded});
}

final class HealthRecordDeleteSuccess extends HealthRecordState {
  final HealthRecordLoaded loaded;
  HealthRecordDeleteSuccess(this.loaded);
}

final class HealthRecordDeleteFailure extends HealthRecordState {
  final String message;
  final HealthRecordLoaded previousLoaded;
  HealthRecordDeleteFailure(this.message, {required this.previousLoaded});
}