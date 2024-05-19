import 'package:uuid/uuid.dart';

final class PlaylistEntry {
  final UuidValue id;
  final int song;
  final String singer;
  final DateTime? predictedEnd;
  final String? password;

  PlaylistEntry(
      {required this.id, required this.song, required this.singer, required this.predictedEnd, required this.password});

  PlaylistEntry.fromJson(Map<String, dynamic> json)
      : id = UuidValue.fromString(json['id']),
        song = json['song'] as int,
        singer = json['singer'],
        predictedEnd = json['predictedEnd'] == null ? null : DateTime.tryParse(json['predictedEnd']),
        password = json['password'] as String?;

  @override
  String toString() => "[PlaylistEntry $id: song = $song, singer = $singer, predictedEnd = $predictedEnd]";
}
