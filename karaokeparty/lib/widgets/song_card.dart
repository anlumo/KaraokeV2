import 'package:flutter/material.dart';
import 'package:flutter_constraintlayout/flutter_constraintlayout.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/model/song.dart';

class SongCard extends StatelessWidget {
  SongCard({required this.song, super.key});

  final Song song;
  final title = ConstraintId('title');
  final coverImage = ConstraintId('coverImage');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 380.0, maxHeight: 96, minHeight: 96),
      child: Card(
        child: ConstraintLayout(
          showHelperWidgets: true,
          debugPrintConstraints: true,
          children: [
            Text(
              song.title,
              textAlign: TextAlign.start,
              style: theme.textTheme.labelLarge!.copyWith(overflow: TextOverflow.ellipsis),
            ).applyConstraint(
              id: title,
              left: parent.left.margin(8),
              right: coverImage.left.margin(8),
              bottom: parent.center,
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
              top: title.bottom,
            ),
            Text(
              '${song.duration ~/ 60}:${(song.duration % 60).round().toString().padLeft(2, '0')}',
              textAlign: TextAlign.end,
              style: theme.textTheme.labelSmall!.copyWith(overflow: TextOverflow.ellipsis),
            ).applyConstraint(
              right: coverImage.left.margin(8),
              bottom: parent.bottom.margin(8),
            ),
            const Placeholder(
              fallbackHeight: 80,
              fallbackWidth: 80,
            ).applyConstraint(
              id: coverImage,
              width: 80,
              height: 80,
              centerRightTo: parent.rightMargin(8),
            ),
          ],
        ),
      ),
    );
  }
}
