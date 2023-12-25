final class Song {
  final int id;
  final String title;
  final String artist;
  final String? language;
  final int? year;
  final double duration;
  final String? lyrics;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.language,
    required this.year,
    required this.duration,
    required this.lyrics,
  });

  Song.placeholder()
      : id = 123,
        title = 'Let\'s meet at the FooBar sdflkj sdalf ldsjf lksdjf klsjdflsjldkfjlsdj',
        artist = 'Foo Fighters',
        language = null,
        year = 1234,
        duration = 260.0,
        lyrics = null;
}
