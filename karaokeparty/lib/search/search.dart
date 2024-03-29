import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_constraintlayout/flutter_constraintlayout.dart';
import 'package:karaokeparty/add_dialog/add_dialog.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/api/cubit/connection_cubit.dart';
import 'package:karaokeparty/api/cubit/playlist_cubit.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/model/song.dart';
import 'package:karaokeparty/search/cubit/search_filter_cubit.dart';
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
    final search = [
      text,
      if (searchFilter.language != null) 'language:"${searchFilter.language!}"',
      if (searchFilter.decade != null) 'year:[${searchFilter.decade!}]',
      if (searchFilter.duet != null) 'duet:${searchFilter.duet}',
    ].join(' AND ');

    setState(() {
      _searchResults = widget.api.search(search);
    });
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
                    child: BlocBuilder<SearchFilterCubit, SearchFilterState>(
                      builder: (context, searchFilter) => Row(
                        children: [
                          Expanded(
                            child: SearchBar(
                              focusNode: _searchBarFocusNode,
                              controller: _controller,
                              padding:
                                  const MaterialStatePropertyAll<EdgeInsets>(EdgeInsets.symmetric(horizontal: 16.0)),
                              backgroundColor: MaterialStatePropertyAll(theme.colorScheme.surface.withOpacity(0.5)),
                              hintText: context.t.search.searchHint,
                              onTap: () {},
                              onChanged: (_) {},
                              onSubmitted: (_) {
                                _updateSearch(context);
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
                                              showAddSongDialog(
                                                context,
                                                song: songs.first,
                                                api: widget.api,
                                                playlistCubit: context.read<PlaylistCubit>(),
                                              );
                                            }
                                          },
                                          icon: const Icon(Icons.casino)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Tooltip(
                            message: context.t.search.searchFilterLanguagesTooltip,
                            child: MenuAnchor(
                                menuChildren: widget.api.connectionCubit.state is WebSocketConnectedState
                                    ? [
                                        RadioMenuButton(
                                            value: null,
                                            groupValue: searchFilter.language,
                                            onChanged: (_) {
                                              context.read<SearchFilterCubit>().language = null;
                                              _updateSearch(context);
                                            },
                                            child: Text(context.t.search.searchFilterAllLanguages)),
                                        const Divider(),
                                        ...(widget.api.connectionCubit.state as WebSocketConnectedState)
                                            .languages
                                            .map((language) => RadioMenuButton(
                                                value: language,
                                                groupValue: searchFilter.language,
                                                onChanged: (_) {
                                                  context.read<SearchFilterCubit>().language = language;
                                                  _updateSearch(context);
                                                },
                                                child: Text(language)))
                                      ]
                                    : const [],
                                builder: (context, controller, child) => IconButton(
                                    onPressed: () {
                                      if (controller.isOpen) {
                                        controller.close();
                                      } else {
                                        controller.open();
                                      }
                                    },
                                    isSelected: searchFilter.language != null,
                                    icon: const Icon(Icons.language))),
                          ),
                          Tooltip(
                            message: context.t.search.searchFilterDecadesTooltip,
                            child: MenuAnchor(
                              menuChildren: [
                                RadioMenuButton(
                                    value: null,
                                    groupValue: searchFilter.decade,
                                    onChanged: (_) {
                                      context.read<SearchFilterCubit>().decade = null;
                                      _updateSearch(context);
                                    },
                                    child: Text(context.t.search.searchFilterAllYears)),
                                const Divider(),
                                ...context.t.search.searchFilterDecades.entries.map(
                                  (entry) => RadioMenuButton(
                                    value: entry.key,
                                    groupValue: searchFilter.decade,
                                    onChanged: (_) {
                                      context.read<SearchFilterCubit>().decade = entry.key;
                                      _updateSearch(context);
                                    },
                                    child: Text(entry.value),
                                  ),
                                ),
                              ],
                              builder: (context, controller, child) => IconButton(
                                  onPressed: () {
                                    if (controller.isOpen) {
                                      controller.close();
                                    } else {
                                      controller.open();
                                    }
                                  },
                                  isSelected: searchFilter.decade != null,
                                  icon: const Icon(Icons.calendar_month)),
                            ),
                          ),
                          Tooltip(
                            message: context.t.search.searchFilterDuetTooltip,
                            child: MenuAnchor(
                              menuChildren: [
                                RadioMenuButton(
                                    value: null,
                                    groupValue: searchFilter.duet,
                                    onChanged: (_) {
                                      context.read<SearchFilterCubit>().duet = null;
                                      _updateSearch(context);
                                    },
                                    child: Text(context.t.search.duets.dontCare)),
                                const Divider(),
                                RadioMenuButton(
                                    value: true,
                                    groupValue: searchFilter.duet,
                                    onChanged: (_) {
                                      context.read<SearchFilterCubit>().duet = true;
                                      _updateSearch(context);
                                    },
                                    child: Text(context.t.search.duets.onlyDuets)),
                                RadioMenuButton(
                                    value: false,
                                    groupValue: searchFilter.duet,
                                    onChanged: (_) {
                                      context.read<SearchFilterCubit>().duet = false;
                                      _updateSearch(context);
                                    },
                                    child: Text(context.t.search.duets.noDuets)),
                              ],
                              builder: (context, controller, child) => IconButton(
                                  onPressed: () {
                                    if (controller.isOpen) {
                                      controller.close();
                                    } else {
                                      controller.open();
                                    }
                                  },
                                  isSelected: searchFilter.duet != null,
                                  icon: const Icon(Icons.group)),
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
        ],
      ),
    );
  }
}
