import 'package:flutter/services.dart';

class DeviceControls {
  static const MethodChannel _channel = MethodChannel(
    'com.myagent.tools/system',
  );

  static Future<bool> setDoNotDisturb({required int durationMinutes}) async {
    try {
      final bool result = await _channel.invokeMethod('enableDnd', {
        'duration': durationMinutes,
      });
      return result;
    } on PlatformException catch (e) {
      print('Failed to enable DND: ${e.message}');
      return false;
    }
  }

  static Future<void> requestDndPermission() async {
    try {
      await _channel.invokeMethod('requestDndPermission');
    } on PlatformException catch (e) {
      print('Failed to request DND permission: ${e.message}');
    }
  }

  static Future<bool> toggleFlashlight({required bool enable}) async {
    try {
      final bool result = await _channel.invokeMethod('toggleFlashlight', {
        'enable': enable,
      });
      return result;
    } on PlatformException catch (e) {
      print('Failed to toggle flashlight: ${e.message}');
      return false;
    }
  }

  static Future<bool> setVolume({required int volumePercent}) async {
    try {
      final bool result = await _channel.invokeMethod('setVolume', {
        'volumePercent': volumePercent,
      });
      return result;
    } on PlatformException catch (e) {
      print('Failed to set volume: ${e.message}');
      return false;
    }
  }
}
