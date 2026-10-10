import 'package:adhisaat_health_care/core/storage/local_storage_service.dart';
import 'package:uuid/uuid.dart';

import '../../di/locator.dart';

class DeviceService {
  static Future<String> getPersistentDeviceId() async {
    final storage = locator<LocalStorageService>();

    // 1. Try to fetch the existing ID from secure storage
    String? deviceId = await storage.getDeviceId();

    if (deviceId == null) {
      // 2. If it doesn't exist, generate a new one
      deviceId = const Uuid().v4(); // Generates a random unique ID

      // 3. Save it securely so it's the same next time
      await storage.saveDeviceId(deviceId);
    }

    return deviceId;
  }
}
