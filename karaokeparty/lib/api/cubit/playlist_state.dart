part of 'playlist_cubit.dart';

class PlaylistState {
  const PlaylistState({required this.nowPlaying, required this.songQueue});

  final PlaylistEntry? nowPlaying;
  final List<PlaylistEntry> songQueue;
}
