import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_audio_engine/flutter_audio_engine.dart';
import 'package:flutter_audio_engine/flutter_audio_engine_platform_interface.dart';
import 'package:flutter_audio_engine/flutter_audio_engine_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterAudioEnginePlatform
    with MockPlatformInterfaceMixin
    implements FlutterAudioEnginePlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterAudioEnginePlatform initialPlatform = FlutterAudioEnginePlatform.instance;

  test('$MethodChannelFlutterAudioEngine is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterAudioEngine>());
  });

  test('getPlatformVersion', () async {
    FlutterAudioEngine flutterAudioEnginePlugin = FlutterAudioEngine();
    MockFlutterAudioEnginePlatform fakePlatform = MockFlutterAudioEnginePlatform();
    FlutterAudioEnginePlatform.instance = fakePlatform;

    expect(await flutterAudioEnginePlugin.getPlatformVersion(), '42');
  });
}
