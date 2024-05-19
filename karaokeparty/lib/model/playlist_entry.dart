import 'package:uuid/uuid.dart';

final class PlaylistEntry {
  final UuidValue id;
  final int song;
  final String singer;
  final DateTime? predictedEnd;
  final String? passwordHash;

  PlaylistEntry(
      {required this.id,
      required this.song,
      required this.singer,
      required this.predictedEnd,
      required this.passwordHash});

  PlaylistEntry.fromJson(Map<String, dynamic> json)
      : id = UuidValue.fromString(json['id']),
        song = json['song'] as int,
        singer = json['singer'],
        predictedEnd = json['predictedEnd'] == null ? null : DateTime.tryParse(json['predictedEnd']),
        passwordHash = json['passwordHash'] as String?;

  @override
  String toString() => "[PlaylistEntry $id: song = $song, singer = $singer, predictedEnd = $predictedEnd]";
}
