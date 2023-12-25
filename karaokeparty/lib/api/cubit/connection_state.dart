part of 'connection_cubit.dart';

sealed class ConnectionState {
  const ConnectionState();
}

final class InitialConnectionState extends ConnectionState {
  const InitialConnectionState();
}

final class ConnectingState extends ConnectionState {
  const ConnectingState();
}

final class ConnectedState extends ConnectionState {
  const ConnectedState({required this.sink, required this.songCount});

  final WebSocketSink sink;
  final int songCount;
}

final class ConnectionFailedState extends ConnectionState {
  const ConnectionFailedState(this.exception);

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
