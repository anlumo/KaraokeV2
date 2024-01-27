import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:karaokeparty/model/playlist_entry.dart';

part 'playlist_state.dart';

class PlaylistCubit extends Cubit<PlaylistState> {
  PlaylistCubit() : super(const PlaylistState(playHistory: [], songQueue: []));

  void update({
    required List<PlaylistEntry> playHistory,
    required List<PlaylistEntry> songQueue,
  }) {
    emit(PlaylistState(playHistory: playHistory, songQueue: songQueue));
  }
}
