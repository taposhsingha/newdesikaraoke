/*

import 'flutter_audio_engine_platform_interface.dart';

class FlutterAudioEngine {
  Future<String?> getPlatformVersion() {
    return FlutterAudioEnginePlatform.instance.getPlatformVersion();
  }
}
*/

import 'dart:async';

import 'package:flutter/services.dart';

import 'flutter_audio_engine_platform_interface.dart';

class FlutterAudioEngine {
  static const MethodChannel _channel =
  MethodChannel('flutter_audio_engine');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
  Future<String?> getPlatformVersion() {
    return FlutterAudioEnginePlatform.instance.getPlatformVersion();
  }
}

class AudioEngine {
  static const MethodChannel platform =
  MethodChannel('flutter_audio_engine');
  static const playerStatusChannel = EventChannel("borhnn/playerStatus");
  static const playerPositionChannel =
  const EventChannel("borhnn/playerPosition");

  late Stream<PlayerStatus> _playerStatusStream;
  late Stream<int> _playerPositionStream;

  /*Future stop() async {
    try {
      await platform.invokeMethod("stop");
    } on PlatformException catch (e) {
      print(e.message);
    }
  }*/
  /*AudioEngine() {
    _playerStatusStream = playerStatusChannel
        .receiveBroadcastStream("forStatus")
        .map<PlayerStatus>((value) => fromCode(value));
    // Initialize the `_playerPositionStream` variable in the constructor.
    _playerPositionStream = playerPositionChannel.receiveBroadcastStream("forPosition");
  }*/
  AudioEngine() {
    _playerStatusStream = playerStatusChannel
        .receiveBroadcastStream("forStatus")
        .map<PlayerStatus>((value) => fromCode(value));
    // Initialize the `_playerPositionStream` variable in the constructor.
    _playerPositionStream = playerPositionChannel.receiveBroadcastStream("forPosition").cast<int>();
  }
  Future stop() async {
    if (_playerStatusStream != null) {
      try {
        await platform.invokeMethod("stop");
      } on PlatformException catch (e) {
        print(e.message);
      }
    }
  }

  /*Stream<PlayerStatus> get getPlayerStatusStream {
    return _playerStatusStream ??= playerStatusChannel
        .receiveBroadcastStream("forStatus")
        .map<PlayerStatus>((value) => fromCode(value));
  }*/

  Stream<PlayerStatus> get getPlayerStatusStream {
    return _playerStatusStream;
  }
  Stream<int> get getPlayerPositionStream {
    return _playerPositionStream;
  }
  Future setVolume(double volume) async {
    try {
      await platform.invokeMethod("setVolume", {"volume": volume});
    } on PlatformException catch (e) {
      print(e.message);
    }
  }

  Future<int?> getCurrentPosition() async {
    try {
      int result = await platform.invokeMethod("getCurrentPosition");
      return result;
    } on PlatformException catch (e) {
      print(e.message);
    }
    return null;
  }

  Future<void> initPlayer(String url) async {
    try {
      await platform.invokeMethod('initPlayer', {"fileURL": url});
    } on PlatformException catch (e) {
      print(e.message);
    }
  }

  Future<void> startPlaying() async {
    try {
      await platform.invokeMethod('play');
    } on PlatformException catch (e) {
      print(e.message);
    }
  }

  Future<void> pause() async {
    try {
      await platform.invokeMethod("pause");
    } on PlatformException catch (e) {
      print(e.message);
    }
  }

  Future<void> setPlaybackPitch(int playerHalfstepDelta) async {
    try {
      await platform.invokeMethod(
          "setPlayerPitch", {"halfstepDelta": playerHalfstepDelta});
    } on PlatformException catch (e) {
      print(e.message);
    }
  }

  Future<void> setPlaybackRate(double playbackRate) async {
    try {
      await platform
          .invokeMethod("setPlayerSpeed", {"playbackRate": playbackRate});
    } on PlatformException catch (e) {
      print(e.message);
    }
  }

  Future<void> release() async {
    try {
      await platform.invokeMethod("release");
    } on PlatformException catch (e) {
      print(e.message);
    }
  }
}

enum PlayerStatus {
  NOT_INITIALIZED,
  INITIALIZED,
  READY,
  STOPPED,
  PAUSED,
  RESUMED,
}

PlayerStatus fromCode(status) {
  switch (status) {
    case -4:
      return PlayerStatus.NOT_INITIALIZED;
    case -3:
      return PlayerStatus.INITIALIZED;
    case -2:
      return PlayerStatus.READY;
    case -1:
      return PlayerStatus.STOPPED;
    case 0:
      return PlayerStatus.PAUSED;
    case 1:
      return PlayerStatus.RESUMED;
    default:
      return PlayerStatus.NOT_INITIALIZED;
  }
}
