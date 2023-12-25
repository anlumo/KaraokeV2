import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:karaokeparty/api/cubit/playlist_cubit.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/main.dart';
import 'package:karaokeparty/model/playlist_entry.dart';
import 'package:karaokeparty/model/song.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

const serverApi = 'http://localhost:8080';
final client = http.Client();
final random = Random();

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
  int? songCount;

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

    final response = await client.get(Uri.parse('$serverApi/song_count'));
    if (response.statusCode == 200) {
      songCount = int.tryParse(response.body);
    }
  }

  Future<List<Song>> search(String text) async {
    final response = await client.post(Uri.parse('$serverApi/search'), body: utf8.encode(text));
    if (response.statusCode != 200) {
      throw Exception(response);
    }
    final json = utf8.decode(response.bodyBytes);
    return (jsonDecode(json) as List<dynamic>)
        .map((song) => Song.fromJson(song as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Song?> fetchSongByOffset(int offset) async {
    final response = await client.get(Uri.parse('$serverApi/all_songs?offset=$offset&per_page=1'));
    if (response.statusCode != 200) {
      return null;
    }
    final json = utf8.decode(response.bodyBytes);
    return (jsonDecode(json) as List<dynamic>).map((song) => Song.fromJson(song)).firstOrNull;
  }

  Future<Song?> fetchRandomSong() async {
    if (songCount != null) {
      final songIndex = random.nextInt(songCount!);
      return await fetchSongByOffset(songIndex);
    }
    return null;
  }
}
