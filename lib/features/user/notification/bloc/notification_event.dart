part of 'notification_bloc.dart';

abstract class NotificationEvent {}

class FetchNotificationsEvent extends NotificationEvent {
  final bool isSilent;
  FetchNotificationsEvent({this.isSilent = false});
}

class MarkAsReadEvent extends NotificationEvent {
  final List<int> ids;
  MarkAsReadEvent(this.ids);
}

class MarkAllAsReadEvent extends NotificationEvent {}
