import 'dart:io';
import 'dart:math';
import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'storage_service.dart';

/// A stable per-device identifier used to stop one phone claiming the
/// welcome gift repeatedly with different accounts.
///  - Android: ANDROID_ID (survives uninstall/reinstall, resets on factory reset)
///  - iOS: identifierForVendor
///  - Fallback: a random id saved in secure storage
/// The ids are namespaced so they never collide across sources.
class DeviceIdService {
  static String? _cached;
  static const _fallbackKey = 'device_fallback_id';

  static Future<String> get() async {
    if (_cached != null) return _cached!;
    String? id;
    try {
      if (Platform.isAndroid) {
        final a = await const AndroidId().getId();
        if (a != null && a.isNotEmpty) id = 'and-$a';
      } else if (Platform.isIOS) {
        final v = (await DeviceInfoPlugin().iosInfo).identifierForVendor;
        if (v != null && v.isNotEmpty) id = 'ios-$v';
      }
    } catch (_) {}

    if (id == null) {
      var f = await StorageService.read(_fallbackKey);
      if (f == null || f.isEmpty) {
        final r = Random.secure();
        f = List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
        await StorageService.write(_fallbackKey, f);
      }
      id = 'gen-$f';
    }
    return _cached = id;
  }
}
