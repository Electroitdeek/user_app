part of 'provider_notification_bloc.dart';

abstract class ProviderNotificationEvent {}

class FetchProviderNotifications extends ProviderNotificationEvent {}

class MarkAsReadEvent extends ProviderNotificationEvent {
  final List<int> ids;
  MarkAsReadEvent(this.ids);
}

class MarkAllAsReadEvent extends ProviderNotificationEvent {}

class ClearNotificationsEvent extends ProviderNotificationEvent {
  final List<int> ids; // empty = clear all
  ClearNotificationsEvent(this.ids);
}

class ToggleSelectNotificationEvent extends ProviderNotificationEvent {
  final int id;
  ToggleSelectNotificationEvent(this.id);
}

class ClearSelectionEvent extends ProviderNotificationEvent {}