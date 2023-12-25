import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/main.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

sealed class ConnectionState {
  const ConnectionState();
}

final class ConnectingState extends ConnectionState {
  const ConnectingState();
}

final class ConnectedState extends ConnectionState {
  const ConnectedState();
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

final class ServerApi {
  final connectedController = StreamController<ConnectionState>.broadcast();

  Future<void> connect() async {
    final wsUrl = Uri.parse('ws://localhost:8080/ws');
    log.d('Connecting to $wsUrl...');
    connectedController.add(const ConnectingState());
    final channel = WebSocketChannel.connect(wsUrl);

    try {
      await channel.ready;
    } on Exception catch (e) {
      connectedController.add(ConnectionFailedState(e));
      return;
    }

    log.d('Connected to web socket!');
    connectedController.add(const ConnectedState());

    channel.stream.listen((message) {}, onError: (error) {
      log.e('Websocket connection failed: $error');
      connectedController.add(ConnectionFailedState(error));
    }, onDone: () {
      log.e('Websocket connection closed');
      connectedController.add(const ConnectingState());
      connect();
    });
  }
}
