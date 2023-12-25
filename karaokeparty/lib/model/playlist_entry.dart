import 'package:uuid/uuid.dart';

final class PlaylistEntry {
  final UuidValue id;
  final int song;
  final String singer;

  PlaylistEntry({required this.id, required this.song, required this.singer});

  PlaylistEntry.fromJson(Map<String, dynamic> json)
      : id = UuidValue.fromString(json['id']),
        song = json['song'] as int,
        singer = json['singer'];
}
