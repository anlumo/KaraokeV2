import 'package:flutter/material.dart';
import 'package:flutter_constraintlayout/flutter_constraintlayout.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/api/song_cache.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/main.dart';
import 'package:karaokeparty/model/playlist_entry.dart';
import 'package:karaokeparty/model/song.dart';
import 'package:skeletonizer/skeletonizer.dart';

class SongCard extends StatelessWidget {
  SongCard({required this.song, this.singer, super.key});

  final Song song;
  final title = ConstraintId('title');
  final coverImage = ConstraintId('coverImage');
  final String? singer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 380.0, maxHeight: 96, minHeight: 96),
      child: Card(
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
            Image.network('$serverApi/cover/${song.id}').applyConstraint(
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
          ],
        ),
      ),
    );
  }
}

class PlaylistSongCard extends StatelessWidget {
  const PlaylistSongCard({required this.songCache, required this.entry, super.key});

  final SongCache songCache;
  final PlaylistEntry entry;

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
        );
      },
    );
  }
}
