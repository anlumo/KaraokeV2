// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html';

final class Host {
  final String covers;
  final String api;
  final String wsUrl;

  Host({required this.covers, required this.api, required this.wsUrl});
}

FutureOr<Host> host() {
  return Host(
    covers: '${window.location.origin}/cover',
    api: '${window.location.origin}/api',
    wsUrl: '${window.location.origin.replaceFirst('http:', 'ws:').replaceFirst('https:', 'wss:')}/ws',
  );
}
