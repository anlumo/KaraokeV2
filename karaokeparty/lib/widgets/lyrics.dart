import 'package:flutter/material.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/model/song.dart';

class LyricsDialog extends StatelessWidget {
  const LyricsDialog({required this.song, super.key});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(context.t.playlist.lyricsDialog.title(song: song.title)),
      content: SingleChildScrollView(
        child: Text(
          song.lyrics ?? '',
          style: theme.textTheme.bodySmall,
        ),
      ),
      actions: [
        OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(context.t.playlist.lyricsDialog.closeButton)),
      ],
    );
  }
}

Future<void> showLyricsDialog(BuildContext context, Song song) => showDialog<void>(
      context: context,
      builder: (context) => LyricsDialog(song: song),
    );
