part of 'provider_notification_bloc.dart';

abstract class ProviderNotificationState {}

class ProviderNotificationInitial extends ProviderNotificationState {}

class ProviderNotificationLoading extends ProviderNotificationState {}

class ProviderNotificationLoaded extends ProviderNotificationState {
  final List<PushNotificationModel> notifications;
  final Set<int> selectedIds;
  final bool isActionLoading; // spinner for mark/clear API call

  ProviderNotificationLoaded({
    required this.notifications,
    this.selectedIds = const {},
    this.isActionLoading = false,
  });

  int get unreadCount => notifications.where((n) => n.isRead == false).length;
  bool get hasUnread => unreadCount > 0;
  bool get hasSelection => selectedIds.isNotEmpty;

  ProviderNotificationLoaded copyWith({
    List<PushNotificationModel>? notifications,
    Set<int>? selectedIds,
    bool? isActionLoading,
  }) => ProviderNotificationLoaded(
    notifications: notifications ?? this.notifications,
    selectedIds: selectedIds ?? this.selectedIds,
    isActionLoading: isActionLoading ?? this.isActionLoading,
  );
}

class ProviderNotificationError extends ProviderNotificationState {
  final String message;
  ProviderNotificationError(this.message);
}