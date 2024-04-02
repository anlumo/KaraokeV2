import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/api/cubit/connection_cubit.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/main.dart';
import 'package:karaokeparty/model/song.dart';
import 'package:karaokeparty/search/cubit/search_filter_cubit.dart';
import 'package:karaokeparty/widgets/filter_bar.dart';
import 'package:karaokeparty/widgets/song_card.dart';

const _pageSize = 20;

class Browse extends StatefulWidget {
  const Browse({required this.api, super.key});

  final ServerApi api;

  @override
  State<Browse> createState() => _BrowseState();
}

class _BrowseState extends State<Browse> {
  final _pagingController = PagingController<int, Song>(firstPageKey: 0);

  @override
  void initState() {
    super.initState();
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int pageKey) async {
    final searchFilter = context.read<SearchFilterCubit>();
    try {
      final newSongs = await widget.api.fetchSongs(pageKey, _pageSize, filter: searchFilter);
      if (newSongs != null) {
        final isLastPage = newSongs.length < _pageSize;
        log.d('isLastPage = $isLastPage');
        if (isLastPage) {
          _pagingController.appendLastPage(newSongs);
        } else {
          final nextPageKey = pageKey + newSongs.length;
          _pagingController.appendPage(newSongs, nextPageKey);
        }
      }
    } catch (e) {
      _pagingController.error = e;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Card(
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: FilterBar(
                api: widget.api,
                child: Text(
                  context.t.search.browseTitle,
                  style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSecondaryContainer),
                ),
              ),
            ),
          ),
        ),
        BlocListener<SearchFilterCubit, SearchFilterState>(
          listener: (context, state) {
            _pagingController.refresh();
            _pagingController.value = const PagingState();
          },
          child: PagedSliverList<int, Song>(
            pagingController: _pagingController,
            builderDelegate: PagedChildBuilderDelegate<Song>(
              itemBuilder: (context, item, index) => SongCard(song: item, api: widget.api),
            ),
          ),
        ),
      ],
    );
  }
}
