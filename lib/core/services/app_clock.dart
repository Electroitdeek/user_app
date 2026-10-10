import 'package:adhisaat_health_care/core/api/api_client.dart';

/// App-wide "now" corrected for the difference between the device clock and
/// the last known server time, so a user-changed device date/time doesn't
/// break session expiry/time-lock checks that compare against `DateTime.now()`.
///
/// The correction is just a display/UX safeguard against an honestly wrong
/// device clock — it is refreshed opportunistically whenever an API response
/// happens to carry `server_time` (e.g. `check-service-availability`), so it
/// can go stale between syncs. Anything that gates money (cancellation
/// windows, no-show billing) must still be enforced by the backend.
class AppClock {
  Duration _offset = Duration.zero;

  // Server only ever reports times in this fixed (non-DST) IANA zone.
  static const _knownOffsets = <String, Duration>{'Asia/Kolkata': Duration(hours: 5, minutes: 30)};

  DateTime get now => DateTime.now().add(_offset);

  /// [currentDateTime] is a naive "yyyy-MM-dd HH:mm:ss" string in [timezone].
  void syncFromServerTime({required String currentDateTime, required String timezone}) {
    final naive = DateTime.tryParse(currentDateTime);
    final tzOffset = _knownOffsets[timezone];
    if (naive == null || tzOffset == null) return;

    final serverInstant = DateTime.utc(
      naive.year,
      naive.month,
      naive.day,
      naive.hour,
      naive.minute,
      naive.second,
    ).subtract(tzOffset);

    _offset = serverInstant.difference(DateTime.now());
    kPrint('AppClock: synced, device offset = $_offset');
  }
}
