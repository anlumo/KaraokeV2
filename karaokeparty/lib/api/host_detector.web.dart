// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html';

final class Host {
  final String media;
  final String api;
  final String wsUrl;

  Host({required this.media, required this.api, required this.wsUrl});
}

FutureOr<Host> host() {
  return Host(
    media: '${window.location.origin}/media',
    api: '${window.location.origin}/api',
    wsUrl: '${window.location.origin.replaceFirst('http:', 'ws:').replaceFirst('https:', 'wss:')}/ws',
  );
}
