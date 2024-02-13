import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:desi_karaoke_lite/lyricBuilder.dart';
import 'package:desi_karaoke_lite/models.dart';
import 'package:desi_karaoke_lite/widgets/fading_background.dart';
import 'package:desi_karaoke_lite/widgets/spinning_logo.dart';
import 'package:dio/dio.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_audio_engine/flutter_audio_engine.dart';
import 'package:flutter_device_type/flutter_device_type.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flu_wake_lock/flu_wake_lock.dart';
import 'dart:convert';
import 'package:charset/charset.dart';
import 'package:bordered_text/bordered_text.dart';

class KaraokePage extends StatefulWidget {
  final Music music;

  KaraokePage({Key? key, required this.music}) : super(key: key);

  @override
  _KaraokePageState createState() => _KaraokePageState();
}

class _KaraokePageState extends State<KaraokePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Constants
  static const platform =
      const EventChannel('desikaraoke.com/bluetooth_connected_devices');
  /*static const methodChannel =
      const MethodChannel('desikaraoke.com/filedownloader');*/
  static const methodChannel = MethodChannel('desikaraoke.com/filedownloader');
  final double _iconSize = Device.get().isTablet ? 72 : 48;

  // Page fields
  AudioEngine audioEngine = AudioEngine();
   Karaoke _karaoke=Karaoke();
  List<KaraokeDevice> deviceList = [];

  // Disposables
  /*late StreamSubscription subBluetooth;*/

  late StreamSubscription plyerStatusSubscription;
  late StreamSubscription playerPositionSubscription;

  // Page state fields
  PlayerStatus? _playerStatus = PlayerStatus.NOT_INITIALIZED;
  String countDownText = "";
  Widget _lastLyric = RichText(
    text: TextSpan(text: "\n\n"),
  );
  FluWakeLock _fluWakeLock = FluWakeLock();

  // Page state relate fields

  // Tracking fields
  int _playerSpeedStep = 0;
  int _playerHalfstepDelta = 0;
  int _countdownPosition = 0;
  int timediff=0;
  PlayerStatus? statusBeforeBackground;
  bool isFlushbarShown = false;
  int previousEndTime = 0;
  int nextStartTime = 0;

  // Data fields
  late String uid;
  int i=0;
   int _lyricPosition=0;
  bool isMusicTrialExpired = false;
  bool isTrialAccount = false;
  bool isFreeModeEnabled = false;
  int trialMillis = 1000 * 1000;

  var flushbar = Flushbar(
    title: "Microphone required",
    message:
        "Please, connect to a RANGS Desi Karaoke microphone to enjoy the full song",
    mainButton: TextButton(
        child: Text(
          "Call Now",
          style: TextStyle(color: Colors.greenAccent),
        ),
        onPressed: () => launchUrl(Uri.parse('tel://+8801748332274'))),
    duration: Duration(days: 365),
    isDismissible: false,
  );

  Future<File> downloadFile(Reference ref) async {
    final String url = await ref.getDownloadURL();
    // final http.Response downloadData = await http.get(url);
    final Directory systemTempDir = Directory.systemTemp;

    final String name = ref.name;
    final String path = ref.fullPath;
    final File tempFile = File('${systemTempDir.path}/$path');
    if (tempFile.existsSync()) {
      await tempFile.delete();
    }
    await tempFile.create(recursive: true);
    final DownloadTask task = ref.writeToFile(tempFile);
    // final int byteCount = (await task.snapshot).totalByteCount;
    // var bodyBytes = downloadData.bodyBytes;
    print('Success!\nDownloaded $name \nUrl: $url'
        // '\npath: $path \nBytes Count :: $byteCount',
        );
    return tempFile;
  }

  @override
  void initState() {
    super.initState();
    _fluWakeLock.enable();
    WidgetsBinding.instance.addObserver(this);
    Reference storageReference =
        FirebaseStorage.instance.ref().child(widget.music.storagepath);
    Reference lyricReference =
        FirebaseStorage.instance.ref().child(widget.music.lyricref);
    _startDownload(storageReference, lyricReference);

    var stream = audioEngine.getPlayerStatusStream;
    var positionStream = audioEngine.getPlayerPositionStream;
    plyerStatusSubscription = stream.listen((status) {
      setState(() {
        _playerStatus = status;
      });
      if (_playerStatus == PlayerStatus.STOPPED) {
        Navigator.pop(context);
      }
    });
    switch (widget.music.trial) {
      case "none":
        trialMillis = 0;
        break;
      case "short":
        trialMillis = 40 * 1000;
        break;
      case "long":
        trialMillis = 80 * 1000;
        break;
      case "max":
        trialMillis = 8000 * 1000;
        break;
      default:
        trialMillis = 40 * 1000;
    }
    var user = FirebaseAuth.instance.currentUser;
    uid = user!.uid;
    FirebaseDatabase.instance
        .ref()
        .child("users/${user.uid}/currenttime")
        .set(ServerValue.timestamp)
        .whenComplete(() {
      FirebaseDatabase.instance
          .ref()
          .child("users/${user.uid}")
          .once()
          .then((data) {
        int? currentTime;
        try {
          final Map<Object, Object> rawData =
              data.snapshot.value as Map<Object, Object>;
          final Map<String, dynamic> convertedData =
              rawData.cast<String, dynamic>();
          currentTime = convertedData['currenttime'];
        } on Exception catch (e, s) {
          currentTime = null;
          print(s);
        }
        int? signUpTime;
        try {
          final Map<Object, Object> rawData =
              data.snapshot.value as Map<Object, Object>;
          final Map<String, dynamic> convertedData =
              rawData.cast<String, dynamic>();
          currentTime = convertedData['signuptime'];
        } on Exception catch (e, s) {
          currentTime = null;
          print(s);
        }

        if ((currentTime! - signUpTime!) < 72 * 3600 * 1000) {
          setPlaybackValidity(() {
            isTrialAccount = true;
          });
        } else {
          setPlaybackValidity(() {
            isTrialAccount = false;
          });
        }
      });
    });

    // trialMillis = 7000;
    playerPositionSubscription = positionStream.listen((position) {
      var lyricPosition = _karaoke.timedTextMap
          .lastKeyBefore(position - widget.music.lyricoffset);
      if (lyricPosition != _lyricPosition) {
        setState(() {
          if(_karaoke.timedTextMap[lyricPosition]!=null){
            _lastLyric = convertToLyric(_karaoke.timedTextMap[lyricPosition]);
            _lyricPosition = lyricPosition;
          }
        });
      }
      var countdownPosition = _karaoke.countdownTimes.lastKeyBefore(position);
      if (countdownPosition!=null && countdownPosition != _countdownPosition) {
        var countdownTime = _karaoke.countdownTimes[countdownPosition];
        if (countdownTime == null || countdownTime == "null") {
          countDownText = "";
        } else {
          countDownText = countdownTime.toString();
        }
        setState(() {
          _countdownPosition = countdownPosition;
        });
      }
      var musicTrialExpired = position > trialMillis;
      if (musicTrialExpired != isMusicTrialExpired) {
        setPlaybackValidity(() {
          isMusicTrialExpired = musicTrialExpired;
        });
      }
    });
    FirebaseDatabase.instance
        .ref()
        .child("isFreeModeEnabled")
        .once()
        .then((value) {
      setPlaybackValidity(() {
        isFreeModeEnabled = value.snapshot.value as bool;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: "Desi Karaoke",
      home: Container(
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: FadingBackground()),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                  padding: EdgeInsets.only(top: 24, bottom: 16),
                  alignment: Alignment.topCenter,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.black,
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      Hero(
                        tag: widget.music,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            CupertinoButton(
                              padding: EdgeInsets.all(0),
                              child: Icon(CupertinoIcons.back, size: _iconSize),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  widget.music.effectivetitle,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.apply(
                                          color: Colors.white,
                                          fontSizeDelta:
                                              Device.get().isTablet ? 10 : 0),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            Container(width: _iconSize, height: _iconSize),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          widget.music.effectiveartist,
                          style: Theme.of(context).textTheme.titleMedium?.apply(
                              color: Colors.white,
                              fontSizeDelta: Device.get().isTablet ? 8 : 0),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    ],
                  ),
                ),
                Spacer(flex: 3),
                AnimatedOpacity(
                  duration: Duration(milliseconds: 300),
                  opacity: countDownText == "" ? 0 : 1,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Row(
                      children: <Widget>[
                        Container(
                          decoration: BoxDecoration(color: Colors.white70),
                          width: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Center(
                            child: Text(
                              countDownText,
                              style: Theme.of(context)
                                  .textTheme
                                  .displaySmall
                                  ?.apply(
                                    color: Colors.red,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Device.get().isTablet ? 16 : 0,
                  ),
                  child: AnimatedSize(
                    child: Column(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ClipRect(
                            clipBehavior: Clip.hardEdge,
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 0.0,
                                sigmaY: 0.0,
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                child: Container(
                                  /*color: Colors.transparent,*/
                                    color: countDownText == "" ?Colors.transparent: Colors.white54,
                                  padding: const EdgeInsets.all(8.0),
                                  child: _lastLyric,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    duration: Duration(milliseconds: 1200),
                  ),
                ),
                Spacer(flex: 2),
                Container(
                  width: Device.get().isTablet ? 480 : null,
                  decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.all(
                          Radius.circular(Device.get().isTablet ? 16 : 0))),
                  child: Column(
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          CupertinoButton(
                            padding: EdgeInsets.all(8),
                            child: Container(
                              child: getPlayPauseWidget(),
                              width: _iconSize,
                              height: _iconSize,
                            ),
                            onPressed:
                                _playerStatus != PlayerStatus.NOT_INITIALIZED
                                    ? _playPauseOnClick
                                    : null,
                          ),
                          Container(width: 16),
                          CupertinoButton(
                            padding: EdgeInsets.all(8),
                            child: Container(
                              child: Icon(
                                Icons.stop,
                                color: Colors.white,
                                size: _iconSize,
                              ),
                              width: _iconSize,
                              height: _iconSize,
                            ),
                            onPressed: _stopOnClick,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: CupertinoButton.filled(
                                padding: EdgeInsets.symmetric(horizontal: 0),
                                child: Text(
                                  "Tempo" +
                                      (_playerSpeedStep != 0
                                          ? " (" +
                                              _playerSpeedStep.toString() +
                                              ")"
                                          : ""),
                                ),
                                onPressed: () => showModalBottomSheet(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return DiscreteValueChanger(
                                      currentValue: _playerSpeedStep,
                                      valueOnChange: (value) {
                                        setState(() {
                                          _playerSpeedStep = value.toInt();
                                          audioEngine.setPlaybackRate(
                                              getPlaybackRateFromStep(
                                                  _playerSpeedStep));
                                        });
                                      },
                                      title: "Tempo",
                                      maxValue: 12,
                                      minValue: -12,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 25,
                            color: Colors.grey,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: CupertinoButton.filled(
                                padding: EdgeInsets.symmetric(horizontal: 0),
                                child: Text(
                                  "Scale" +
                                      (_playerHalfstepDelta != 0
                                          ? " (" +
                                              _playerHalfstepDelta.toString() +
                                              ")"
                                          : ""),
                                ),
                                onPressed: () => showModalBottomSheet(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return DiscreteValueChanger(
                                      currentValue: _playerHalfstepDelta,
                                      valueOnChange: (value) {
                                        setState(() {
                                          _playerHalfstepDelta = value.toInt();
                                          audioEngine.setPlaybackPitch(
                                              _playerHalfstepDelta);
                                        });
                                      },
                                      title: "Scale",
                                      maxValue: 6,
                                      minValue: -6,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget getPlayPauseWidget() {
    if (_playerStatus == PlayerStatus.NOT_INITIALIZED ||
        _playerStatus == PlayerStatus.INITIALIZED) {
      return CupertinoTheme(
        child: CupertinoActivityIndicator(
          radius: _iconSize / 2 - 8,
        ),
        data: CupertinoThemeData(brightness: Brightness.dark),
      );
    } else {
      return Icon(
        _getPlayPauseIcon(),
        color: Colors.white,
        size: _iconSize,
      );
    }
  }

  IconData _getPlayPauseIcon() {
    var _isPlaying = _playerStatus == PlayerStatus.RESUMED;
    return _isPlaying ? Icons.pause : Icons.play_arrow;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (statusBeforeBackground == PlayerStatus.RESUMED) {
        audioEngine.startPlaying();
      }
      statusBeforeBackground = null;
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (statusBeforeBackground == null) {
        statusBeforeBackground = _playerStatus!;
      }
      audioEngine.pause();
    }
  }

  @override
  void dispose() {
    plyerStatusSubscription.cancel();
    audioEngine.stop();
    playerPositionSubscription.cancel();
    //subBluetooth.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _fluWakeLock.disable();
    super.dispose();
  }

  _startDownload(Reference storageReference, Reference lyricReference) async {
    //String musicDownloadUrl = await storageReference.getDownloadURL();
    String musicDownloadUrl = await methodChannel
        .invokeMethod("getDownloadUrl", {"path": storageReference.fullPath});
    musicDownloadUrl = musicDownloadUrl.replaceAll("(", "%28");
    musicDownloadUrl = musicDownloadUrl.replaceAll(")", "%29");
    musicDownloadUrl = musicDownloadUrl.replaceAll(" ", "%20");
    audioEngine.initPlayer(musicDownloadUrl);

    // const oneMegabyte = 2048 * 2048;
    // final Uint8List? lyricint8 = await lyricReference.getData(oneMegabyte);

    // var bytes = lyricint8;
    // String lyric = "";

    // if (hasUtf16LeBom(bytes!)) {
    //   lyric = Utf16Decoder().decodeUtf16Le(bytes);
    // } else {
    //   lyric = utf8.decode(bytes);
    // }
    // final lyricUrl = await lyricReference.getDownloadURL();

    // final Directory tempDir = await getTemporaryDirectory();
    // final file = File('${tempDir.path}/${lyricReference.name}');

    // await Dio().download(lyricUrl, file);
    final lyricint8 = await getUint8ListFromDownload(lyricReference);
    var bytes = lyricint8;
    String lyric = "";
    if (hasUtf16LeBom(bytes!)) {
      lyric = Utf16Decoder().decodeUtf16Le(bytes);
    } else {
      lyric = utf8.decode(bytes);
    }

    print("============hi==========");
    print(lyric);

    _karaoke = await buildLyric(lyric);
  }

  Future<Uint8List> getUint8ListFromDownload(Reference lyricReference) async {
    // Get the file download URL
    final lyricUrl = await lyricReference.getDownloadURL();

    // Create a temporary directory to store the downloaded file
    final Directory tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/${lyricReference.name}';

    // Download the file to the temporary directory
    await Dio().download(lyricUrl, filePath);

    // Read the downloaded file as bytes
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    // Convert the bytes to a Uint8List
    return Uint8List.fromList(bytes);
  }

  String convertToLyricTemp(KaraokeTimedText karaokeTimedText) {
    StringBuffer stringBuffer = StringBuffer();
    karaokeTimedText.lines?.forEach((KaraokeLine it) {
      it.words.forEach((word) {
        stringBuffer.write("$word ");
      });
      stringBuffer.write("\n");
    });
    return stringBuffer.toString();
  }

  Widget convertToLyric(KaraokeTimedText karaokeTimedText) {
    bool hasText = false;
    List<List<String>> spanText = [
      ["", ""],
      ["", ""]
    ];
    int? hightlightwordNumber =
        karaokeTimedText.lyricHighlightEvent?.wordnumber;

    int highlightLine = 5;
    if (karaokeTimedText.lines != null && karaokeTimedText.lines.isNotEmpty) {
      if (karaokeTimedText.lyricHighlightEvent?.line == karaokeTimedText.lines[0]) {
        highlightLine = 0;
      } else if (karaokeTimedText.lines.length > 1 &&
          karaokeTimedText.lyricHighlightEvent?.line == karaokeTimedText.lines[1]) {
        highlightLine = 1;
      }
    }
    /*if (karaokeTimedText.lyricHighlightEvent?.line ==
        karaokeTimedText.lines[0]) {
      highlightLine = 0;
    } else if (karaokeTimedText.lyricHighlightEvent?.line ==
        karaokeTimedText.lines[1]) {
      highlightLine = 1;
    }*/
    List<Widget> children =[];
    karaokeTimedText.lines.asMap().forEach((lineNum, line) {

     /* nextStartTime = line.startTime!;
       timediff = previousEndTime - nextStartTime;*/
      print("linenum $lineNum");
      print(karaokeLines.length);
      nextStartTime = line.startTime!;

      /*if(timediff>=8000){
        print("startTime $nextStartTime");
        print("endTime $previousEndTime");
        print("timediff $timediff");
        print("Interlude $i");
        i++;
      }*/
      previousEndTime = line.endTime!;
      StringBuffer normalBuffer = StringBuffer();
      StringBuffer highlightBuffer = StringBuffer();
      line.words.asMap().forEach((wordNum, word) {
        if (highlightLine == lineNum && wordNum <= hightlightwordNumber!) {
          highlightBuffer.write("$word ");
        } else {
          normalBuffer.write("$word ");
        }
      });
      spanText[lineNum][0] = highlightBuffer.toString();
      spanText[lineNum][1] = normalBuffer.toString().trimRight();

      String highlightText = spanText[lineNum][0];
      String normalText = spanText[lineNum][1];

      if (highlightText.isNotEmpty || normalText.isNotEmpty) {
        hasText = true;
      }
      print("hasText $hasText");
    });
    if(hasText){
      return Container(
        color: Colors.white54,
        padding: const EdgeInsets.all(8.0),
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
              style: Theme.of(context).textTheme.headlineSmall?.apply(
                  color: Colors.blue[700],
                  fontWeightDelta: 3,
                  fontSizeDelta: Device.get().isTablet ? 25 : 0),
              children: <TextSpan>[
          TextSpan(
              text: "${spanText[0][0]}",
              style: TextStyle(color: Colors.indigo[900])),
    TextSpan(text: "${spanText[0][1]}\n"),
    TextSpan(
    text: "${spanText[1][0]}",
    style: TextStyle(color: Colors.indigo[900])),
    TextSpan(text: "${spanText[1][1]}"),
    ],
    ),
    ));}else{
    return Image.asset("assets/backgrounds/forbgimage.png",width: 200,height: 200);
    }

    /*if(hasText){
      return Stack( children: <Widget>[
        Text(
          "${spanText[0][0]}",
          style: TextStyle(
            fontSize: Device.get().isTablet ? 40 : 30,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = Colors.white,
          ),
        ),
        // Solid text as fill.
        Text(
          "${spanText[0][0]}",
          style: TextStyle(
            fontSize: Device.get().isTablet ? 40 : 30,
            color: Colors.indigo[900],
          ),
        ),
      ],alignment: AlignmentDirectional.center,);
    }else{
      return Image.asset("assets/backgrounds/forbgimage.png",width: 200,height: 200);
    }*/
    /*if(hasText){

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: Theme.of(context).textTheme.headlineSmall?.apply(
            color: Colors.blue[700],
            fontWeightDelta: 3,
            fontSizeDelta: Device.get().isTablet ? 25 : 0),
        children: <TextSpan>[
          TextSpan(
              text: "${spanText[0][0]}",
              style: *//*TextStyle(color: Colors.indigo[900])*//*TextStyle(foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1
                ..color = Colors.white
              )),
          TextSpan(text: "${spanText[0][1]}\n"),
          TextSpan(
              text: "${spanText[1][0]}",
              style: TextStyle(color: Colors.indigo[900])),
          TextSpan(text: "${spanText[1][1]}"),
        ],
      ),
    );}else{
      return Image.asset("assets/backgrounds/forbgimage.png",width: 200,height: 200);
    }*/
    /*return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: Theme.of(context).textTheme.headlineSmall?.apply(
            color: Colors.blue[700],
            fontWeightDelta: 3,
            fontSizeDelta: Device.get().isTablet ? 25 : 0),
        children: <TextSpan>[
          TextSpan(
              text: "${spanText[0][0]}",
              style: TextStyle(color: Colors.indigo[900])),
          TextSpan(text: "${spanText[0][1]}\n"),
          TextSpan(
              text: "${spanText[1][0]}",
              style: TextStyle(color: Colors.indigo[900])),
          TextSpan(text: "${spanText[1][1]}"),
        ],
      ),
    );*/
  }

  void _playPauseOnClick() {
    if (_playerStatus == PlayerStatus.RESUMED) {
      audioEngine.pause();
    } else {
      audioEngine.startPlaying();
    }
  }

  void _stopOnClick() {
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('playHistory')
        .doc()
        .set({
      'timestamp': FieldValue.serverTimestamp(),
      'musicKey': widget.music.key,
      'playDurationMiliSec': _lyricPosition,
      'title': widget.music.effectivetitle,
      'artist': widget.music.artist,
      'genre': widget.music.genre,
      'language': widget.music.language,
    });
    Navigator.pop(context);
  }

  double getPlaybackRateFromStep(int playBackStep) {
    return (1.0 + .05 * _playerSpeedStep);
  }

  void setPlaybackValidity(VoidCallback fn) {
    fn();
    var shouldPlayLoud =
        isTrialAccount || !isMusicTrialExpired || isFreeModeEnabled;

    switch (shouldPlayLoud) {
      case false:
        if (!isFlushbarShown) {
          isFlushbarShown = true;
          flushbar.show(context);
        }
        break;
      default:
        if (isFlushbarShown) {
          isFlushbarShown = false;
          flushbar.dismiss();
        }
    }
    audioEngine.setVolume(shouldPlayLoud ? 1.0 : 0.0);
  }
}

class DiscreteValueChanger extends StatefulWidget {
  final Function? valueOnChange;
  final int? currentValue;
  final String title;
  final int? minValue;
  final int? maxValue;
  final int? divisions;
  final bool disabled;

  DiscreteValueChanger(
      {Key? key,
      this.valueOnChange,
      this.currentValue,
      required this.title,
      this.minValue,
      this.maxValue,
      bool? disabled})
      : this.divisions = maxValue! - minValue!,
        this.disabled = disabled ?? false,
        super(key: key);

  @override
  _DiscreetValueChangerState createState() => _DiscreetValueChangerState();
}

class _DiscreetValueChangerState extends State<DiscreteValueChanger> {
  late double _newValue;

  get newValue => _newValue;

  set newValue(newValue) {
    if (!widget.disabled &&
        newValue >= widget.minValue &&
        newValue <= widget.maxValue) {
      _newValue = newValue;
      widget.valueOnChange!(_newValue);
    }
  }

  @override
  void initState() {
    _newValue = widget.currentValue!.toDouble();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 480,
      padding: EdgeInsets.only(left: 16, right: 16, bottom: 32, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Center(
              child: Text(widget.title,
                  style: Theme.of(context).textTheme.titleLarge)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(newValue.toInt().toString()),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              CupertinoButton(
                child: Icon(CupertinoIcons.minus_circled),
                onPressed: () => setState(() => newValue--),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  child: CupertinoSlider(
                    onChanged: (double value) {
                      setState(() {
                        newValue = value;
                      });
                    },
                    onChangeEnd: (value) {
                      setState(() {
                        newValue = value.toInt().toDouble();
                      });
                    },
                    value: newValue,
                    min: widget.minValue!.toDouble(),
                    max: widget.maxValue!.toDouble(),
                    divisions: widget.divisions,
                  ),
                ),
              ),
              CupertinoButton(
                child: Icon(CupertinoIcons.add_circled),
                onPressed: () => setState(() => newValue++),
              ),
            ],
          ),
          Container(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: !widget.disabled
                  ? null
                  : Text("Not available for this song",
                      textAlign: TextAlign.end)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              CupertinoButton(
                child: Text("Cancel"),
                onPressed: () {
                  widget.valueOnChange!(widget.currentValue);
                  Navigator.pop(context);
                },
              ),
              CupertinoButton(
                child: Text("Done"),
                onPressed: () {
                  widget.valueOnChange!(newValue);
                  Navigator.pop(context);
                },
              ),
            ],
          )
        ],
      ),
    );
  }
}
