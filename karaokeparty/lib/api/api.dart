import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:karaokeparty/api/cubit/connection_cubit.dart';
import 'package:karaokeparty/api/cubit/playlist_cubit.dart';
import 'package:karaokeparty/model/song.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

const serverApi = 'http://localhost:8080';
final client = http.Client();
final random = Random();

final class ServerApi {
  final connectionCubit = ConnectionCubit();
  final playlist = PlaylistCubit();

  Future<void> connect() {
    return connectionCubit.connect(playlist);
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
    switch (connectionCubit.state) {
      case InitialConnectionState():
      case ConnectingState():
      case ConnectionFailedState():
        return null;
      case ConnectedState(:final songCount):
        final songIndex = random.nextInt(songCount);
        return await fetchSongByOffset(songIndex);
    }
  }

  Future<UuidValue?> submitSong({required String singer, required int songId}) async {
    // switch ()
    return null;
  }
}
