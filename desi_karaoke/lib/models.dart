class Music {
   String artist="";
  String banglaartist = "";
  String banglatitle = "";
   String effectivetitle="";
   String effectiveartist="";
   String genre="";
   String language="";
   int lyricoffset=-1;
   String lyricref="";
   String storagepath="";
   String title="";
   String trial="";
   String key="";
  bool isFavorite = false;
  /*late String artist;
  String banglaartist = "";
  String banglatitle = "";
  late String effectivetitle;
  late String effectiveartist;
  late String genre;
  late String language;
  late int lyricoffset;
  late String lyricref;
  late String storagepath;
  late String title;
  late String trial;
  late String key;
  bool isFavorite = false;*/

  Music.fromMap(Map<dynamic, dynamic> data) {
    artist = data['artist'];
    banglatitle = data['banglatitle'];
    /*banglaartist = data['banglaartist'];*/
    banglaartist = data['banglaartist'] ?? '';
    genre = data['genre'];
    language = data['language'];
    lyricoffset = data['lyricoffset'];
    lyricref = data['lyricref'];
    storagepath = data['storagepath'];
    title = data['title'];
    trial = data['trial'];

    /*effectivetitle =
        banglatitle == "" ? title : banglatitle;*/
    effectiveartist =
        banglaartist == "" ? artist : banglaartist;
  }
   String get effectiveTitle {
     return banglatitle ?? title;
   }
  @override
  String toString() {
    return effectivetitle;
  }
}

class KaraokeDevice {
  String buyer = "";
  String name = "";
  String mac = "";
  String phone = "";

  KaraokeDevice.fromMap(Map<dynamic, dynamic> data) {
    buyer = data['buyer'];
    name = data['name'];
    mac = data['mac'];
    phone = data['phone'];
  }

  @override
  String toString() {
    return "KaraokeDevice: mac = $mac, name = $name";
  }
}

class SharedPreferencesKeys {
  static const FAVORITES = "favorites";
}

class Artist implements Comparable<Artist> {
   String artist="";
   String effectiveartist="";
   String banglaartist="";
  /*late String artist;
  late String effectiveartist;
  late String banglaartist;*/

  Artist(this.artist, this.banglaartist, this.effectiveartist);

  Artist.fromMusic(Music music) {
    this.artist = music.artist;
    this.banglaartist = music.banglaartist;
    this.effectiveartist = music.effectiveartist;
  }

  @override
  int compareTo(other) {
    if (other is Artist) {
      return this.effectiveartist.compareTo(other.effectiveartist);
    } else
      return -1;
  }

  bool contains(String query) {
    return (this.artist.toLowerCase().trim().contains(query) ?? false) ||
        (this.banglaartist.toLowerCase().trim().contains(query) ?? false) ||
        (this.effectiveartist.toLowerCase().trim().contains(query) ?? false);
  }
}
