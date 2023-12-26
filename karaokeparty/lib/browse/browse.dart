import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/model/song.dart';
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
    try {
      final newSongs = await widget.api.fetchSongs(pageKey, _pageSize);
      final songCount = widget.api.songCount;
      if (newSongs != null && songCount != null) {
        final isLastPage = pageKey + _pageSize >= songCount;
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
    return PagedListView(
        pagingController: _pagingController,
        builderDelegate: PagedChildBuilderDelegate<Song>(
          itemBuilder: (context, item, index) => SongCard(song: item, api: widget.api),
        ));
  }
}
