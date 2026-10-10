class FeedbackModel {
  final int id;
  final int? customerProfileId;
  final int serviceProviderId;
  final int rating;
  final String feedbackText;
  final String feedbackType;
  final String createdAt;

  FeedbackModel({
    required this.id,
    this.customerProfileId,
    required this.serviceProviderId,
    required this.rating,
    required this.feedbackText,
    required this.feedbackType,
    required this.createdAt,
  });

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    return FeedbackModel(
      id: json['id'],
      customerProfileId: json['customer_profile_id'],
      serviceProviderId: json['service_provider_id'],
      rating: json['rating'],
      feedbackText: json['feedback_text'] ?? '',
      feedbackType: json['feedback_type'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_profile_id': customerProfileId,
      'service_provider_id': serviceProviderId,
      'rating': rating,
      'feedback_text': feedbackText,
      'feedback_type': feedbackType,
      'created_at': createdAt,
    };
  }
}

class FeedbackResponse {
  final bool status;
  final String message;
  final List<FeedbackModel> data;

  FeedbackResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory FeedbackResponse.fromJson(Map<String, dynamic> json) {
    var list = json['data'];
    List<FeedbackModel> feedbackList = [];
    if (list is List) {
      feedbackList = list.map((i) => FeedbackModel.fromJson(i)).toList();
    } else if (list is Map<String, dynamic>) {
       feedbackList = [FeedbackModel.fromJson(list)];
    }
    
    return FeedbackResponse(
      status: json['status'] ?? false,
      message: json['message'] ?? '',
      data: feedbackList,
    );
  }
}
