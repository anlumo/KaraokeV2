import 'package:flutter/material.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/api/song_cache.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/model/playlist_entry.dart';
import 'package:karaokeparty/widgets/song_card.dart';

class NowPlaying extends StatelessWidget {
  const NowPlaying({required this.songCache, required this.api, required this.entry, super.key});

  final SongCache songCache;
  final ServerApi api;
  final PlaylistEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.secondary,
      elevation: 5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.t.playlist.nowPlayingTitle,
            style: theme.textTheme.labelLarge!.copyWith(color: theme.colorScheme.onSecondary),
          ),
          PlaylistSongCard(
            songCache: songCache,
            entry: entry,
            api: api,
            predictedPlayTime: null,
          ),
        ],
      ),
    );
  }
}
