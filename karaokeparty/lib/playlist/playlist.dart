import 'package:animated_list_plus/animated_list_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/api/cubit/playlist_cubit.dart';
import 'package:karaokeparty/api/song_cache.dart';
import 'package:karaokeparty/model/playlist_entry.dart';
import 'package:karaokeparty/widgets/song_card.dart';

class Playlist extends StatelessWidget {
  const Playlist({required this.songCache, required this.api, super.key});

  final SongCache songCache;
  final ServerApi api;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaylistCubit, PlaylistState>(
      builder: (context, state) {
        return ImplicitlyAnimatedList<PlaylistEntry>(
          primary: true,
          items: state.songQueue,
          itemBuilder: (context, animation, item, i) {
            return PlaylistSongCard(songCache: songCache, entry: item, api: api);
          },
          areItemsTheSame: (a, b) => a.id == b.id,
        );
      },
    );
  }
}
