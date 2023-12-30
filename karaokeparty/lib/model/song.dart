final class Song {
  final int id;
  final String title;
  final String artist;
  final String? language;
  final int? year;
  final double duration;
  final String? lyrics;
  final bool duet;
  final String? coverPath;
  final String audioPath;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.language,
    required this.year,
    required this.duration,
    required this.lyrics,
    required this.duet,
    required this.coverPath,
    required this.audioPath,
  });

  Song.placeholder()
      : id = -1,
        title = 'Let\'s meet at the FooBar sdflkj sdalf ldsjf lksdjf klsjdflsjldkfjlsdj',
        artist = 'Foo Fighters',
        language = null,
        year = 1234,
        duration = 260.0,
        lyrics = null,
        duet = false,
        coverPath = null,
        audioPath = '';

  Song.fromJson(Map<String, dynamic> json)
      : id = json['rowId'],
        title = json['title'],
        artist = json['artist'],
        language = json['language'],
        year = json['year'] as int?,
        duration = json['duration'],
        lyrics = json['lyrics'],
        duet = json['duet'] ?? false,
        coverPath = json['coverPath'],
        audioPath = json['audioPath'];
}
