import 'package:flutter/material.dart';
import 'package:flutter_constraintlayout/flutter_constraintlayout.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/model/song.dart';
import 'package:karaokeparty/widgets/song_card.dart';

class EmptyState extends StatefulWidget {
  const EmptyState({required this.api, super.key});

  final ServerApi api;

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState> {
  final helpText = ConstraintId('help text');
  List<Song>? _songs;

  @override
  void initState() {
    super.initState();
    widget.api.fetchRandomSongs(5).then((songs) => setState(() {
          _songs = songs;
        }));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        children: [
          Text(
            context.t.search.emptyState.explanation,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(
            height: 16,
          ),
          if (_songs != null)
            Flexible(
              child: ListView(
                children: [
                  Text(
                    context.t.search.emptyState.randomPickListTitle,
                    style: theme.textTheme.labelLarge,
                  ),
                  ..._songs!.map((song) => SongCard(song: song, api: widget.api)),
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: TextButton(
                        onPressed: () {
                          widget.api.fetchRandomSongs(5).then((songs) => setState(() {
                                _songs = songs;
                              }));
                        },
                        child: Text(context.t.search.emptyState.rerollRandom)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
