import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/api/cubit/connection_cubit.dart';
import 'package:karaokeparty/api/song_cache.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/model/playlist_entry.dart';
import 'package:karaokeparty/now_playing/bug_report.dart';
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
          BlocBuilder<ConnectionCubit, WebSocketConnectionState>(
            builder: (context, state) {
              final titleText = Text(
                context.t.playlist.nowPlayingTitle,
                style: theme.textTheme.labelLarge!.copyWith(color: theme.colorScheme.onSecondary),
              );
              if (state case WebSocketConnectedState(:final isAdmin)) {
                if (isAdmin) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(children: [
                      Expanded(
                        child: titleText,
                      ),
                      IconButton(
                        onPressed: () async {
                          final maybeSong = await songCache.get(entry.song);
                          if (maybeSong != null && context.mounted) {
                            await showBugReportDialog(context, song: maybeSong, api: api);
                          }
                        },
                        hoverColor: theme.colorScheme.onSecondaryContainer,
                        icon: Icon(Icons.bug_report, color: theme.colorScheme.onSecondary),
                      ),
                    ]),
                  );
                }
              }
              return titleText;
            },
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
