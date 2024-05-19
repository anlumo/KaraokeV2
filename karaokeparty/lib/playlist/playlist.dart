import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/api/cubit/connection_cubit.dart';
import 'package:karaokeparty/api/cubit/playlist_cubit.dart';
import 'package:karaokeparty/api/song_cache.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/main.dart';
import 'package:karaokeparty/model/playlist_entry.dart';
import 'package:karaokeparty/playlist/admin_list.dart';
import 'package:karaokeparty/playlist/user_list.dart';
import 'package:karaokeparty/search/empty_state.dart';

class Playlist extends StatefulWidget {
  const Playlist({required this.songCache, required this.api, super.key});

  final SongCache songCache;
  final ServerApi api;

  @override
  State<Playlist> createState() => _PlaylistState();
}

class _PlaylistState extends State<Playlist> {
  List<PlaylistEntry>? _songQueue;
  int? _songQueueNowPlaying;
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

  @override
  void dispose() {
    _listFocusNode.dispose();
    super.dispose();
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
          WebSocketConnectedState(:final isAdmin, :final password) => BlocConsumer<PlaylistCubit, PlaylistState>(
              listener: (context, state) {
                log.d('Received list update: $state');
                _songQueue = List.from(state.playHistory.followedBy(state.songQueue));
                _songQueueNowPlaying = state.playHistory.length - 1;
                if (_songQueue!.isNotEmpty && _selectedItem > _songQueue!.length - 1) {
                  setState(() {
                    _selectedItem = _songQueue!.length - 1;
                  });
                }
              },
              builder: (context, state) {
                final passwordHash =
                    password != null ? sha256.convert(utf8.encode(password.toString())).toString() : null;
                _songQueue ??= List.from(state.playHistory.followedBy(state.songQueue));
                _songQueueNowPlaying ??= state.playHistory.length - 1;
                if (_songQueue?.isEmpty ?? true) {
                  return Center(
                    child: EmptyState(api: widget.api, explanation: context.t.playlist.emptyState),
                  );
                }
                log.d('_songQueueNowPlaying = $_songQueueNowPlaying');
                if (isAdmin) {
                  return SlidableAutoCloseBehavior(
                    child: Focus(
                      focusNode: _listFocusNode,
                      onKeyEvent: itemOnKey,
                      autofocus: true,
                      child: AdminList(
                          api: widget.api,
                          songCache: widget.songCache,
                          songQueue: _songQueue!,
                          songQueueNowPlaying: _songQueueNowPlaying,
                          selectedItem: _selectedItem,
                          onSelectItem: (index) => setState(() {
                                _selectedItem = index;
                              }),
                          onUpdateQueue: (queue) => setState(() {
                                _songQueue = queue;
                              })),
                    ),
                  );
                } else if (_songQueue != null) {
                  return UserList(
                    api: widget.api,
                    songCache: widget.songCache,
                    songQueue: _songQueue!,
                    songQueueNowPlaying: _songQueueNowPlaying,
                    passwordHash: passwordHash,
                    onRemove: passwordHash != null ? (id) => connectionState.remove(id) : null,
                  );
                } else {
                  return const SizedBox();
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
