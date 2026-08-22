import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceInfo {
  final String id;
  final String name;

  DeviceInfo({required this.id, required this.name});
}

class DeviceService {
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  static Future<DeviceInfo> getDeviceInfo() async {
    try {
      if (kIsWeb) {
        final webInfo = await _deviceInfoPlugin.webBrowserInfo;
        final browserName = webInfo.browserName.name;
        final userAgent = webInfo.userAgent ?? 'Web';
        final webId = 'web_${userAgent.hashCode.abs()}';
        return DeviceInfo(id: webId, name: 'Browser ($browserName)');
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        return DeviceInfo(
          id: androidInfo.id,
          name: '${androidInfo.manufacturer} ${androidInfo.model}',
        );
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        return DeviceInfo(
          id: iosInfo.identifierForVendor ?? 'ios_unknown',
          name: iosInfo.name,
        );
      } else if (Platform.isWindows) {
        final winInfo = await _deviceInfoPlugin.windowsInfo;
        return DeviceInfo(id: winInfo.deviceId, name: 'Windows PC');
      } else if (Platform.isMacOS) {
        final macInfo = await _deviceInfoPlugin.macOsInfo;
        return DeviceInfo(id: macInfo.systemGUID ?? 'mac_unknown', name: 'MacBook');
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }

    return DeviceInfo(id: 'unknown_device_id', name: 'Unknown Device');
  }
}