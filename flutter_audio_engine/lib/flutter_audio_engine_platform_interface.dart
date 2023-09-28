import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_audio_engine_method_channel.dart';

abstract class FlutterAudioEnginePlatform extends PlatformInterface {
  /// Constructs a FlutterAudioEnginePlatform.
  FlutterAudioEnginePlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterAudioEnginePlatform _instance = MethodChannelFlutterAudioEngine();

  /// The default instance of [FlutterAudioEnginePlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterAudioEngine].
  static FlutterAudioEnginePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterAudioEnginePlatform] when
  /// they register themselves.
  static set instance(FlutterAudioEnginePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
