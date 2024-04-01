import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/model/song.dart';

class SongPlayer extends StatefulWidget {
  const SongPlayer({required this.song, super.key});

  final Song song;

  @override
  State<SongPlayer> createState() => _SongPlayerState();
}

class _SongPlayerState extends State<SongPlayer> {
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
    return Column(
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
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Tooltip(
              message: context.t.audioplayer.mediaButtonRewind,
              child: IconButton(
                onPressed: () {
                  player.seek(Duration.zero);
                },
                icon: const Icon(Icons.fast_rewind),
              ),
            ),
            Tooltip(
              message: context.t.audioplayer.mediaButtonRewind10Seconds,
              child: IconButton(
                onPressed: () {
                  player.seek(position - const Duration(seconds: 10));
                },
                icon: const Icon(Icons.replay_10),
              ),
            ),
            (playerState == PlayerState.playing)
                ? Tooltip(
                    message: context.t.audioplayer.mediaButtonPause,
                    child: IconButton(
                      onPressed: () {
                        player.pause();
                      },
                      icon: const Icon(Icons.pause, size: 42),
                    ),
                  )
                : Tooltip(
                    message: context.t.audioplayer.mediaButtonPlay,
                    child: IconButton(
                      onPressed: () {
                        player.resume();
                      },
                      icon: const Icon(Icons.play_arrow, size: 42),
                    ),
                  ),
            Tooltip(
              message: context.t.audioplayer.mediaButtonSkip10Seconds,
              child: IconButton(
                onPressed: () {
                  player.seek(position + const Duration(seconds: 10));
                },
                icon: const Icon(Icons.forward_10),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
