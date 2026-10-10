part of 'notification_bloc.dart';

abstract class NotificationState {}

class NotificationInitial extends NotificationState {}

class NotificationLoading extends NotificationState {}

class NotificationLoaded extends NotificationState {
  final List<PushNotificationModel> notifications;
  final bool isActionLoading;
  
  NotificationLoaded(this.notifications, {this.isActionLoading = false});
  
  int get unreadCount => notifications.where((n) => n.isRead == false).length;

  NotificationLoaded copyWith({
    List<PushNotificationModel>? notifications,
    bool? isActionLoading,
  }) {
    return NotificationLoaded(
      notifications ?? this.notifications,
      isActionLoading: isActionLoading ?? this.isActionLoading,
    );
  }
}

class NotificationError extends NotificationState {
  final String message;
  NotificationError(this.message);
}
