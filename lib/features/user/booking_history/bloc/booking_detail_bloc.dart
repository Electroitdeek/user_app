import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/features/user/payment/data/payment_repository.dart';
import 'package:adhisaat_health_care/features/user/service_booking/data/service_request_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../model/booking_detail_model.dart';

part 'booking_detail_event.dart';
part 'booking_detail_state.dart';

class BookingDetailBloc extends Bloc<BookingDetailEvent, BookingDetailState> {
  final ServiceRequestRepository _repository;
  final PaymentRepository _paymentRepository;
  int? _requestId;

  BookingDetailBloc(this._repository, this._paymentRepository)
      : super(BookingDetailInitial()) {
    on<LoadBookingDetail>(_onLoad);
    on<RefreshBookingDetail>(_onRefresh);
    on<CancelBookingDetail>(_onCancel);
    on<CancelUnpaidBookingDetail>(_onCancelUnpaid);
    on<CancelWithSubBlocks>(_onCancelWithSubBlocks);
  }

  Future<void> _onLoad(LoadBookingDetail event, Emitter<BookingDetailState> emit) async {
    _requestId = event.requestId;
    emit(BookingDetailLoading());
    await _fetch(emit);
  }

  Future<void> _onRefresh(RefreshBookingDetail event, Emitter<BookingDetailState> emit) async {
    if (_requestId == null) return;
    if (state is BookingDetailLoaded) {
      emit(BookingDetailRefreshing(model: (state as BookingDetailLoaded).model));
    }
    await _fetch(emit);
  }

  Future<void> _onCancel(CancelBookingDetail event, Emitter<BookingDetailState> emit) async {
    if (_requestId == null) return;
    final current = state;
    if (current is BookingDetailLoaded) {
      emit(BookingDetailCancelling(model: current.model));
    }
    try {
      final success = await _repository.cancelServiceRequest(_requestId!, reason: event.reason);
      if (success) {
        emit(BookingDetailCancelled());
      } else {
        await _fetch(emit);
      }
    } catch (e) {
      kPrintError('BookingDetailBloc._onCancel: $e');
      await _fetch(emit);
    }
  }

  Future<void> _onCancelUnpaid(CancelUnpaidBookingDetail event, Emitter<BookingDetailState> emit) async {
    if (_requestId == null) return;
    final current = state;
    if (current is BookingDetailLoaded) {
      emit(BookingDetailCancelling(model: current.model));
    }
    try {
      await _paymentRepository.cancelUnpaidBooking(_requestId!);
      emit(BookingDetailCancelled());
    } catch (e) {
      kPrintError('BookingDetailBloc._onCancelUnpaid: $e');
      await _fetch(emit);
    }
  }

  Future<void> _onCancelWithSubBlocks(CancelWithSubBlocks event, Emitter<BookingDetailState> emit) async {
    if (_requestId == null) return;
    final current = state;
    if (current is BookingDetailLoaded) {
      emit(BookingDetailCancelling(model: current.model));
    }
    try {
      final success = await _repository.cancelServiceRequestWithSubBlocks(
        serviceRequestId: _requestId!,
        subBlockIds: event.subBlockIds,
        reason: event.reason,
      );
      if (success) {
        final res = await _repository.getServiceRequestDetailsById(_requestId!);
        if (res['status'] == true && res['data'] != null) {
          final model = BookingDetailModel.fromJson(res);
          emit(BookingDetailSubBlocksCancelled(model: model));
          emit(BookingDetailLoaded(model: model));
          return;
        }
      }
      await _fetch(emit);
    } catch (e) {
      kPrintError('BookingDetailBloc._onCancelWithSubBlocks: $e');
      await _fetch(emit);
    }
  }

  Future<void> _fetch(Emitter<BookingDetailState> emit) async {
    try {
      final res = await _repository.getServiceRequestDetailsById(_requestId!);
      if (res['status'] == true && res['data'] != null) {
        final model = BookingDetailModel.fromJson(res);
        emit(BookingDetailLoaded(model: model));
      } else {
        emit(BookingDetailError(res['message'] as String? ?? 'Failed to load booking details.'));
      }
    } catch (e) {
      kPrintError('BookingDetailBloc._fetch: $e');
      emit(BookingDetailError(e.toString().replaceAll('Exception:', '').trim()));
    }
  }
}
