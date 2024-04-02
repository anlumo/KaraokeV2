import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';
import 'package:karaokeparty/api/cubit/connection_cubit.dart';
import 'package:karaokeparty/api/cubit/playlist_cubit.dart';
import 'package:karaokeparty/model/song.dart';
import 'package:http/http.dart' as http;

import 'package:karaokeparty/api/host_detector.io.dart'
    if (dart.library.html) 'package:karaokeparty/api/host_detector.web.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:karaokeparty/api/host_detector.io.dart'
    if (dart.library.html) 'package:karaokeparty/api/host_detector.web.dart' show Host;

late Host serverHost;
final client = http.Client();

final class ServerError implements Exception {
  final Response response;

  ServerError(this.response);
}

final class ServerApi {
  ServerApi(SharedPreferences sharedPreferences) : connectionCubit = ConnectionCubit(sharedPreferences);
  final ConnectionCubit connectionCubit;
  final playlist = PlaylistCubit();

  Future<void> connect() async {
    serverHost = await host();

    return connectionCubit.connect(playlist);
  }

  int? get songCount => switch (connectionCubit.state) {
        InitialWebSocketConnectionState() || WebSocketConnectingState() || WebSocketConnectionFailedState() => null,
        WebSocketConnectedState(:final songCount) => songCount,
      };

  Future<List<Song>> search(String text) async {
    final response = await client.post(Uri.parse('${serverHost.api}/search'), body: utf8.encode(text));
    if (response.statusCode != 200) {
      throw ServerError(response);
    }
    final json = utf8.decode(response.bodyBytes);
    return (jsonDecode(json) as List<dynamic>)
        .map((song) => Song.fromJson(song as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<Song>?> fetchSongs(int offset, int perPage) async {
    final response = await client.get(Uri.parse('${serverHost.api}/all_songs?offset=$offset&per_page=$perPage'));
    if (response.statusCode != 200) {
      throw ServerError(response);
    }
    final json = utf8.decode(response.bodyBytes);
    return (jsonDecode(json) as List<dynamic>).map((song) => Song.fromJson(song)).toList(growable: false);
  }

  Future<Song?> fetchSongByOffset(int offset) async {
    final response = await client.get(Uri.parse('${serverHost.api}/all_songs?offset=$offset&per_page=1'));
    if (response.statusCode != 200) {
      throw ServerError(response);
    }
    final json = utf8.decode(response.bodyBytes);
    return (jsonDecode(json) as List<dynamic>).map((song) => Song.fromJson(song)).firstOrNull;
  }

  Future<List<Song>?> fetchRandomSongs(int count, {String? query}) async {
    var uri = Uri.parse('${serverHost.api}/random_songs');
    final queryParameters = <String, String>{
      'count': count.toString(),
      if (query != null) 'query': query,
    };
    final response = await client.get(uri.replace(queryParameters: queryParameters));
    if (response.statusCode != 200) {
      throw ServerError(response);
    }
    final json = utf8.decode(response.bodyBytes);
    return (jsonDecode(json) as List<dynamic>).map((song) => Song.fromJson(song)).toList(growable: false);
  }

  void submitSong({required String singer, required int songId}) {
    switch (connectionCubit.state) {
      case InitialWebSocketConnectionState():
      case WebSocketConnectingState():
      case WebSocketConnectionFailedState():
        return;
      case WebSocketConnectedState(:final sink):
        sink.add(jsonEncode({
          'cmd': 'add',
          'song': songId,
          'singer': singer,
        }));
    }
  }

  Future<void> suggestSong({required String name, required String artist, required String title}) async {
    var uri = Uri.parse('${serverHost.api}/suggest');
    final suggestion = <String, String>{
      'name': name,
      'artist': artist,
      'title': title,
    };
    final response = await client.post(uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(suggestion));
    if (response.statusCode ~/ 100 != 2) {
      throw ServerError(response);
    }
  }
}
