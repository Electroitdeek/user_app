import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/api/api_endpoints.dart';
import 'package:adhisaat_health_care/core/api/app_exception.dart';
import 'package:adhisaat_health_care/core/constants/app_constants.dart';
import 'package:adhisaat_health_care/core/constants/error_constants.dart';
import 'package:adhisaat_health_care/data/models/push_notification_model.dart';
import 'package:dio/dio.dart';

class NotificationRepository {
  final ApiClient _apiClient;

  NotificationRepository(this._apiClient);

  Future<List<PushNotificationModel>> getPushNotifications() async {
    try {
      final appType = AppConstants.isProviderApp ? 'provider' : 'customer';
      final response = await _apiClient.get(ApiEndpoints.pushNotifications, query: {"send_to": appType});
      if (response != null && response['success'] == true) {
        final pushResponse = PushNotificationResponse.fromJson(response);
        return pushResponse.data ?? [];
      }
      return [];
    } on AppException catch (e) {
      throw AppException(e.toString());
    } catch (e) {
      throw AppException(ErrorConstants.defaultError);
    }
  }

  // ── Mark specific notifications as read ──────────────────────
  // POST multipart: type="mark_as_read", notification_ids[]=111, ...
  Future<bool> markAsRead(List<int> ids) async {
    try {
      final formData = FormData.fromMap({
        'type': 'mark_as_read',
        'notification_ids[]': ids.map((e) => e.toString()).toList(),
      });
      final response = await _apiClient.postMultipart(
        ApiEndpoints.pushNotificationsResponse,
        {},
        formData: formData,
      );
      return response?['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // ── Clear (delete) specific notifications ────────────────────
  // POST multipart: type="clear", notification_ids[]=111, ...
  Future<bool> clearNotifications(List<int> ids) async {
    try {
      final formData = FormData.fromMap({
        'type': 'clear',
        'notification_ids[]': ids.map((e) => e.toString()).toList(),
      });
      final response = await _apiClient.postMultipart(
        ApiEndpoints.pushNotificationsResponse,
        {},
        formData: formData,
      );
      return response?['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // ── Mark ALL unread as read ──────────────────────────────────
  Future<bool> markAllAsRead(List<PushNotificationModel> notifications) async {
    final unread = notifications.where((n) => n.isRead == false && n.id != null).map((n) => n.id!).toList();
    if (unread.isEmpty) return true;
    return markAsRead(unread);
  }
}
