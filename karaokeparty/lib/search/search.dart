import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_constraintlayout/flutter_constraintlayout.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/api/cubit/connection_cubit.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/model/song.dart';
import 'package:karaokeparty/search/cubit/search_filter_cubit.dart';
import 'package:karaokeparty/search/empty_state.dart';
import 'package:karaokeparty/search/suggest_song.dart';
import 'package:karaokeparty/widgets/filter_bar.dart';
import 'package:karaokeparty/widgets/song_card.dart';

class Search extends StatefulWidget {
  const Search({required this.api, super.key});

  final ServerApi api;

  @override
  State<Search> createState() => _SearchState();
}

class _SearchState extends State<Search> {
  Future<List<Song>>? _searchResults;
  String? _searchedText;
  final _controller = TextEditingController();
  final searchBar = ConstraintId('searchbar');
  final _searchBarFocusNode = FocusNode(debugLabel: 'searchbar');

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {});
    });
    _searchBarFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchBarFocusNode.dispose();
    super.dispose();
  }

  void _updateSearch(BuildContext context) {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    final searchFilter = context.read<SearchFilterCubit>();
    final search = searchFilter.queryString(text);

    if (search != null) {
      setState(() {
        _searchedText = text;
        _searchResults = widget.api.search(search);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Stack(
        children: [
          Positioned.fill(
            child: (_searchResults != null)
                ? FutureBuilder(
                    future: _searchResults,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        final theme = Theme.of(context);

                        final String message;
                        if (snapshot.error is ServerError &&
                            (snapshot.error as ServerError).response.statusCode == 400) {
                          message =
                              '${context.t.search.searchQueryParserError}\n\n${(snapshot.error as ServerError).response.body}';
                        } else {
                          message = snapshot.error.toString();
                        }

                        return Center(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                message,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelLarge!.copyWith(color: theme.colorScheme.error),
                              ),
                            ),
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: SizedBox(width: 50, height: 50, child: CircularProgressIndicator()));
                      }
                      if (snapshot.data!.isEmpty && _searchedText != null) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 80),
                          child: SuggestSong(
                            api: widget.api,
                            failedSearch: _searchedText!,
                          ),
                        );
                      }
                      return ListView.builder(
                        primary: true,
                        padding: const EdgeInsets.only(top: 66),
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          return SongCard(song: snapshot.data![index], api: widget.api);
                        },
                      );
                    },
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: 72),
                    child: EmptyState(
                      api: widget.api,
                      explanation: context.t.search.emptyState.explanation,
                    ),
                  ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: ColoredBox(
                  color: theme.colorScheme.background.withOpacity(0.5),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: BlocListener<SearchFilterCubit, SearchFilterState>(
                      listener: (context, state) => _updateSearch(context),
                      child: FilterBar(
                        api: widget.api,
                        child: SearchBar(
                          focusNode: _searchBarFocusNode,
                          controller: _controller,
                          padding: const MaterialStatePropertyAll<EdgeInsets>(EdgeInsets.symmetric(horizontal: 16.0)),
                          backgroundColor: MaterialStatePropertyAll(theme.colorScheme.surface.withOpacity(0.5)),
                          hintText: context.t.search.searchHint,
                          onTap: () {},
                          onChanged: (_) {},
                          onSubmitted: (_) {
                            _updateSearch(context);
                          },
                          leading: const Icon(Icons.search),
                          trailing: [
                            if (_controller.text.isNotEmpty)
                              Tooltip(
                                message: context.t.search.clearTextButton,
                                child: IconButton(
                                  onPressed: () {
                                    _controller.clear();
                                    setState(() {
                                      _searchResults = null;
                                      _searchedText = null;
                                    });
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
