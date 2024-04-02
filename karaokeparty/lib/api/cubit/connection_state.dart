part of 'connection_cubit.dart';

sealed class WebSocketConnectionState {
  const WebSocketConnectionState();
}

final class InitialWebSocketConnectionState extends WebSocketConnectionState {
  const InitialWebSocketConnectionState();
}

final class WebSocketConnectingState extends WebSocketConnectionState {
  const WebSocketConnectingState();
}

final class WebSocketConnectedState extends WebSocketConnectionState {
  const WebSocketConnectedState(
      {required this.sink, required this.songCount, required this.isAdmin, required this.languages});

  final WebSocketSink sink;
  final int songCount;
  final bool isAdmin;
  final List<String> languages;

  void submitSong({required String singer, required int songId}) {
    sink.add(jsonEncode({
      'cmd': 'add',
      'song': songId,
      'singer': singer,
    }));
  }

  void play(UuidValue playlistEntry) {
    sink.add(jsonEncode({
      'cmd': 'play',
      'id': playlistEntry.uuid,
    }));
  }

  void remove(UuidValue playlistEntry) {
    sink.add(jsonEncode({
      'cmd': 'remove',
      'id': playlistEntry.uuid,
    }));
  }

  void swap(UuidValue id1, UuidValue id2) {
    sink.add(jsonEncode({
      'cmd': 'swap',
      'id1': id1.uuid,
      'id2': id2.uuid,
    }));
  }

  void moveAfter(UuidValue id, {required UuidValue after}) {
    sink.add(jsonEncode({
      'cmd': 'moveAfter',
      'id': id.uuid,
      'after': after.uuid,
    }));
  }

  void moveTop(UuidValue id) {
    sink.add(jsonEncode({
      'cmd': 'moveTop',
      'id': id.uuid,
    }));
  }

  void reportBug(int songId, String report) {
    sink.add(jsonEncode({
      'cmd': 'reportBug',
      'song': songId,
      'report': report,
    }));
  }
}

final class WebSocketConnectionFailedState extends WebSocketConnectionState {
  const WebSocketConnectionFailedState(this.exception);

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
