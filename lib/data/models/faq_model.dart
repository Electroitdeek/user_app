class FaqResponse {
  final bool success;
  final String message;
  final List<FaqData> data;
  final Map<String, String> faqCategories;

  FaqResponse({
    required this.success,
    required this.message,
    required this.data,
    required this.faqCategories,
  });

  factory FaqResponse.fromJson(Map<String, dynamic> json) {
    return FaqResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: (json['data'] as List? ?? []).map((e) => FaqData.fromJson(e)).toList(),
      faqCategories: Map<String, String>.from(json['faqCategories'] ?? {}),
    );
  }
}

class FaqData {
  final int id;
  final int cityAdminId;
  final String category;
  final String question;
  final String answer;
  final int displayOrder;
  final bool isActive;
  final String updatedAt;

  FaqData({
    required this.id,
    required this.cityAdminId,
    required this.category,
    required this.question,
    required this.answer,
    required this.displayOrder,
    required this.isActive,
    required this.updatedAt,
  });

  factory FaqData.fromJson(Map<String, dynamic> json) {
    return FaqData(
      id: json['id'] ?? 0,
      cityAdminId: json['city_admin_id'] ?? 0,
      category: json['category'] ?? '',
      question: json['question'] ?? '',
      answer: json['answer'] ?? '',
      displayOrder: json['display_order'] ?? 0,
      isActive: json['is_active'] == true || json['is_active'] == 1,
      updatedAt: json['updated_at'] ?? '',
    );
  }
}
