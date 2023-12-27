import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/model/song.dart';
import 'package:karaokeparty/widgets/song_card.dart';

class _AudioPlayer extends StatefulWidget {
  const _AudioPlayer({required this.song});

  final Song song;

  @override
  State<_AudioPlayer> createState() => _AudioPlayerState();
}

class _AudioPlayerState extends State<_AudioPlayer> {
  final player = AudioPlayer();
  var duration = Duration.zero;
  var position = Duration.zero;
  var playerState = PlayerState.stopped;

  var disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      player.setSourceUrl('${serverHost.media}/${widget.song.audioPath}');
      player.onDurationChanged.listen((newDuration) {
        if (!disposed) {
          setState(() {
            duration = newDuration;
          });
        }
      });
      player.onPositionChanged.listen((newPosition) {
        if (!disposed) {
          setState(() {
            position = newPosition;
          });
        }
      });
      player.onPlayerComplete.listen((_) => Navigator.of(context).pop());
      player.onPlayerStateChanged.listen(
        (event) {
          if (!disposed) {
            setState(() {
              playerState = event;
            });
          }
        },
      );
      player.resume();
    });
  }

  @override
  void dispose() {
    disposed = true;
    player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).round().toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.all(8),
      contentPadding: const EdgeInsets.all(16),
      title: Text(widget.song.title),
      icon: coverImageWidget(),
      actions: [
        OutlinedButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(context.t.audioplayer.closeButton),
        ),
      ],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.song.year != null
                ? context.t.core.songCardArtistYear(artist: widget.song.artist, year: widget.song.year!)
                : widget.song.artist,
          ),
          Row(
            children: [
              Text(_formatDuration(position)),
              Expanded(
                child: Slider(
                  max: max(duration.inMilliseconds, position.inMilliseconds).toDouble(),
                  value: position.inMilliseconds.toDouble(),
                  onChanged: (value) {
                    player.seek(Duration(milliseconds: value.round()));
                  },
                ),
              ),
              Text(_formatDuration(duration)),
            ],
          ),
          Wrap(
            children: [
              IconButton(
                onPressed: () {
                  player.seek(Duration.zero);
                },
                icon: const Icon(Icons.fast_rewind),
              ),
              IconButton(
                onPressed: () {
                  player.seek(position - const Duration(seconds: 10));
                },
                icon: const Icon(Icons.replay_10),
              ),
              (playerState == PlayerState.playing)
                  ? IconButton(
                      onPressed: () {
                        player.pause();
                      },
                      icon: const Icon(Icons.pause),
                    )
                  : IconButton(
                      onPressed: () {
                        player.resume();
                      },
                      icon: const Icon(Icons.play_arrow),
                    ),
              IconButton(
                onPressed: () {
                  player.seek(position + const Duration(seconds: 10));
                },
                icon: const Icon(Icons.forward_10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Image coverImageWidget() => Image.network(
        '${serverHost.media}/${widget.song.coverPath}',
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

Future<void> showAudioPlayer(BuildContext context, Song song) => showDialog(
      context: context,
      builder: (context) => _AudioPlayer(song: song),
    );
