import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_audio_engine_platform_interface.dart';

/// An implementation of [FlutterAudioEnginePlatform] that uses method channels.
class MethodChannelFlutterAudioEngine extends FlutterAudioEnginePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_audio_engine');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
