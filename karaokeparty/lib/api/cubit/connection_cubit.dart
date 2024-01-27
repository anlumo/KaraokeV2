import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/api/cubit/playlist_cubit.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/main.dart';
import 'package:karaokeparty/model/playlist_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

part 'connection_state.dart';

class ConnectionCubit extends Cubit<WebSocketConnectionState> {
  ConnectionCubit(this.sharedPreferences) : super(const InitialWebSocketConnectionState());

  SharedPreferences sharedPreferences;
  Completer<bool>? _loginListener;

  Future<void> connect(PlaylistCubit playlist) async {
    final wsUrl = Uri.parse(serverHost.wsUrl);
    log.d('Connecting to $wsUrl...');

    emit(const WebSocketConnectingState());
    final channel = WebSocketChannel.connect(wsUrl);

    try {
      await channel.ready;
    } on Exception catch (e) {
      emit(WebSocketConnectionFailedState(e));
      return;
    }

    log.d('Connected to web socket!');
    final response = await client.get(Uri.parse('${serverHost.api}/song_count'));
    if (response.statusCode != 200) {
      emit(WebSocketConnectionFailedState(
          Exception('Couldn\'t fetch song count, server returned status ${response.statusCode}.')));
      return;
    }
    final songCount = int.tryParse(response.body);
    if (songCount == null) {
      emit(WebSocketConnectionFailedState(Exception('Couldn\'t parse song count: ${response.body}')));
      return;
    }
    final password = sharedPreferences.getString("password");
    if (password != null) {
      channel.sink.add(jsonEncode({
        'cmd': 'authenticate',
        'password': password,
      }));
    }

    final languagesResponse = await client.get(Uri.parse('${serverHost.api}/languages'));
    if (response.statusCode != 200) {
      emit(WebSocketConnectionFailedState(
          Exception('Couldn\'t fetch languages list, server returned status ${response.statusCode}.')));
      return;
    }

    final languages = (jsonDecode(languagesResponse.body) as List).whereType<String>().toList(growable: false);
    emit(WebSocketConnectedState(sink: channel.sink, songCount: songCount, isAdmin: false, languages: languages));

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
          final playHistoryJson = json['playHistory'];
          final List<PlaylistEntry> playHistory = (playHistoryJson is List<dynamic>)
              ? playHistoryJson.map((entry) => PlaylistEntry.fromJson(entry)).toList(growable: false)
              : const [];

          List<PlaylistEntry> songQueue = (json['list'] as List<dynamic>)
              .map((entry) => PlaylistEntry.fromJson(entry as Map<String, dynamic>))
              .toList(growable: false);

          playlist.update(playHistory: playHistory, songQueue: songQueue);
        } catch (e) {
          log.e('Failed parsing server message: $e');
        }
      } else if (message is Uint8List) {
        final success = message[0] == 1;
        if (_loginListener != null) {
          _loginListener!.complete(success);
          _loginListener = null;
        }
        emit(WebSocketConnectedState(sink: channel.sink, songCount: songCount, isAdmin: success, languages: languages));
      }
    }, onError: (error) {
      log.e('Websocket connection failed: $error');
      if (_loginListener != null) {
        _loginListener!.completeError(error);
        _loginListener = null;
      }
      emit(WebSocketConnectionFailedState(error));
    }, onDone: () {
      log.e('Websocket connection closed');
      connect(playlist);
    });
  }

  Future<bool> login(String password) async {
    await sharedPreferences.setString("password", password);
    _loginListener = Completer<bool>();

    switch (state) {
      case InitialWebSocketConnectionState():
      case WebSocketConnectingState():
      case WebSocketConnectionFailedState():
        // Will log in once we're connected
        break;
      case WebSocketConnectedState(:final sink):
        sink.add(jsonEncode({
          'cmd': 'authenticate',
          'password': password,
        }));
    }
    return await _loginListener!.future;
  }

  Future<bool> logout() async {
    await sharedPreferences.remove("password");
    _loginListener = Completer<bool>();

    switch (state) {
      case InitialWebSocketConnectionState():
      case WebSocketConnectingState():
      case WebSocketConnectionFailedState():
        // Will log in once we're connected
        break;
      case WebSocketConnectedState(:final sink):
        sink.add(jsonEncode({
          'cmd': 'authenticate',
          'password': '',
        }));
    }
    return await _loginListener!.future;
  }
}
