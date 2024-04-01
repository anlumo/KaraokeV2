import 'package:animated_list_plus/animated_list_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/api/song_cache.dart';
import 'package:karaokeparty/main.dart';
import 'package:karaokeparty/model/playlist_entry.dart';
import 'package:karaokeparty/now_playing/now_playing.dart';
import 'package:karaokeparty/widgets/song_card.dart';

class UserList extends StatelessWidget {
  const UserList({
    super.key,
    required this.api,
    required this.songCache,
    required this.songQueue,
    required this.songQueueNowPlaying,
  });

  final SongCache songCache;
  final ServerApi api;
  final List<PlaylistEntry> songQueue;
  final int? songQueueNowPlaying;

  @override
  Widget build(BuildContext context) {
    return ImplicitlyAnimatedList<PlaylistEntry>(
      primary: true,
      items: songQueue,
      itemBuilder: (context, itemAnimation, item, i) {
        if (i == songQueueNowPlaying) {
          return NowPlaying(songCache: songCache, api: api, entry: item);
        }
        log.d('render item $i singer ${item.singer}');
        return PlaylistSongCard(
          songCache: songCache,
          entry: item,
          api: api,
          predictedPlayTime: (i > 0 && (songQueueNowPlaying == null || i > songQueueNowPlaying!))
              ? songQueue[i - 1].predictedEnd
              : null,
        );
      },
      areItemsTheSame: (a, b) => a.id == b.id,
    );
  }
}
