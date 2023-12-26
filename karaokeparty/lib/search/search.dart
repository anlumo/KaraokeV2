import 'package:flutter/material.dart';
import 'package:flutter_constraintlayout/flutter_constraintlayout.dart';
import 'package:karaokeparty/add_dialog/add_dialog.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/model/song.dart';
import 'package:karaokeparty/search/empty_state.dart';
import 'package:karaokeparty/widgets/song_card.dart';

class Search extends StatefulWidget {
  const Search({required this.api, super.key});

  final ServerApi api;

  @override
  State<Search> createState() => _SearchState();
}

class _SearchState extends State<Search> {
  Future<List<Song>>? _searchResults;
  final _controller = TextEditingController();
  final searchBar = ConstraintId('searchbar');

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Stack(
        children: [
          Positioned.fill(
            bottom: null,
            child: SearchBar(
              controller: _controller,
              padding: const MaterialStatePropertyAll<EdgeInsets>(EdgeInsets.symmetric(horizontal: 16.0)),
              onTap: () {},
              onChanged: (_) {},
              onSubmitted: (text) {
                setState(() {
                  _searchResults = widget.api.search(text);
                });
              },
              leading: const Icon(Icons.search),
              trailing: [
                Tooltip(
                  message: _controller.text.isNotEmpty
                      ? context.t.search.clearTextButton
                      : context.t.search.randomPickButton,
                  child: _controller.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _searchResults = null;
                            });
                          },
                          icon: const Icon(Icons.clear))
                      : IconButton(
                          onPressed: () async {
                            final songs = await widget.api.fetchRandomSongs(1);
                            if (songs != null && songs.length == 1 && context.mounted) {
                              showAddSongDialog(context, song: songs.first, api: widget.api);
                            }
                          },
                          icon: const Icon(Icons.casino)),
                ),
              ],
            ),
          ),
          Positioned.fill(
            top: 66,
            child: (_searchResults != null)
                ? FutureBuilder(
                    future: _searchResults,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        final theme = Theme.of(context);

                        return Center(
                          child: Text(
                            snapshot.error.toString(),
                            style: theme.textTheme.labelLarge!.copyWith(color: theme.colorScheme.error),
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: SizedBox(width: 50, height: 50, child: CircularProgressIndicator()));
                      }
                      return ListView.builder(
                        primary: true,
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          return SongCard(song: snapshot.data![index], api: widget.api);
                        },
                      );
                    },
                  )
                : EmptyState(
                    api: widget.api,
                    explanation: context.t.search.emptyState.explanation,
                  ),
          ),
        ],
      ),
    );
  }
}
