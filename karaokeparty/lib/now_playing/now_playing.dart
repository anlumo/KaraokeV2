import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/api/cubit/playlist_cubit.dart';
import 'package:karaokeparty/api/song_cache.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/widgets/song_card.dart';

class NowPlaying extends StatelessWidget {
  const NowPlaying({required this.songCache, required this.api, super.key});

  final SongCache songCache;
  final ServerApi api;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<PlaylistCubit, PlaylistState>(
      builder: (context, state) {
        if (state.nowPlaying == null) {
          return const SizedBox();
        }
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
                entry: state.nowPlaying!,
                api: api,
                predictedPlayTime: null,
              ),
            ],
          ),
        );
      },
    );
  }
}
