import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/api/api_endpoints.dart';

class RatingRepository {
  final ApiClient _apiClient;

  RatingRepository(this._apiClient);

  /// Submits a rating for a completed booking.
  Future<bool> submitRating({
    required int bookingId,
    required int rating, // 1-5
    int? bookingSubBlockId,
    String? feedbackComment,
    int? punctualityRating,
    int? behaviorRating,
    int? skillRating,
    bool isComplaint = false,
    String? complaintType,
    String? complaintSubject,
    String? complaintDescription,
    String? status,
    String? priority,
  }) async {
    try {
      final data = <String, dynamic>{
        'booking_id': bookingId.toString(),
        'rating': rating.toString(),
        if (bookingSubBlockId != null) 'booking_sub_block_id': bookingSubBlockId.toString(),
        'feedback_comment': ?feedbackComment,
        if (punctualityRating != null) 'punctuality_rating': punctualityRating.toString(),
        if (behaviorRating != null) 'behavior_rating': behaviorRating.toString(),
        if (skillRating != null) 'skill_rating': skillRating.toString(),
        'is_complaint': isComplaint ? '1' : '0',
        'complaint_type': ?complaintType,
        'complaint_subject': ?complaintSubject,
        'complaint_description': ?complaintDescription,
        if (isComplaint) 'status': status ?? 'open',
        if (isComplaint) 'priority': priority ?? 'low',
      };

      final response = await _apiClient.postMultipart(ApiEndpoints.submitRating, data);
      final json = response as Map<String, dynamic>;
      return json['status'] == true;
    } catch (e) {
      kPrintError('RatingRepository.submitRating: $e');
      rethrow;
    }
  }
}
