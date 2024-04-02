import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/model/song.dart';
import 'package:karaokeparty/widgets/song_player.dart';
import 'package:karaokeparty/widgets/song_card.dart';

class SongDetailsDialog extends StatefulWidget {
  const SongDetailsDialog({required this.song, super.key});

  final Song song;

  @override
  State<SongDetailsDialog> createState() => _SongDetailsDialogState();
}

class _SongDetailsDialogState extends State<SongDetailsDialog> {
  final _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(widget.song.title)),
          IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
        ],
      ),
      scrollable: true,
      content: Focus(
        autofocus: true,
        descendantsAreFocusable: false,
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
            if (_audioPlayer.state == PlayerState.playing) {
              _audioPlayer.pause();
            } else {
              _audioPlayer.resume();
            }
            return KeyEventResult.handled;
          }
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _audioPlayer.getCurrentPosition().then((position) {
              if (position != null) {
                _audioPlayer.seek(position - const Duration(seconds: 10));
              }
            });
            return KeyEventResult.handled;
          }
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _audioPlayer.getCurrentPosition().then((position) {
              if (position != null) {
                _audioPlayer.seek(position + const Duration(seconds: 10));
              }
            });
            return KeyEventResult.handled;
          }
          if (event is KeyDownEvent && event.character == '0') {
            _audioPlayer.seek(Duration.zero);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 32.0, right: 32.0, bottom: 16.0),
              child: SizedBox(
                width: 300,
                child: widget.song.coverPath != null ? coverImageWidget() : null,
              ),
            ),
            SongPlayer(song: widget.song, player: _audioPlayer),
            const SizedBox(
              height: 8,
            ),
            Text(
              widget.song.lyrics ?? '',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Image coverImageWidget() => Image.network(
        '${serverHost.media}/${widget.song.coverPath}',
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
