import 'package:flutter/material.dart';
import 'package:flutter_constraintlayout/flutter_constraintlayout.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/model/song.dart';
import 'package:karaokeparty/widgets/song_card.dart';
import 'package:skeletonizer/skeletonizer.dart';

const suggestionsCount = 5;

class EmptyState extends StatefulWidget {
  const EmptyState({required this.api, required this.explanation, super.key});

  final ServerApi api;
  final String explanation;

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState> {
  final helpText = ConstraintId('help text');
  List<Song>? _songs;

  @override
  void initState() {
    super.initState();
    widget.api.fetchRandomSongs(suggestionsCount).then((songs) => setState(() {
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
            widget.explanation,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(
            height: 16,
          ),
          Flexible(
            child: Skeletonizer(
              enabled: _songs == null,
              child: ListView(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Skeleton.keep(
                          child: Text(
                            context.t.search.emptyState.randomPickListTitle,
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _songs = null;
                            widget.api.fetchRandomSongs(suggestionsCount).then((songs) => setState(() {
                                  _songs = songs;
                                }));
                          });
                        },
                        child: SizedBox(
                            height: kMinInteractiveDimension,
                            child: Center(child: Text(context.t.search.emptyState.rerollRandom))),
                      ),
                    ],
                  ),
                  ...(_songs ?? List.generate(suggestionsCount, (_) => Song.placeholder()))
                      .map((song) => Skeleton.leaf(child: SongCard(song: song, api: widget.api))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
