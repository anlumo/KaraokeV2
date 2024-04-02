import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/model/song.dart';

class SongPlayer extends StatefulWidget {
  const SongPlayer({required this.song, required this.player, super.key});

  final Song song;
  final AudioPlayer player;

  @override
  State<SongPlayer> createState() => _SongPlayerState();
}

class _SongPlayerState extends State<SongPlayer> {
  var duration = Duration.zero;
  var position = Duration.zero;
  var playerState = PlayerState.stopped;
  final _subscriptions = <StreamSubscription>[];

  var disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = widget.player;
      player.setSourceUrl('${serverHost.media}/${widget.song.audioPath}');
      _subscriptions.add(player.onDurationChanged.listen((newDuration) {
        if (!disposed) {
          setState(() {
            duration = newDuration;
          });
        }
      }));
      _subscriptions.add(player.onPositionChanged.listen((newPosition) {
        if (!disposed) {
          setState(() {
            position = newPosition;
          });
        }
      }));
      _subscriptions.add(player.onPlayerComplete.listen((_) => Navigator.of(context).pop()));
      _subscriptions.add(player.onPlayerStateChanged.listen(
        (event) {
          if (!disposed) {
            setState(() {
              playerState = event;
            });
          }
        },
      ));
    });
  }

  @override
  void dispose() {
    disposed = true;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
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
                  widget.player.seek(Duration(milliseconds: value.round()));
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
                  widget.player.seek(Duration.zero);
                },
                icon: const Icon(Icons.fast_rewind),
              ),
            ),
            Tooltip(
              message: context.t.audioplayer.mediaButtonRewind10Seconds,
              child: IconButton(
                onPressed: () {
                  widget.player.seek(position - const Duration(seconds: 10));
                },
                icon: const Icon(Icons.replay_10),
              ),
            ),
            (playerState == PlayerState.playing)
                ? Tooltip(
                    message: context.t.audioplayer.mediaButtonPause,
                    child: IconButton(
                      onPressed: () {
                        widget.player.pause();
                      },
                      icon: const Icon(Icons.pause, size: 42),
                    ),
                  )
                : Tooltip(
                    message: context.t.audioplayer.mediaButtonPlay,
                    child: IconButton(
                      onPressed: () {
                        widget.player.resume();
                      },
                      icon: const Icon(Icons.play_arrow, size: 42),
                    ),
                  ),
            Tooltip(
              message: context.t.audioplayer.mediaButtonSkip10Seconds,
              child: IconButton(
                onPressed: () {
                  widget.player.seek(position + const Duration(seconds: 10));
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
