import 'package:animated_list_plus/animated_list_plus.dart';
import 'package:animated_list_plus/transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/api/cubit/connection_cubit.dart';
import 'package:karaokeparty/api/cubit/playlist_cubit.dart';
import 'package:karaokeparty/api/song_cache.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/model/playlist_entry.dart';
import 'package:karaokeparty/search/empty_state.dart';
import 'package:karaokeparty/widgets/song_card.dart';

class Playlist extends StatefulWidget {
  const Playlist({required this.songCache, required this.api, super.key});

  final SongCache songCache;
  final ServerApi api;

  @override
  State<Playlist> createState() => _PlaylistState();
}

class _PlaylistState extends State<Playlist> {
  List<PlaylistEntry>? _songQueue;
  late final FocusNode _listFocusNode;
  int _selectedItem = 0;

  @override
  void initState() {
    super.initState();
    _listFocusNode = FocusNode(
        debugLabel: 'playlist',
        descendantsAreTraversable: false,
        descendantsAreFocusable: false,
        onKeyEvent: itemOnKey);
  }

  WebSocketConnectedState? connectionFromFocusNode(FocusNode focusNode) {
    final context = focusNode.context;
    if (context != null) {
      final connection = context.read<ConnectionCubit>();
      switch (connection.state) {
        case InitialWebSocketConnectionState():
        case WebSocketConnectingState():
        case WebSocketConnectionFailedState():
          break;
        case WebSocketConnectedState():
          return connection.state as WebSocketConnectedState;
      }
    }
    return null;
  }

  KeyEventResult itemOnKey(FocusNode focusNode, KeyEvent event) {
    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        if (_selectedItem > 0) {
          final keys = HardwareKeyboard.instance.logicalKeysPressed;
          if (keys.contains(LogicalKeyboardKey.alt) ||
              keys.contains(LogicalKeyboardKey.altLeft) ||
              keys.contains(LogicalKeyboardKey.altRight) ||
              keys.contains(LogicalKeyboardKey.altGraph)) {
            final connection = connectionFromFocusNode(focusNode);
            if (connection != null) {
              if (_selectedItem > 1) {
                connection.moveAfter(_songQueue![_selectedItem].id, after: _songQueue![_selectedItem - 2].id);
              } else {
                connection.moveTop(_songQueue![_selectedItem].id);
              }
            }
          }
          setState(() {
            _selectedItem -= 1;
          });
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        if (_selectedItem < (_songQueue?.length ?? 0) - 1) {
          final keys = HardwareKeyboard.instance.logicalKeysPressed;
          if (keys.contains(LogicalKeyboardKey.alt) ||
              keys.contains(LogicalKeyboardKey.altLeft) ||
              keys.contains(LogicalKeyboardKey.altRight) ||
              keys.contains(LogicalKeyboardKey.altGraph)) {
            final connection = connectionFromFocusNode(focusNode);
            connection?.moveAfter(_songQueue![_selectedItem].id, after: _songQueue![_selectedItem + 1].id);
          }
          setState(() {
            _selectedItem += 1;
          });
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
        setState(() {
          _selectedItem = 0;
        });
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        setState(() {
          _selectedItem = (_songQueue?.length ?? 1) - 1;
        });
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
        final connection = connectionFromFocusNode(focusNode);
        connection?.play(_songQueue![_selectedItem].id);
        return connection != null ? KeyEventResult.handled : KeyEventResult.ignored;
      case LogicalKeyboardKey.delete:
      case LogicalKeyboardKey.backspace:
        final connection = connectionFromFocusNode(focusNode);
        connection?.remove(_songQueue![_selectedItem].id);
        return connection != null ? KeyEventResult.handled : KeyEventResult.ignored;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectionCubit, WebSocketConnectionState>(
      builder: (context, connectionState) {
        final theme = Theme.of(context);
        return switch (connectionState) {
          InitialWebSocketConnectionState() || WebSocketConnectingState() => const Center(
              child: SizedBox(width: 50, height: 50, child: CircularProgressIndicator()),
            ),
          WebSocketConnectedState(:final isAdmin) => BlocConsumer<PlaylistCubit, PlaylistState>(
              listener: (context, state) {
                _songQueue = List.from(state.songQueue);
                if (_songQueue!.isNotEmpty && _selectedItem > _songQueue!.length - 1) {
                  setState(() {
                    _selectedItem = _songQueue!.length - 1;
                  });
                }
              },
              builder: (context, state) {
                _songQueue ??= List.from(state.songQueue);
                if (_songQueue?.isEmpty ?? true) {
                  return Center(
                    child: EmptyState(api: widget.api, explanation: context.t.playlist.emptyState),
                  );
                }
                if (isAdmin) {
                  return SlidableAutoCloseBehavior(
                    child: Focus(
                      focusNode: _listFocusNode,
                      onKeyEvent: itemOnKey,
                      autofocus: true,
                      child: ImplicitlyAnimatedReorderableList<PlaylistEntry>(
                        items: _songQueue!,
                        itemBuilder: (context, itemAnimation, item, i) {
                          return Reorderable(
                            key: ValueKey(item.id),
                            builder: (context, dragAnimation, inDrag) {
                              return AnimatedBuilder(
                                  animation: dragAnimation,
                                  builder: (context, child) {
                                    final listItem = Row(
                                      children: [
                                        Tooltip(
                                          message: context.t.playlist.playTooltip,
                                          child: IconButton(
                                              onPressed: () {
                                                connectionState.play(item.id);
                                              },
                                              icon: const Icon(Icons.play_arrow)),
                                        ),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _selectedItem = i;
                                              });
                                            },
                                            child: PlaylistSongCard(
                                              songCache: widget.songCache,
                                              entry: item,
                                              api: widget.api,
                                              selected: _selectedItem == i,
                                              predictedPlayTime: i > 0 ? _songQueue![i - 1].predictedEnd : null,
                                            ),
                                          ),
                                        ),
                                        Tooltip(
                                          message: context.t.playlist.rearrangeTooltip,
                                          child: SizeFadeTransition(
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
                                                  connectionState.remove(item.id);
                                                  _songQueue!.removeWhere((element) => element.id == item.id);
                                                },
                                              ),
                                            ]),
                                        child: inDrag
                                            ? ColoredBox(
                                                color: theme.colorScheme.secondary.withOpacity(0.5), child: listItem)
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
                            connectionState.moveAfter(item.id, after: newItems[to - 1].id);
                          } else {
                            connectionState.moveTop(item.id);
                          }
                          _songQueue = newItems;
                        },
                      ),
                    ),
                  );
                } else {
                  return ImplicitlyAnimatedList<PlaylistEntry>(
                    primary: true,
                    items: _songQueue!,
                    itemBuilder: (context, itemAnimation, item, i) {
                      return PlaylistSongCard(
                        songCache: widget.songCache,
                        entry: item,
                        api: widget.api,
                        predictedPlayTime: i > 0 ? _songQueue![i - 1].predictedEnd : null,
                      );
                    },
                    areItemsTheSame: (a, b) => a.id == b.id,
                  );
                }
              },
            ),
          WebSocketConnectionFailedState() => Center(
                child: Text(
              (connectionState).description(context),
              style: theme.textTheme.bodyLarge!.copyWith(color: theme.colorScheme.error),
            )),
        };
      },
    );
  }
}
