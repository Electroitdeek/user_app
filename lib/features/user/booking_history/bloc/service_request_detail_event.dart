part of 'service_request_detail_bloc.dart';

abstract class ServiceRequestDetailEvent {}

class LoadServiceRequestDetail extends ServiceRequestDetailEvent {
  final int? requestId;
  final int? bookingId;

  LoadServiceRequestDetail({this.bookingId,this.requestId});
}

class CancelDetailServiceRequest extends ServiceRequestDetailEvent {
  final int requestId;
  final String? reason;
  CancelDetailServiceRequest(this.requestId, {this.reason});
}

class RefreshServiceRequestDetail extends ServiceRequestDetailEvent {}

class CancelSubBlock extends ServiceRequestDetailEvent {
  final int subBlockId;
  final String? reason;
  CancelSubBlock(this.subBlockId, {this.reason});
}
