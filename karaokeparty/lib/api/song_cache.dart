import 'dart:async';
import 'dart:convert';

import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/model/song.dart';

final class SongCache {
  final Map<int, Song?> _cache = {};

  FutureOr<Song?> get(int id) {
    final cached = _cache[id];
    if (cached != null) {
      return cached;
    }
    return client.get(Uri.parse('${serverHost.api}/song?id=$id')).then((response) {
      if (response.statusCode != 200) {
        _cache[id] = null;
        return null;
      }
      final text = utf8.decode(response.bodyBytes);
      final song = Song.fromJson(jsonDecode(text) as Map<String, dynamic>);
      _cache[id] = song;
      return song;
    });
  }
}
