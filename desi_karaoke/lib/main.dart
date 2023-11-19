import 'dart:async';
import 'dart:collection';

import 'package:connectivity/connectivity.dart';
import 'package:desi_karaoke_lite/KaraokePage.dart';
import 'package:desi_karaoke_lite/LoginScreen.dart';
import 'package:desi_karaoke_lite/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart' hide PhoneAuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/loc_str.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upgrader/upgrader.dart';
import 'firebase_options.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'models.dart';

const NO_CONNECTION = "No Connection";
const CONNECTION_TIMEOUT = "Connection timed out";
const GOOGLE_CLIENT_ID =
    '837759484127-orc1b2i495rq62s4i1gab2dfjblcbetp.apps.googleusercontent.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseUIAuth.configureProviders([
    PhoneAuthProvider(),
    GoogleProvider(clientId: GOOGLE_CLIENT_ID),
  ]);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) async {
    await Firebase.initializeApp();
    runApp(MyApp());
  });
  // runApp(MyApp());
}
/*void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) async {
    await Firebase.initializeApp();
    runApp(MyApp());
  });
  // runApp(MyApp());
}*/

class ConnectivityException implements Exception {
  String code;

  ConnectivityException(this.code);
}

enum NavigationItem {
  home,
  artist,
  favorite,
  genre,
  language,
}

/// This Widget is the main application widget.
class MyApp extends StatelessWidget {
  static const String _title = 'Desi Karaoke';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: [
        LocStr.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      title: _title,
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = NavigationItem.home.index;
  String? _selectedItem;

  late SearchDelegate _searchDelegate;

  List<Music> items = List.empty(growable: true);
  List<Music> favoriteMusic = List.empty(growable: true);
  List<String> favoriteKeyList = List.empty(growable: true);

  late SharedPreferences prefs;
  static const TextStyle optionStyle =
      TextStyle(fontSize: 30, fontWeight: FontWeight.bold);

  void unselectItem() {
    setState(() {
      _selectedItem = null;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _selectedItem = null;
    });
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: 1)).then((onValue) {
      var currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        Navigator.of(context).pushReplacement(FadeRoute(page: LoginScreen()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RANGS DESI KARAOKE'),
        leading: Visibility(
          visible: _selectedItem != null,
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios),
            onPressed: unselectItem,
          ),
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(CupertinoIcons.search),
            onPressed: ()  {

              _searchDelegate =  MusicSearchDelegate(
                  items, _openKaraokePage, buildNavItem,
                  prefs: prefs);
              print("=============THIS GOING ON=============");
              print(_searchDelegate);
              showSearch(context: context, delegate: _searchDelegate);
            },
          ),
          PopupMenuButton<String>(
            onSelected: handleClick,
            itemBuilder: (BuildContext context) {
              return {
                'Song Request',
                'Feedback',
              }.map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: UpgradeAlert(
        child: Center(
          child: FutureBuilder(
            future: buildThen(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                if (snapshot.error is TimeoutException) {
                  return InkWell(
                    onTap: () {
                      setState(() {});
                    },
                    child: Text("Could not load data\nTap to try again",
                        textAlign: TextAlign.center),
                  );
                } else if (snapshot.error is ConnectivityException) {
                  return InkWell(
                      onTap: () {
                        setState(() {});
                      },
                      child: Text(LocStr.of(context)!.helloWorld));
                } else {
                  //print(snapshot.error);
                  return InkWell(
                      onTap: () {
                        setState(() {});
                      },
                      child: Text("Error occured\nPlease retry"));
                }
              }
              switch (snapshot.connectionState) {
                case ConnectionState.none:
                  return CircularProgressIndicator();
                case ConnectionState.waiting:
                  return CircularProgressIndicator();
                case ConnectionState.active:
                  return CircularProgressIndicator();
                case ConnectionState.done:
                  return buildNavItem();
              }
              return CircularProgressIndicator();
            },
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: (_selectedIndex == NavigationItem.artist.index)
                ? Icon(CupertinoIcons.person_solid)
                : Icon(CupertinoIcons.person),
            label: 'Artist',
          ),
          BottomNavigationBarItem(
            icon: (_selectedIndex == NavigationItem.favorite.index)
                ? Icon(CupertinoIcons.heart_solid, color: Colors.redAccent)
                : Icon(CupertinoIcons.heart),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: (_selectedIndex == NavigationItem.genre.index)
                ? Icon(CupertinoIcons.collections_solid)
                : Icon(CupertinoIcons.collections),
            label: 'Genre',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.language),
            label: 'Language',
          ),
        ],
        // Syncronize with [NavigationItem] enum
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent[700],
        onTap: _onItemTapped,
      ),
    );
  }

  Future<void> buildThen() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      throw ConnectivityException(NO_CONNECTION);
    }
    if (items.isNotEmpty) {
      return;
    } else {
      DatabaseReference musicDataRef =
          FirebaseDatabase.instance.ref().child("music");
      FirebaseDatabase.instance.setPersistenceEnabled(true);
      FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10000000);
      musicDataRef.keepSynced(true);
      await musicDataRef
          .once()
          .timeout(Duration(seconds: 30),
              onTimeout: () => throw TimeoutException(CONNECTION_TIMEOUT))
          .then((DatabaseEvent event) async {
        /*if (prefs == null) {
          prefs = await SharedPreferences.getInstance();
        }*/
        prefs = await SharedPreferences.getInstance();
        favoriteKeyList =
            prefs.getStringList(SharedPreferencesKeys.FAVORITES) ??
                List<String>.empty(growable: true);
        List<Music> list = <Music>[];
        favoriteMusic.clear();
        (event.snapshot.value as Map).forEach((key, value) {
          Music music = Music.fromMap(value);
          music.key = key;
          if (favoriteKeyList.contains(key)) {
            music.isFavorite = true;
          }
          list.add(music);
        });
        items.clear();
        items.addAll(list);
        items.sort((a, b) => a.effectivetitle.compareTo(b.effectivetitle));
      });
    }
  }

  /* Future buildThen() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      throw ConnectivityException(NO_CONNECTION);
    }
    if (items.isNotEmpty) {
      return;
    } else {
      DatabaseReference musicDataRef =
      FirebaseDatabase.instance.reference().child("music");
      FirebaseDatabase.instance.setPersistenceEnabled(true);
      FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10000000);
      musicDataRef.keepSynced(true);
      await musicDataRef
          .once()
          .timeout(Duration(seconds: 30),
          onTimeout: () => throw TimeoutException(CONNECTION_TIMEOUT))
          .then((DataSnapshot data) async {
        if (prefs == null) {
          prefs = await SharedPreferences.getInstance();
        }
        favoriteKeyList =
            prefs.getStringList(SharedPreferencesKeys.FAVORITES) ??
                List<String>();
        List<Music> list = new List();
        if (favoriteKeyList != null) {
          favoriteMusic.clear();
        }
        data.value.forEach(
              (key, value) {
            Music music = Music.fromMap(value);
            music.key = key;
            if (favoriteKeyList != null && favoriteKeyList.contains(key)) {
              music.isFavorite = true;
            }
            list.add(music);
          },
        );
        items.clear();
        items.addAll(list);
        items.sort((a, b) => a.effectivetitle.compareTo(b.effectivetitle));
      });
    }
  }*/

  /*Future buildThen() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      throw ConnectivityException(NO_CONNECTION);
    }
    if (items.isNotEmpty) {
      return;
    } else {
      DatabaseReference musicDataRef =
          FirebaseDatabase.instance.ref().child("music");
      FirebaseDatabase.instance.setPersistenceEnabled(true);
      FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10000000);
      musicDataRef.keepSynced(true);
      await musicDataRef
          .once()
          .timeout(Duration(seconds: 30),
              onTimeout: () => throw TimeoutException(CONNECTION_TIMEOUT))
          .then((DataSnapshot data) async {
            if (prefs == null) {
              prefs = await SharedPreferences.getInstance();
            }
            favoriteKeyList =
                prefs.getStringList(SharedPreferencesKeys.FAVORITES) ??
                    List<String>.empty();
            List<Music> list = new List.empty();
            if (favoriteKeyList != null) {
              favoriteMusic.clear();
            }
            */ /*Map<dynamic, dynamic> musicData =
            data.value as Map<dynamic, dynamic>;*/ /*
            Map<String, dynamic> musicData = data.value as Map<String, dynamic>;
            musicData.forEach(
                  (key, value) {
                Music music = Music.fromMap(value);
                music.key = key;
                if (favoriteKeyList != null && favoriteKeyList.contains(key)) {
                  music.isFavorite = true;
                }
                list.add(music);
              },
            );
            */ /*Map<dynamic, dynamic> musicData =
                data.value as Map<dynamic, dynamic>;
            musicData.forEach(
              (key, value) {
                Music music = Music.fromMap(value);
                music.key = key;
                if (favoriteKeyList != null && favoriteKeyList.contains(key)) {
                  music.isFavorite = true;
                }
                list.add(music);
              },
            );*/ /*
            items.clear();
            items.addAll(list);
            items.sort((a, b) => a.effectivetitle.compareTo(b.effectivetitle));
          } as FutureOr Function(DatabaseEvent value));
    }
  }*/

  StatelessWidget buildNavItem([String? filter]) {
    if (_selectedIndex == NavigationItem.home.index) {
      var list = items.where((music) => music.language == "Bangla").toList();
      if (filter != null) {
        list = filterAndSort(list, filter);
      }
      return ListView.builder(
        itemCount: list.length,
        itemBuilder: (context, index) {
          return MusicTile(
            music: list[index],
            onTap: _openKaraokePage,
            prefs: prefs,
          );
        },
      );
    } else if (_selectedIndex == NavigationItem.artist.index) {
      if (_selectedItem != null) {
        var list = items.where((item) {
          return item.effectiveartist == _selectedItem &&
              item.language == "Bangla";
        }).toList();
        if (filter != null) {
          list = filterAndSort(list, filter);
        }
        return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              return MusicTile(
                music: list[index],
                onTap: _openKaraokePage,
                prefs: prefs,
              );
            });
      } else {
        SplayTreeSet<Artist> artistList = new SplayTreeSet();
        items.where((songs) => songs.language == "Bangla").forEach((item) {
          artistList.add(Artist.fromMusic(item));
        });

        if (filter != null) {
          var filterOutList =
              artistList.where((artist) => !artist.contains(filter)).toSet();
          artistList.removeAll(filterOutList);
        }

        List countList = [];
        artistList.toList().asMap().forEach((index, value) {
          var count = items
              .where((element) =>
                  element.artist == value.artist &&
                  element.language == 'Bangla')
              .length;
          countList.add(count);
        });
        return ListView.builder(
          itemCount: artistList.length,
          itemBuilder: (context, index) {
            return ItemTile(
              title: artistList.elementAt(index).effectiveartist,
              onTap: _setSelectItem,
              icon: Icons.person,
              count: countList.elementAt(index),
            );
          },
        );
      }
    } else if (_selectedIndex == NavigationItem.genre.index) {
      if (_selectedItem != null) {
        var list = items.where((item) => item.genre == _selectedItem).toList();
        if (filter != null) {
          list = filterAndSort(list, filter);
        }
        return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              return MusicTile(
                music: list[index],
                onTap: _openKaraokePage,
                prefs: prefs,
              );
            });
      } else {
        SplayTreeSet<String> genreList = new SplayTreeSet();
        items.forEach((item) {
          genreList.add(item.genre);
        });

        List countList = [];
        genreList.toList().asMap().forEach((index, value) {
          var count = items.where((element) => element.genre == value).length;
          countList.add(count);
        });

        if (filter != null) {
          genreList = filterItems(genreList, filter);
        }
        return ListView.builder(
          itemCount: genreList.length,
          itemBuilder: (context, index) {
            return ItemTile(
              title: genreList.elementAt(index),
              onTap: _setSelectItem,
              icon: Icons.library_music,
              count: countList.elementAt(index),
            );
          },
        );
      }
    } else if (_selectedIndex == NavigationItem.language.index) {
      if (_selectedItem != null) {
        var list =
            items.where((item) => item.language == _selectedItem).toList();
        if (filter != null) {
          list = filterAndSort(list, filter);
        }
        return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              return MusicTile(
                music: list[index],
                onTap: _openKaraokePage,
                prefs: prefs,
              );
            });
      } else {
        SplayTreeSet<String> languageList = new SplayTreeSet();
        items.forEach((item) {
          languageList.add(item.language);
        });

        List countList = [];
        languageList.toList().asMap().forEach((index, value) {
          var count =
              items.where((element) => element.language == value).length;
          countList.add(count);
        });

        if (filter != null) {
          languageList = filterItems(languageList, filter);
        }
        return ListView.builder(
          itemCount: languageList.length,
          itemBuilder: (context, index) {
            return ItemTile(
              title: languageList.elementAt(index),
              onTap: _setSelectItem,
              icon: Icons.language,
              count: countList.elementAt(index),
            );
          },
        );
      }
    } else if (_selectedIndex == NavigationItem.favorite.index) {
      var list =
          items.where((music) => music.isFavorite).toList(growable: true);
      if (filter != null) {
        list = filterAndSort(list, filter);
      }
      return ListView.builder(
        itemCount: list.length,
        itemBuilder: (BuildContext context, int index) {
          return MusicTile(
            music: list[index],
            onTap: _openKaraokePage,
            prefs: prefs,
          );
        },
      );
    } else
      return Text("Comming soon");
  }

  SplayTreeSet<String> filterItems(SplayTreeSet<String> items, String query) {
    var itemSet = SplayTreeSet<String>();
    itemSet.addAll(items.where((item) =>
        item.toLowerCase().trim().contains(query.toLowerCase().trim())));
    return itemSet;
  }

  List<Music> filterAndSort(List<Music> items, String cleanQuery) {
    var list = List<Music>.empty();
    if (cleanQuery.length < 3) {
      items.forEach((item) {
        if (item.artist.toLowerCase().startsWith(cleanQuery) ||
            (item.banglaartist.startsWith(cleanQuery) ?? false) ||
            item.title.toLowerCase().startsWith(cleanQuery) ||
            item.banglatitle.startsWith(cleanQuery)) {
          list.add(item);
        }
      });
      buildSortedResult(list, cleanQuery);
    } else {
      items.forEach((item) {
        if (item.artist.toLowerCase().contains(cleanQuery) ||
            (item.banglaartist.contains(cleanQuery) ?? false) ||
            item.title.toLowerCase().contains(cleanQuery) ||
            item.banglatitle.contains(cleanQuery)) {
          list.add(item);
        }
      });
      buildSortedResult(list, cleanQuery);
    }
    return list;
  }

  buildSortedResult(List<Music> list, String cleanQuery) {
    if (list.isNotEmpty) {
      list.sort((a, b) => getRank(a, cleanQuery) - getRank(b, cleanQuery));
    }
  }

  int getRank(Music music, String query) {
    var cleanQuery = query.toLowerCase().trim();
    var rank = 0;
    if (music.banglatitle.contains(cleanQuery)) {
      rank = music.banglatitle.indexOf(cleanQuery);
    } else if (music.artist.toLowerCase().contains(cleanQuery)) {
      rank = music.artist.toLowerCase().indexOf(cleanQuery) + 3;
    } else if ((music.banglaartist.contains(cleanQuery) ?? false)) {
      rank = music.banglaartist.indexOf(cleanQuery) + 3;
    } else if (music.title.toLowerCase().contains(cleanQuery)) {
      rank = music.title.toLowerCase().indexOf(cleanQuery);
    } else
      rank = 200;

    if (music.language == "Hindi") {
      rank += 16;
    }
    return rank;
  }

  void _openKaraokePage(Music music) {
    Navigator.push(
      context,
      CupertinoPageRoute(
          builder: (context) => KaraokePage(
                music: music,
              )),
    );
  }

  _setSelectItem(item) {
    //print(item);
    //print(_searchDelegate);
    _searchDelegate =  MusicSearchDelegate(
        items, _openKaraokePage, buildNavItem,
        prefs: prefs);
    print("=============THIS GOING ON=============");
    print(_searchDelegate);
    showSearch(context: context, delegate: _searchDelegate);
    _searchDelegate.close(context, null);
    setState(() {
      _selectedItem = item;
    });
  }

  void handleClick(String value) {
    switch (value) {
      case 'Sign Out':
        FirebaseAuth.instance.signOut().then(
            (value) => {GoogleSignIn().signOut().then((value) => setState)});
        break;
      case 'Song Request':
        showDialog(
          barrierDismissible: false,
          context: context,
          builder: (context) {
            var songNameController = TextEditingController();
            var artistNameController = TextEditingController();
            var globalKey = GlobalKey();
            return AlertDialog(
              title: Text("Song Request"),
              content: Form(
                key: globalKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextFormField(
                      textCapitalization: TextCapitalization.words,
                      maxLines: 1,
                      controller: songNameController,
                      validator: (val) {
                        print("validating: $val");
                        if (val!.length < 2) {
                          return "Name too short";
                        } else
                          return null;
                      },
                      decoration: InputDecoration(
                          hintMaxLines: 1, hintText: "Song Name"),
                    ),
                    TextFormField(
                      textCapitalization: TextCapitalization.words,
                      maxLines: 1,
                      controller: artistNameController,
                      validator: (val) {
                        print("validating: $val");
                        if (val!.length < 2) {
                          return "Name too short";
                        } else
                          return null;
                      },
                      decoration: InputDecoration(
                          hintMaxLines: 1, hintText: "Artist Name"),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text("Cancel"),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                TextButton(
                    child: Text("Submit"),
                    onPressed: () {
                      FormState? state = globalKey.currentState as FormState?;
                      if (state!.validate()) {
                        var songRequestRef = FirebaseDatabase.instance
                            .ref()
                            .child("requests")
                            .push();
                        var songRequestData = Map<String, dynamic>();
                        songRequestData['song_name'] = songNameController.text;
                        songRequestData['artist_name'] =
                            artistNameController.text;
                        songRequestData['user_id'] =
                            FirebaseAuth.instance.currentUser?.uid ?? "";
                        songRequestData['user_name'] =
                            FirebaseAuth.instance.currentUser?.displayName ??
                                "";
                        songRequestData['user_contact'] =
                            FirebaseAuth.instance.currentUser?.email ?? "";
                        songRequestRef.set(songRequestData).whenComplete(() {
                          Navigator.pop(context);
                        }).catchError((error) {});
                      }
                    }),
              ],
            );
          },
        );
        break;
      case 'Feedback':
        showDialog(
          barrierDismissible: false,
          context: context,
          builder: (context) {
            var feedbackTextController = TextEditingController();
            final GlobalKey<FormState> globalKey = GlobalKey<FormState>();
            /*var globalKey = GlobalKey();*/
            return AlertDialog(
              title: Text("Feedback"),
              content: Form(
                key: globalKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextFormField(
                      textCapitalization: TextCapitalization.words,
                      maxLines: 6,
                      controller: feedbackTextController,
                      validator: (val) {
                        print("validating: $val");
                        if (val!.length < 10) {
                          return "Please elaborate";
                        } else
                          return null;
                      },
                      decoration: InputDecoration(
                          hintMaxLines: 5,
                          hintText:
                              "Please, describe your experience with our app"),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text("Cancel"),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                TextButton(
                    child: Text("Submit"),
                    onPressed: () {
                      //State<StatefulWidget>? state = globalKey.currentState;
                      if (globalKey.currentState!.validate()) {
                        var feedbackRef = FirebaseDatabase.instance
                            .ref()
                            .child("feedback")
                            .push();
                        var feedbackData = Map<String, dynamic>();
                        feedbackData['feedback'] = feedbackTextController.text;
                        feedbackData['user_id'] =
                            FirebaseAuth.instance.currentUser?.uid ?? "";
                        feedbackData['user_name'] =
                            FirebaseAuth.instance.currentUser?.displayName ??
                                "";
                        feedbackData['user_contact'] =
                            FirebaseAuth.instance.currentUser?.email ?? "";
                        feedbackRef.set(feedbackData).whenComplete(() {
                          Navigator.pop(context);
                        }).catchError((error) {});
                      }
                    }),
              ],
            );
          },
        );
        break;
    }
  }
}

class MusicSearchDelegate extends SearchDelegate {
  final List<Music> items;
  final SharedPreferences prefs;
  final Function _openKaraokePage;
  final Function buildNavItems;

  MusicSearchDelegate(this.items, this._openKaraokePage, this.buildNavItems,
      {required this.prefs});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
         close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return buildSuggestions(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    var cleanQuery = query.toString().toLowerCase().trim();
    return buildNavItems(cleanQuery);
  }
}

class FadeRoute extends PageRouteBuilder {
  final Widget page;

  FadeRoute({required this.page})
      : super(
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              page,
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) =>
              FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
}
