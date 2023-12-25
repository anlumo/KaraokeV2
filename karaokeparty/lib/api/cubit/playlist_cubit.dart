import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:karaokeparty/model/playlist_entry.dart';

part 'playlist_state.dart';

class PlaylistCubit extends Cubit<PlaylistState> {
  PlaylistCubit() : super(const PlaylistState(nowPlaying: null, songQueue: []));

  void update({
    required PlaylistEntry? nowPlaying,
    required List<PlaylistEntry> songQueue,
  }) {
    emit(PlaylistState(nowPlaying: nowPlaying, songQueue: songQueue));
  }
}
