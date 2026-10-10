import 'package:adhisaat_health_care/data/models/push_notification_model.dart';
import 'package:adhisaat_health_care/data/repositories/notification_repository.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'notification_event.dart';
part 'notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationRepository repository;

  NotificationBloc({required this.repository}) : super(NotificationInitial()) {
    on<FetchNotificationsEvent>(_onFetchNotifications);
    on<MarkAsReadEvent>(_onMarkAsRead);
    on<MarkAllAsReadEvent>(_onMarkAllAsRead);
  }

  /// Syncs the iOS app-icon badge to match the current unread count.
  /// Passing 0 (or calling after all are read) fully removes the badge.
  static Future<void> syncBadge(int unreadCount) async {
    try {
      if (unreadCount <= 0) {
        await AwesomeNotifications().resetGlobalBadge();
      } else {
        await AwesomeNotifications().setGlobalBadgeCounter(unreadCount);
      }
    } catch (_) {}
  }

  Future<void> _onFetchNotifications(FetchNotificationsEvent event, Emitter<NotificationState> emit) async {
    if (!event.isSilent) emit(NotificationLoading());
    try {
      final notifications = await repository.getPushNotifications();
      emit(NotificationLoaded(notifications));
      // Sync badge with actual unread count from server
      final unread = notifications.where((n) => n.isRead == false).length;
      await syncBadge(unread);
    } catch (e) {
      emit(NotificationError(e.toString()));
    }
  }

  Future<void> _onMarkAsRead(MarkAsReadEvent event, Emitter<NotificationState> emit) async {
    if (state is! NotificationLoaded) return;
    final s = state as NotificationLoaded;
    
    // Optimistically update local state
    final updated = s.notifications.map((n) {
      if (event.ids.contains(n.id)) {
        return PushNotificationModel(
          id: n.id,
          userId: n.userId,
          notificationType: n.notificationType,
          title: n.title,
          message: n.message,
          data: n.data,
          isRead: true,
          readAt: n.readAt,
          sentVia: n.sentVia,
          createdAt: n.createdAt,
        );
      }
      return n;
    }).toList();
    
    emit(s.copyWith(notifications: updated));
    // Update badge to remaining unread count
    final remaining = updated.where((n) => n.isRead == false).length;
    await syncBadge(remaining);
    
    await repository.markAsRead(event.ids);
  }

  Future<void> _onMarkAllAsRead(MarkAllAsReadEvent event, Emitter<NotificationState> emit) async {
    if (state is! NotificationLoaded) return;
    final s = state as NotificationLoaded;
    
    final unreadIds = s.notifications
        .where((n) => n.isRead == false && n.id != null)
        .map((n) => n.id!)
        .toList();
        
    if (unreadIds.isEmpty) return;
    
    // Optimistically update local state
    final updated = s.notifications.map((n) => PushNotificationModel(
      id: n.id,
      userId: n.userId,
      notificationType: n.notificationType,
      title: n.title,
      message: n.message,
      data: n.data,
      isRead: true,
      readAt: n.readAt,
      sentVia: n.sentVia,
      createdAt: n.createdAt,
    )).toList();
    
    emit(s.copyWith(notifications: updated, isActionLoading: true));
    // All read — clear the badge
    await syncBadge(0);
    
    await repository.markAsRead(unreadIds);
    emit(s.copyWith(notifications: updated, isActionLoading: false));
  }
}
