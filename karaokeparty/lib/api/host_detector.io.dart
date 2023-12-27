import 'dart:async';

final class Host {
  final String media;
  final String api;
  final String wsUrl;

  Host({required this.media, required this.api, required this.wsUrl});
}

FutureOr<Host> host() {
  return Host(media: 'http://localhost:8080/media', api: 'http://localhost:8080/api', wsUrl: 'ws://localhost:8080/ws');
}
