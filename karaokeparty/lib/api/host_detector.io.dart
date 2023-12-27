import 'dart:async';

final class Host {
  final String api;
  final String wsUrl;

  Host({required this.api, required this.wsUrl});
}

FutureOr<Host> baseUri() {
  return Host(api: 'http://localhost:8080/api', wsUrl: 'ws://localhost:8080/ws');
}
