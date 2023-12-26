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
  const WebSocketConnectedState({required this.sink, required this.songCount, required this.isAdmin});

  final WebSocketSink sink;
  final int songCount;
  final bool isAdmin;
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
