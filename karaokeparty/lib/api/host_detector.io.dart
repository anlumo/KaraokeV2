import 'dart:async';

final class Host {
  final String covers;
  final String api;
  final String wsUrl;

  Host({required this.covers, required this.api, required this.wsUrl});
}

FutureOr<Host> host() {
  return Host(covers: 'http://localhost:8080/cover', api: 'http://localhost:8080/api', wsUrl: 'ws://localhost:8080/ws');
}
