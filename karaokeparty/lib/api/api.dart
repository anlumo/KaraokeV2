import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:karaokeparty/api/cubit/playlist_cubit.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/main.dart';
import 'package:karaokeparty/model/playlist_entry.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const serverApi = 'http://localhost:8080';

sealed class ConnectionState {
  const ConnectionState();
}

final class ConnectingState extends ConnectionState {
  const ConnectingState();
}

final class ConnectedState extends ConnectionState {
  const ConnectedState();
}

final class ConnectionFailedState extends ConnectionState {
  const ConnectionFailedState(this.exception);

  final Exception exception;

  String description(BuildContext context) {
    if (exception is SocketException && (exception as SocketException).osError?.errorCode == 111) {
      return context.t.core.connection.connectionRefusedError;
    }
    // we might need to prettify more errors here!
    // connection timeout, etc?
    return exception.toString();
  }
}

final class ServerApi {
  final connectedController = StreamController<ConnectionState>.broadcast();
  final playlist = PlaylistCubit();

  Future<void> connect() async {
    final wsUrl = Uri.parse('ws://localhost:8080/ws');
    log.d('Connecting to $wsUrl...');
    connectedController.add(const ConnectingState());
    final channel = WebSocketChannel.connect(wsUrl);

    try {
      await channel.ready;
    } on Exception catch (e) {
      connectedController.add(ConnectionFailedState(e));
      return;
    }

    log.d('Connected to web socket!');
    connectedController.add(const ConnectedState());

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
      connectedController.add(ConnectionFailedState(error));
    }, onDone: () {
      log.e('Websocket connection closed');
      connectedController.add(const ConnectingState());
      connect();
    });
  }
}
