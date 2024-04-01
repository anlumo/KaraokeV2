import 'package:animated_list_plus/animated_list_plus.dart';
import 'package:animated_list_plus/transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/api/cubit/connection_cubit.dart';
import 'package:karaokeparty/api/song_cache.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/main.dart';
import 'package:karaokeparty/model/playlist_entry.dart';
import 'package:karaokeparty/now_playing/now_playing.dart';
import 'package:karaokeparty/widgets/song_card.dart';

class AdminList extends StatelessWidget {
  const AdminList({
    required this.api,
    required this.songCache,
    required this.songQueue,
    required this.songQueueNowPlaying,
    required this.selectedItem,
    required this.onSelectItem,
    required this.onUpdateQueue,
    super.key,
  });

  final SongCache songCache;
  final ServerApi api;
  final List<PlaylistEntry> songQueue;
  final int? songQueueNowPlaying;
  final int? selectedItem;
  final Function(int index) onSelectItem;
  final Function(List<PlaylistEntry>) onUpdateQueue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<ConnectionCubit, WebSocketConnectionState>(
      builder: (context, connectionState) {
        return ImplicitlyAnimatedReorderableList<PlaylistEntry>(
          items: songQueue,
          itemBuilder: (context, itemAnimation, item, i) {
            return Reorderable(
              key: ValueKey(item.id),
              builder: (context, dragAnimation, inDrag) {
                return AnimatedBuilder(
                    animation: dragAnimation,
                    builder: (context, child) {
                      log.d('render item $i singer ${item.singer}');

                      if (i == songQueueNowPlaying) {
                        return NowPlaying(songCache: songCache, api: api, entry: item);
                      }
                      if (songQueueNowPlaying != null && i < songQueueNowPlaying!) {
                        return PlaylistSongCard(
                          songCache: songCache,
                          entry: item,
                          api: api,
                          selected: selectedItem == i,
                          predictedPlayTime: null,
                        );
                      }

                      final listItem = Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              (connectionState as WebSocketConnectedState).play(item.id);
                            },
                            icon: const Icon(Icons.play_arrow),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => onSelectItem(i),
                              child: PlaylistSongCard(
                                songCache: songCache,
                                entry: item,
                                api: api,
                                selected: selectedItem == i,
                                predictedPlayTime: (i > 0 && (songQueueNowPlaying == null || i > songQueueNowPlaying!))
                                    ? songQueue[i - 1].predictedEnd
                                    : null,
                              ),
                            ),
                          ),
                          SizeFadeTransition(
                            animation: itemAnimation,
                            child: Handle(
                              delay: const Duration(milliseconds: 600),
                              child: MouseRegion(
                                cursor: inDrag ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
                                child: const SizedBox(
                                  height: 80,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Icon(Icons.menu),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );

                      return SizeFadeTransition(
                        animation: itemAnimation,
                        sizeFraction: 0.7,
                        curve: Curves.easeInOut,
                        child: Slidable(
                          key: ValueKey(item.id),
                          groupTag: '0',
                          endActionPane: ActionPane(
                              motion: const ScrollMotion(),
                              dragDismissible: false,
                              // dismissible: DismissiblePane(onDismissed: () {
                              //   setState(() {});
                              // }),
                              children: [
                                SlidableAction(
                                  flex: 2,
                                  autoClose: true,
                                  backgroundColor: theme.colorScheme.error,
                                  foregroundColor: theme.colorScheme.onError,
                                  icon: Icons.delete,
                                  label: context.t.playlist.deleteLabel,
                                  onPressed: (context) {
                                    (connectionState as WebSocketConnectedState).remove(item.id);
                                    final newList = List<PlaylistEntry>.from(songQueue);
                                    newList.removeWhere((element) => element.id == item.id);
                                    onUpdateQueue(newList);
                                  },
                                ),
                              ]),
                          child: inDrag
                              ? ColoredBox(color: theme.colorScheme.secondary.withOpacity(0.5), child: listItem)
                              : listItem,
                        ),
                      );
                    });
              },
            );
          },
          areItemsTheSame: (a, b) => a.id == b.id,
          onReorderFinished: (item, from, to, newItems) {
            if (to > 0) {
              (connectionState as WebSocketConnectedState).moveAfter(item.id, after: newItems[to - 1].id);
            } else {
              (connectionState as WebSocketConnectedState).moveTop(item.id);
            }
            onUpdateQueue(newItems);
          },
        );
      },
    );
  }
}
