part of 'playlist_cubit.dart';

class PlaylistState {
  const PlaylistState({required this.playHistory, required this.songQueue});

  final List<PlaylistEntry> playHistory;
  final List<PlaylistEntry> songQueue;
}
