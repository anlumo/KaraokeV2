import 'package:flutter/material.dart';
import 'package:flutter_constraintlayout/flutter_constraintlayout.dart';
import 'package:karaokeparty/add_dialog/add_dialog.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/api/song_cache.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/main.dart';
import 'package:karaokeparty/model/playlist_entry.dart';
import 'package:karaokeparty/model/song.dart';
import 'package:karaokeparty/widgets/lyrics.dart';
import 'package:skeletonizer/skeletonizer.dart';

class SongCard extends StatelessWidget {
  SongCard({required this.song, required this.api, this.singer, this.disabled = false, super.key});

  final Song song;
  final title = ConstraintId('title');
  final coverImage = ConstraintId('coverImage');
  final String? singer;
  final ServerApi api;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 380.0, maxHeight: 96, minHeight: 96),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: disabled
              ? null
              : () {
                  showAddSongDialog(context, song: song, api: api);
                },
          child: ConstraintLayout(
            showHelperWidgets: true,
            children: [
              Text(
                song.title,
                textAlign: TextAlign.start,
                style: theme.textTheme.labelLarge!.copyWith(overflow: TextOverflow.ellipsis),
              ).applyConstraint(
                id: title,
                centerLeftTo: parent.leftMargin(8),
                right: coverImage.left.margin(8),
                width: matchConstraint,
              ),
              Text(
                song.year != null
                    ? context.t.core.songCardArtistYear(artist: song.artist, year: song.year.toString())
                    : song.artist,
                textAlign: TextAlign.start,
                style: theme.textTheme.labelMedium!.copyWith(overflow: TextOverflow.ellipsis),
              ).applyConstraint(
                left: title.left,
                right: coverImage.left.margin(8),
                width: matchConstraint,
                bottom: parent.bottom.margin(8),
              ),
              Text(
                '${song.duration ~/ 60}:${(song.duration % 60).round().toString().padLeft(2, '0')}',
                textAlign: TextAlign.end,
                style: theme.textTheme.labelSmall!.copyWith(overflow: TextOverflow.ellipsis),
              ).applyConstraint(
                right: coverImage.left.margin(8),
                bottom: parent.bottom.margin(8),
              ),
              ((song.coverPath == null)
                      ? ColoredBox(
                          color: theme.colorScheme.secondary,
                          child: Icon(Icons.music_note, size: 50, color: theme.colorScheme.onSecondary))
                      : InkWell(
                          onTap: () => showDialog(
                                context: context,
                                builder: (context) =>
                                    Dialog(child: Image.network('http://$serverHost/cover/${song.coverPath}')),
                              ),
                          child: Image.network('http://$serverHost/cover/${song.coverPath}')))
                  .applyConstraint(
                id: coverImage,
                width: 80,
                height: 80,
                centerRightTo: parent.rightMargin(8),
              ),
              if (singer != null)
                Text(
                  singer!,
                  textAlign: TextAlign.start,
                  style: theme.textTheme.labelLarge!
                      .copyWith(overflow: TextOverflow.ellipsis, color: theme.colorScheme.primary),
                ).applyConstraint(
                  topLeftTo: parent.topMargin(8).leftMargin(8),
                  right: coverImage.left.margin(8),
                  width: matchConstraint,
                ),
              if (song.lyrics != null)
                IconButton(
                        onPressed: () {
                          showLyricsDialog(context, song);
                        },
                        icon: const Icon(Icons.lyrics))
                    .applyConstraint(right: coverImage.left.margin(8), top: parent.top.margin(8)),
            ],
          ),
        ),
      ),
    );
  }
}

class PlaylistSongCard extends StatelessWidget {
  const PlaylistSongCard({
    required this.songCache,
    required this.entry,
    required this.api,
    super.key,
  });

  final SongCache songCache;
  final PlaylistEntry entry;
  final ServerApi api;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: songCache.get(entry.song),
      builder: (context, snapshot) {
        final theme = Theme.of(context);
        log.d('snapshot: $snapshot');

        if (!snapshot.hasData) {
          return Skeletonizer(
            child: Skeleton.leaf(
                child: SongCard(
              song: Song.placeholder(),
              singer: entry.singer,
              api: api,
              disabled: true,
            )),
          );
        } else if (snapshot.data == null) {
          return Text(
            'Failed loading song: ${snapshot.error}',
            style: theme.textTheme.labelMedium!.copyWith(color: theme.colorScheme.error),
          );
        }
        return SongCard(
          song: snapshot.data!,
          singer: entry.singer,
          api: api,
          disabled: true,
        );
      },
    );
  }
}
