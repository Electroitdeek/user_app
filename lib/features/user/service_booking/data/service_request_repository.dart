import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/api/api_endpoints.dart';
import 'package:adhisaat_health_care/features/user/service_booking/data/service_category_repository.dart';

import '../model/booking_model.dart';
import '../model/service_request_model.dart';

class ServiceRequestRepository {
  final ApiClient _apiClient;

  ServiceRequestRepository(this._apiClient);

  /// Creates a new service request. Returns the created request data.
  Future<Map<String, dynamic>> createServiceRequest(BookingRequest request) async {
    try {
      final rateCard = request.serviceType?.rateCard;

      // For long_duration, end_date comes from rangeEnd (already in request.endDate).
      // For procedural, backend expects same-day or +durationDays-1.
      final isLongDuration = request.bookingType == 'long_duration';
      final hasScheduledDates = request.scheduledDates?.isNotEmpty == true;
      String endDate;
      if (isLongDuration || hasScheduledDates) {
        // Long duration or alternate/weekly procedural: endDate is the last actual service day.
        endDate = _formatDate(request.endDate ?? request.startDate);
      } else {
        final durationDays = request.durationDays ?? 1;
        endDate = request.startDate != null
            ? _formatDate(request.startDate!.add(Duration(days: durationDays - 1)))
            : _formatDate(request.endDate ?? request.startDate);
      }

      final serviceKey = int.tryParse('${rateCard?.serviceId ?? request.serviceType?.id ?? ''}') ?? 0;
      final serviceId = await resolveCatalogMongoId(_apiClient, serviceKey);
      if (serviceId == null || serviceId.isEmpty) {
        throw Exception('Open this service from the home list, then book it again.');
      }
      final pin = (request.pinCode ?? '').trim();
      if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
        throw Exception('Add a 6-digit pin code on this address.');
      }
      final coverage = await _apiClient.get(ApiEndpoints.checkServiceAvailability, query: {'pincode': pin});
      final coverageData = coverage is Map ? coverage['data'] : null;
      final city = coverageData is Map ? coverageData['city'] : null;
      final cityId = city is Map ? city['id']?.toString() ?? '' : '';
      if (cityId.isEmpty) {
        throw Exception('This pin code is not in a working city.');
      }
      final start = _formatDate(request.startDate);
      final dates = (request.scheduledDates != null && request.scheduledDates!.isNotEmpty)
          ? request.scheduledDates!
          : [start];
      final response = await _apiClient.post(ApiEndpoints.bookings, {
        'serviceId': serviceId,
        'cityId': cityId,
        'pincode': pin,
        'address': ((request.address ?? '').trim().length > 300)
            ? (request.address ?? '').trim().substring(0, 300)
            : (request.address ?? '').trim(),
        'bookingType': isLongDuration ? 'LONG_DURATION' : 'PROCEDURAL',
        'bookingRequestType': 'NORMAL',
        'genderPreference': 'NO',
        'bookingFor': request.familyMemberName == null || request.familyMemberName!.isEmpty ? 'SELF' : 'FAMILY',
        'bookingForName': request.familyMemberName ?? '',
        'scheduledDate': start,
        'scheduledDates': dates,
        'scheduledTime': _formatTime(request.startTime).isEmpty ? '09:00' : _formatTime(request.startTime),
        'hours': isLongDuration ? null : ((request.durationHours ?? 1).clamp(1, 144)),
        'days': isLongDuration ? ((request.durationDays ?? dates.length).clamp(1, 365)) : null,
        'shift': isLongDuration ? _apiShift(request.shiftType) : '',
        'notes': request.instructions ?? '',
        'endDate': endDate,
      });
      final booking = response is Map && response['data'] is Map ? (response['data'] as Map)['booking'] : null;
      if (booking is! Map) {
        throw Exception('Booking was not created.');
      }
      final row = Map<String, dynamic>.from(booking);
      final pricing = row['pricing'] is Map ? Map<String, dynamic>.from(row['pricing'] as Map) : const <String, dynamic>{};
      return {
        'success': true,
        'status': true,
        'data': {
          'service_request': {
            'id': rememberCatalogId(row['id']?.toString() ?? ''),
            'request_number': row['number']?.toString(),
          },
          'total_amount': pricing['total'],
          'base_price': pricing['actualPrice'],
          'gst_amount': pricing['gstAmount'],
        },
      };
    } catch (e) {
      kPrintError('ServiceRequestRepository.createServiceRequest: $e');
      rethrow;
    }
  }

  /// Creates a new emergency service request. Returns the created request data.
  Future<Map<String, dynamic>> createEmergencyServiceRequest(
    BookingRequest request, {
    required int radiusKm,
    int? serviceRequestId,
  }) async {
    try {
      final isDailyService = request.mode == "daily";
      String? calculatedEndDate;
      if (isDailyService) {
        int durationDays = request.durationDays ?? 1;
        calculatedEndDate = request.startDate != null
            ? _formatDate(request.startDate!.add(Duration(days: durationDays - 1)))
            : null;
      }

      // Default end time to 2 hours after start time if not provided
      String startTime = request.startTime ?? '09:00';
      String endTime = request.endTime ?? startTime;
      if (request.endTime == null && request.startTime != null) {
        try {
          final parts = startTime.split(':');
          final hour = int.parse(parts[0]);
          final newHour = (hour + 2) % 24;
          endTime = "${newHour.toString().padLeft(2, '0')}:${parts[1]}";

          // If the hour wrapped around (e.g., 23:00 -> 01:00), we need to increment the end_date
          if (newHour < hour) {
            final baseEndDate = request.endDate ?? request.startDate ?? DateTime.now();
            // If we already calculated an end date (for daily services), increment that.
            // Otherwise, increment the base start/end date.
            final DateTime dateToIncrement = (isDailyService && calculatedEndDate != null)
                ? DateTime.parse(calculatedEndDate)
                : baseEndDate;
            calculatedEndDate = _formatDate(dateToIncrement.add(const Duration(days: 1)));
          }
        } catch (_) {}
      }

      final data = <String, dynamic>{
        if (serviceRequestId != null) 'service_request_id': serviceRequestId.toString(),
        'city_admin_id': (request.serviceType?.cityAdminId)?.toString() ?? '2',
        'family_member_id': request.familyMemberId?.toString() ?? '',
        'service_procedure_id': request.serviceType?.id.toString() ?? '',
        'gender_preference': request.genderPreference ?? 'all',
        'service_mode': request.serviceMode ?? 'live_in',
        'service_type': 'emergency', // Set explicitly to emergency as per CURL
        'start_date': _formatDate(request.startDate),
        'start_time': _formatTime(startTime),
        'end_date': calculatedEndDate ?? _formatDate(request.endDate ?? request.startDate),
        'end_time': _formatTime(endTime),
        'duration_hours': request.durationHours?.toString() ?? '2',
        'duration_days': request.durationDays?.toString() ?? '',
        'shift_type': request.shiftType ?? 'day',
        'special_instructions': request.instructions ?? '',
        'address_id': request.addressId?.toString() ?? '',
        'full_address': request.address ?? '',
        'city': request.city ?? '',
        'latitude': request.latitude?.toString() ?? '0',
        'longitude': request.longitude?.toString() ?? '0',
        'search_radius_km': radiusKm.toString(),
      };

      final response = await _apiClient.postMultipart(ApiEndpoints.createEmergencyServiceRequest, data);
      return response as Map<String, dynamic>;
    } catch (e) {
      kPrintError('ServiceRequestRepository.createEmergencyServiceRequest: $e');
      rethrow;
    }
  }

  /// Returns cancellation preview. Pass [subBlockIds] for specific sessions; omit or pass [] for full cancellation.
  Future<Map<String, dynamic>> getCancellationPreview(
    int serviceRequestId, {
    List<int> subBlockIds = const [],
  }) async {
    try {
      final response = await _apiClient.post(ApiEndpoints.cancellationPreview, {
        'service_request_id': serviceRequestId,
        'sub_block_ids': subBlockIds,
      });
      return response as Map<String, dynamic>;
    } catch (e) {
      kPrintError('ServiceRequestRepository.getCancellationPreview: $e');
      rethrow;
    }
  }

  /// Gets list of service requests for the logged-in user with optional filters + pagination.
  Future<ServiceRequestsResponse> getServiceRequests({
    int page = 1,
    int perPage = 10,
    String? status, // e.g. 'accepted', 'in_progress', 'cancelled'
    String? search,
  }) async {
    try {
      final response = await _apiClient.get(ApiEndpoints.bookings);
      final data = response is Map ? response['data'] : null;
      final rows = data is Map && data['bookings'] is List ? data['bookings'] as List : const [];
      final wanted = (status ?? '')
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet();
      final query = (search ?? '').trim().toLowerCase();
      final requests = rows.whereType<Map>().map((row) {
        return ServiceRequestModel.fromJson(_legacyBooking(Map<String, dynamic>.from(row)));
      }).where((item) {
        if (wanted.isNotEmpty && !wanted.contains(item.status)) return false;
        if (query.isEmpty) return true;
        final number = item.requestNumber?.toLowerCase() ?? '';
        final name = item.service?.name.toLowerCase() ?? '';
        return number.contains(query) || name.contains(query);
      }).toList();
      return ServiceRequestsResponse(
        success: true,
        requests: requests,
        total: requests.length,
        currentPage: page,
        perPage: perPage,
        lastPage: 1,
      );
    } catch (e) {
      kPrintError('ServiceRequestRepository.getServiceRequests: $e');
      rethrow;
    }
  }

  /// Gets details of a specific service request.
  Future<Map<String, dynamic>> getServiceRequestDetails({int? requestId, int? bookingId}) async {
    try {
      return await _bookingDetails(requestId ?? bookingId);
    } catch (e) {
      kPrintError('ServiceRequestRepository.getServiceRequestDetails: $e');
      rethrow;
    }
  }

  /// Gets full detail of a single sub-block (session) including provider + booking.
  Future<Map<String, dynamic>> getSubBlockDetail(int subBlockId) async {
    try {
      final response = await _apiClient.postMultipart(ApiEndpoints.subBlockDetail, {
        'sub_block_id': subBlockId.toString(),
      });
      return response as Map<String, dynamic>;
    } catch (e) {
      kPrintError('ServiceRequestRepository.getSubBlockDetail: $e');
      rethrow;
    }
  }

  /// Cancels specific sub-blocks with reason. Posts to /service-requests-cancel
  /// (no request ID in path — service_request_id is a form field).
  Future<bool> cancelServiceRequestWithSubBlocks({
    required int serviceRequestId,
    required List<int> subBlockIds,
    String? reason,
  }) async {
    try {
      final fallback = subBlockIds.isEmpty ? null : 'Cancelled ${subBlockIds.length} session(s)';
      return await cancelServiceRequest(serviceRequestId, reason: reason ?? fallback);
    } catch (e) {
      kPrintError('ServiceRequestRepository.cancelServiceRequestWithSubBlocks: $e');
      rethrow;
    }
  }

  /// Gets details of a specific service request using GET (ID in path).
  Future<Map<String, dynamic>> getServiceRequestDetailsById(int requestId) async {
    try {
      return await _bookingDetails(requestId);
    } catch (e) {
      kPrintError('ServiceRequestRepository.getServiceRequestDetailsById: $e');
      rethrow;
    }
  }

  /// Cancels a single scheduled sub-block. Uses same cancel endpoint as full booking
  /// but includes [subBlockId] as a form field.
  Future<bool> cancelSubBlock(int requestId, int subBlockId, {String? reason}) async {
    try {
      return await cancelServiceRequest(requestId, reason: reason ?? 'Cancelled session $subBlockId');
    } catch (e) {
      kPrintError('ServiceRequestRepository.cancelSubBlock: $e');
      rethrow;
    }
  }

  /// Cancels a full service request with an optional [reason].
  Future<bool> cancelServiceRequest(int requestId, {String? reason}) async {
    try {
      final mongoId = await resolveCatalogMongoId(_apiClient, requestId);
      if (mongoId == null || mongoId.isEmpty) return false;
      final response = await _apiClient.post('${ApiEndpoints.bookings}/$mongoId/cancel', {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      });
      final resMap = response as Map<String, dynamic>;
      return resMap['success'] == true || resMap['status'] == true;
    } catch (e) {
      kPrintError('ServiceRequestRepository.cancelServiceRequest: $e');
      rethrow;
    }
  }

  /// Cancels an unpaid booking (pre-payment cancellation).
  Future<void> cancelUnpaidBooking(int requestId) async {
    try {
      await cancelServiceRequest(requestId, reason: 'Cancelled before payment');
    } catch (e) {
      kPrintError('ServiceRequestRepository.cancelUnpaidBooking: $e');
    }
  }

  Future<Map<String, dynamic>> _bookingDetails(int? requestId) async {
    final mongoId = requestId == null ? null : await resolveCatalogMongoId(_apiClient, requestId);
    if (mongoId == null || mongoId.isEmpty) {
      return {'success': false, 'status': false, 'message': 'Booking was not found.'};
    }
    final response = await _apiClient.get('${ApiEndpoints.bookings}/$mongoId');
    final data = response is Map ? response['data'] : null;
    final booking = data is Map ? data['booking'] : null;
    if (booking is! Map) {
      return {'success': false, 'status': false, 'message': 'Booking was not found.'};
    }
    return {
      'success': true,
      'status': true,
      'data': {
        'service_request': _legacyBooking(Map<String, dynamic>.from(booking)),
        'service_request_responses': <Map<String, dynamic>>[],
      },
    };
  }

  static String _apiShift(String? shift) {
    switch ((shift ?? '').toLowerCase()) {
      case 'night':
      case 'night_shift':
        return 'NIGHT';
      case 'full':
      case '24':
      case '24_hours':
        return 'FULL';
      default:
        return 'DAY';
    }
  }

  static String _appStatus(String? status) {
    switch (status) {
      case 'COMPLETED':
        return 'completed';
      case 'CANCELLED':
        return 'cancelled';
      case 'HOLD':
        return 'searching';
      default:
        return 'accepted';
    }
  }

  static Map<String, dynamic> _legacyBooking(Map<String, dynamic> booking) {
    final pricing = booking['pricing'] is Map ? Map<String, dynamic>.from(booking['pricing'] as Map) : const <String, dynamic>{};
    final id = rememberCatalogId(booking['id']?.toString() ?? '');
    final serviceId = rememberCatalogId(booking['serviceId']?.toString() ?? '');
    final due = booking['paymentDue'];
    final total = pricing['total'];
    final paidAmount = booking['paymentPaid'];
    final paid = due is num
        ? due <= 0
        : !(total is num && total > 0 && (paidAmount is! num || paidAmount < total));
    final emergency = booking['bookingRequestType']?.toString() == 'EMERGENCY';
    final longDuration = booking['bookingType']?.toString() == 'LONG_DURATION';
    final hours = booking['hours'];
    final days = booking['days'];
    return {
      'id': id,
      'request_number': booking['number']?.toString() ?? '',
      'request_status': _appStatus(booking['status']?.toString()),
      'status': _appStatus(booking['status']?.toString()),
      'service_type': longDuration ? 'long_duration' : 'procedural',
      'service_type_text': longDuration ? 'Long duration' : 'Procedural',
      'service_mode': 'home_visit',
      'service_mode_text': 'Home visit',
      'shift_type': booking['shift']?.toString(),
      'start_date': booking['scheduledDate']?.toString() ?? '',
      'start_date_text': booking['scheduledDate']?.toString() ?? '',
      'start_time': booking['scheduledTime']?.toString(),
      'start_time_text': booking['scheduledTime']?.toString() ?? '',
      'end_date': booking['endDate']?.toString() ?? '',
      'end_date_text': booking['endDate']?.toString() ?? '',
      'duration_hours': hours is num ? hours.toInt() : int.tryParse(hours?.toString() ?? ''),
      'duration_days': days is num ? days.toInt() : int.tryParse(days?.toString() ?? ''),
      'full_address': booking['address']?.toString() ?? '',
      'city': booking['cityName']?.toString() ?? '',
      'special_instructions': booking['notes']?.toString(),
      'is_emergency': emergency ? 1 : 0,
      'base_price': pricing['actualPrice'] ?? 0,
      'total_amount': pricing['total'] ?? 0,
      'paid_amount': booking['paymentPaid'] ?? 0,
      'discount_amount': pricing['discountAmount'] ?? 0,
      'gst_amount': pricing['gstAmount'] ?? 0,
      'payment_status': paid ? 'paid' : 'pending',
      'payment_status_text': paid ? 'Paid' : 'Pending',
      'created_at': booking['createdAt']?.toString() ?? '',
      'service': {
        'id': serviceId,
        'name': booking['serviceTitle']?.toString() ?? '',
        'service_category_id': serviceId,
        'is_emergency': emergency,
      },
    };
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Normalises time strings to HH:mm — strips seconds if present ("08:00:00" → "08:00").
  static String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '';
    final parts = time.split(':');
    if (parts.length >= 2) return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    return time;
  }
}
