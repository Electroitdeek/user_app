import 'package:adhisaat_health_care/data/models/push_notification_model.dart';
import 'package:adhisaat_health_care/data/repositories/notification_repository.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'provider_notification_event.dart';
part 'provider_notification_state.dart';

class ProviderNotificationBloc
    extends Bloc<ProviderNotificationEvent, ProviderNotificationState> {
  final NotificationRepository _repo;

  ProviderNotificationBloc(this._repo) : super(ProviderNotificationInitial()) {
    on<FetchProviderNotifications>(_onFetch);
    on<MarkAsReadEvent>(_onMarkAsRead);
    on<MarkAllAsReadEvent>(_onMarkAllAsRead);
    on<ClearNotificationsEvent>(_onClear);
    on<ToggleSelectNotificationEvent>(_onToggleSelect);
    on<ClearSelectionEvent>(_onClearSelection);
  }

  /// Syncs the iOS app-icon badge to the given unread count (0 = clear).
  static Future<void> syncBadge(int unreadCount) async {
    try {
      if (unreadCount <= 0) {
        await AwesomeNotifications().resetGlobalBadge();
      } else {
        await AwesomeNotifications().setGlobalBadgeCounter(unreadCount);
      }
    } catch (_) {}
  }

  Future<void> _onFetch(FetchProviderNotifications e, Emitter emit) async {
    emit(ProviderNotificationLoading());
    try {
      final list = await _repo.getPushNotifications();
      emit(ProviderNotificationLoaded(notifications: list));
      // Sync badge with actual unread count from server
      final unread = list.where((n) => n.isRead == false).length;
      await syncBadge(unread);
    } catch (e) {
      emit(ProviderNotificationError(e.toString()));
    }
  }

  Future<void> _onMarkAsRead(MarkAsReadEvent e, Emitter emit) async {
    if (state is! ProviderNotificationLoaded) return;
    final s = state as ProviderNotificationLoaded;
    emit(s.copyWith(isActionLoading: true, selectedIds: {}));
    await _repo.markAsRead(e.ids);
    // Optimistically update local state
    final updated = s.notifications.map((n) {
      if (e.ids.contains(n.id)) {
        return PushNotificationModel(
          id: n.id, userId: n.userId, notificationType: n.notificationType,
          title: n.title, message: n.message, data: n.data,
          isRead: true, readAt: n.readAt, sentVia: n.sentVia, createdAt: n.createdAt,
        );
      }
      return n;
    }).toList();
    // Update badge to remaining unread count
    final remaining = updated.where((n) => n.isRead == false).length;
    await syncBadge(remaining);
    emit(ProviderNotificationLoaded(notifications: updated));
  }

  Future<void> _onMarkAllAsRead(MarkAllAsReadEvent e, Emitter emit) async {
    if (state is! ProviderNotificationLoaded) return;
    final s = state as ProviderNotificationLoaded;
    final unreadIds = s.notifications
        .where((n) => n.isRead == false && n.id != null)
        .map((n) => n.id!)
        .toList();
    if (unreadIds.isEmpty) return;
    emit(s.copyWith(isActionLoading: true));
    await _repo.markAsRead(unreadIds);
    final updated = s.notifications.map((n) => PushNotificationModel(
      id: n.id, userId: n.userId, notificationType: n.notificationType,
      title: n.title, message: n.message, data: n.data,
      isRead: true, readAt: n.readAt, sentVia: n.sentVia, createdAt: n.createdAt,
    )).toList();
    // All read — clear the badge
    await syncBadge(0);
    emit(ProviderNotificationLoaded(notifications: updated));
  }

  Future<void> _onClear(ClearNotificationsEvent e, Emitter emit) async {
    if (state is! ProviderNotificationLoaded) return;
    final s = state as ProviderNotificationLoaded;
    final idsToRemove = e.ids.isEmpty
        ? s.notifications.where((n) => n.id != null).map((n) => n.id!).toList()
        : e.ids;
    emit(s.copyWith(isActionLoading: true, selectedIds: {}));
    await _repo.clearNotifications(idsToRemove);
    final updated = s.notifications.where((n) => !idsToRemove.contains(n.id)).toList();
    // Sync badge after clear
    final remaining = updated.where((n) => n.isRead == false).length;
    await syncBadge(remaining);
    emit(ProviderNotificationLoaded(notifications: updated));
  }

  void _onToggleSelect(ToggleSelectNotificationEvent e, Emitter emit) {
    if (state is! ProviderNotificationLoaded) return;
    final s = state as ProviderNotificationLoaded;
    final newSet = Set<int>.from(s.selectedIds);
    if (newSet.contains(e.id)) {
      newSet.remove(e.id);
    } else {
      newSet.add(e.id);
    }
    emit(s.copyWith(selectedIds: newSet));
  }

  void _onClearSelection(ClearSelectionEvent e, Emitter emit) {
    if (state is! ProviderNotificationLoaded) return;
    emit((state as ProviderNotificationLoaded).copyWith(selectedIds: {}));
  }
}