import 'package:adhisaat_health_care/data/models/dropdown_response_model.dart';

abstract class DropdownState {}

class DropdownInitial extends DropdownState {}

class DropdownLoading extends DropdownState {}

class DropdownLoaded extends DropdownState {
  final DropdownData data;

  DropdownLoaded(this.data);
}

class DropdownError extends DropdownState {
  final String message;

  DropdownError(this.message);
}
