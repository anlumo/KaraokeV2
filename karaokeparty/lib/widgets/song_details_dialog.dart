import 'package:flutter/material.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/model/song.dart';
import 'package:karaokeparty/widgets/song_player.dart';
import 'package:karaokeparty/widgets/song_card.dart';

class SongDetailsDialog extends StatelessWidget {
  const SongDetailsDialog({required this.song, super.key});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(song.title)),
          IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
        ],
      ),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 32.0, right: 32.0, bottom: 16.0),
            child: SizedBox(
              width: 300,
              child: song.coverPath != null ? coverImageWidget() : null,
            ),
          ),
          SongPlayer(song: song),
          const SizedBox(
            height: 8,
          ),
          Text(
            song.lyrics ?? '',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Image coverImageWidget() => Image.network(
        '${serverHost.media}/${song.coverPath}',
        fit: BoxFit.contain,
        loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => const PlaceholderCover(),
      );
}

Future<void> showSongDetailsDialog(BuildContext context, Song song) => showDialog<void>(
      context: context,
      builder: (context) => SongDetailsDialog(song: song),
    );
