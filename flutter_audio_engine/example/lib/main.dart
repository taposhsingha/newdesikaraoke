/*
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_audio_engine/flutter_audio_engine.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final _flutterAudioEnginePlugin = FlutterAudioEngine();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion =
          await _flutterAudioEnginePlugin.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Text('Running on: $_platformVersion\n'),
        ),
      ),
    );
  }
}
*/

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_audio_engine/flutter_audio_engine.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int currentPosition = 0;
  var currentStatus;
  late StreamSubscription statusSub;
  late StreamSubscription positionSub;
  late AudioEngine? audioEngine;
  var url =
      "https://firebasestorage.googleapis.com/v0/b/desikaraoke-staging.appspot.com/o/music%2FAbdul%20Hadi%20Achen%20Amar%20Muktar.mp3?alt=media&token=2e48aa4c-4877-401f-a022-4645fd3a9cf2";

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    positionSub.cancel();
    statusSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(children: <Widget>[
            Row(
              children: <Widget>[
                Column(
                  children: <Widget>[
                    const Text("Player Position"),
                    Text(currentPosition.toString()),
                  ],
                ),
                Column(
                  children: <Widget>[
                    const Text("Player Status"),
                    Text(currentStatus.toString())
                  ],
                )
              ],
            ),
            Wrap(
              direction: Axis.horizontal,
              children: <Widget>[
                MaterialButton(
                  child: const Text("Create"),
                  onPressed: () => audioEngine = AudioEngine(),
                ),
                MaterialButton(
                  child: const Text("getStream"),
                  onPressed: () {
                    positionSub =
                        audioEngine?.getPlayerPositionStream.listen((data) {
                          setState(() {
                            currentPosition = data;
                          });
                        }) as StreamSubscription;
                    statusSub =
                        audioEngine?.getPlayerStatusStream.listen((data) {
                          setState(() {
                            currentStatus = data;
                          });
                        }) as StreamSubscription;
                  },
                ),
                MaterialButton(
                  child: const Text("Init"),
                  onPressed: () => audioEngine?.initPlayer(url),
                ),
                MaterialButton(
                    child: const Text("Play"),
                    onPressed: () {
                      audioEngine?.startPlaying();
                    }),
                MaterialButton(
                  child: const Text("Pause"),
                  onPressed: () => audioEngine?.pause(),
                ),
                MaterialButton(
                  child: const Text("Stop"),
                  onPressed: () => audioEngine?.stop(),
                ),
                MaterialButton(
                  child: const Text("Release"),
                  onPressed: () => audioEngine?.release(),
                ),
                MaterialButton(
                  child: const Text("Nullify"),
                  onPressed: () => audioEngine = null,
                )
              ],
            ),
          ]),
        ),
      ),
    );
  }
}
