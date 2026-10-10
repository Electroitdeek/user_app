part of 'health_record_bloc.dart';

sealed class HealthRecordEvent {}

/// Initial load: fetches family members + self records in parallel
final class HealthRecordInitialLoad extends HealthRecordEvent {
  HealthRecordInitialLoad();
}

/// Called when user returns from FamilyAddEditPage to refresh member list
final class HealthRecordRefreshFamilyMembers extends HealthRecordEvent {

  HealthRecordRefreshFamilyMembers();
}

/// User taps a family member tab
final class HealthRecordMemberSwitched extends HealthRecordEvent {
  final int? familyMemberId; // null = self / "Me"
  HealthRecordMemberSwitched({this.familyMemberId});
}

/// Change the active record-type filter chip
final class HealthRecordFilterChanged extends HealthRecordEvent {
  final String filter;

  HealthRecordFilterChanged(this.filter);
}

/// Save a new health record
final class HealthRecordSaveRequested extends HealthRecordEvent {
  final int? familyMemberId;
  final String recordType;
  final String recordTitle;
  final String recordDate;
  final String? hospitalName;
  final String? doctorName;
  final String? notes;
  final File? documentFile;

  HealthRecordSaveRequested({
    this.familyMemberId,
    required this.recordType,
    required this.recordTitle,
    required this.recordDate,
    this.hospitalName,
    this.doctorName,
    this.notes,
    this.documentFile,
  });
}

/// Delete an existing health record
final class HealthRecordDeleteRequested extends HealthRecordEvent {
  final int id;
  final int? familyMemberId;

  HealthRecordDeleteRequested({required this.id, this.familyMemberId});
}
