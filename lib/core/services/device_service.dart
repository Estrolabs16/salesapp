import 'package:device_info_plus/device_info_plus.dart';

class DeviceService {
  DeviceService._();

  static Future<String> deviceId() async {
    try {
      final info = DeviceInfoPlugin();
      final ios = await info.iosInfo;
      final id = ios.identifierForVendor ?? '';
      if (id.isNotEmpty) return id;
    } catch (_) {
      // Not running on iOS or the identifier is unavailable.
    }
    try {
      final info = DeviceInfoPlugin();
      final android = await info.androidInfo;
      if (android.id.isNotEmpty) return android.id;
    } catch (_) {
      // Not running on Android.
    }
    return '';
  }
}
