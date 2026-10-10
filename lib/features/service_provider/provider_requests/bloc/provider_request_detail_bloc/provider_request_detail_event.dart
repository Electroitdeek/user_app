part of 'provider_request_detail_bloc.dart';

abstract class ProviderRequestDetailEvent {}

class LoadProviderRequestDetail extends ProviderRequestDetailEvent {
  final int? requestId;
  final int? bookingId;

  LoadProviderRequestDetail({this.requestId, this.bookingId});
}

class RefreshProviderRequestDetail extends ProviderRequestDetailEvent {}

class AcceptProviderRequest extends ProviderRequestDetailEvent {
  final int requestId;
  final List<int> subBlockIds;
  AcceptProviderRequest({required this.requestId, this.subBlockIds = const []});
}

class RejectProviderRequest extends ProviderRequestDetailEvent {
  final int requestId;
  RejectProviderRequest({required this.requestId});
}

class StartServiceRequest extends ProviderRequestDetailEvent {
  final int requestId;
  final double? checkinLatitude;
  final double? checkinLongitude;

  StartServiceRequest({
    required this.requestId,
    this.checkinLatitude,
    this.checkinLongitude,
  });
}

