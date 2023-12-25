import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/api/cubit/playlist_cubit.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/main.dart';
import 'package:karaokeparty/model/playlist_entry.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

part 'connection_state.dart';

class ConnectionCubit extends Cubit<ConnectionState> {
  ConnectionCubit() : super(const InitialConnectionState());

  Future<void> connect(PlaylistCubit playlist) async {
    final wsUrl = Uri.parse('ws://localhost:8080/ws');
    log.d('Connecting to $wsUrl...');
    emit(const ConnectingState());
    final channel = WebSocketChannel.connect(wsUrl);

    try {
      await channel.ready;
    } on Exception catch (e) {
      emit(ConnectionFailedState(e));
      return;
    }

    log.d('Connected to web socket!');
    final response = await client.get(Uri.parse('$serverApi/song_count'));
    if (response.statusCode != 200) {
      emit(ConnectionFailedState(
          Exception('Couldn\'t fetch song count, server returned status ${response.statusCode}.')));
    }
    final songCount = int.tryParse(response.body);
    if (songCount == null) {
      emit(ConnectionFailedState(Exception('Couldn\'t parse song count: ${response.body}')));
      return;
    }
    emit(ConnectedState(sink: channel.sink, songCount: songCount));

    channel.stream.listen((message) {
      if (message is String) {
        final Map<String, dynamic> json;
        try {
          json = jsonDecode(message) as Map<String, dynamic>;
        } catch (e) {
          log.e('Decoding json from websocket failed: $e');
          return;
        }
        log.d('Received websocket message $json');
        try {
          PlaylistEntry? nowPlaying;
          if (json['now_playing'] != null) {
            nowPlaying = PlaylistEntry.fromJson(json['now_playing']);
          }
          List<PlaylistEntry> songQueue = (json['list'] as List<dynamic>)
              .map((entry) => PlaylistEntry.fromJson(entry as Map<String, dynamic>))
              .toList(growable: false);

          playlist.update(nowPlaying: nowPlaying, songQueue: songQueue);
        } catch (e) {
          log.e('Failed parsing server message: $e');
        }
      }
    }, onError: (error) {
      log.e('Websocket connection failed: $error');
      emit(ConnectionFailedState(error));
    }, onDone: () {
      log.e('Websocket connection closed');
      connect(playlist);
    });
  }
}
