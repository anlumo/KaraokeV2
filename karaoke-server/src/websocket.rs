use std::net::SocketAddr;

use axum::{
    extract::{
        ws::{Message, WebSocket},
        ConnectInfo, WebSocketUpgrade,
    },
    response::IntoResponse,
};
use futures_util::{SinkExt, StreamExt};

pub async fn ws_handler(
    ws: WebSocketUpgrade,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
) -> impl IntoResponse {
    log::debug!("Websocket at {addr} connected.");
    ws.on_upgrade(move |socket| handle_socket(socket, addr))
}

async fn handle_socket(socket: WebSocket, who: SocketAddr) {
    let (mut sender, mut receiver) = socket.split();

    while let Some(msg) = receiver.next().await {
        match msg {
            Ok(Message::Text(text)) => {
                log::debug!("[{who:?}] Received text {text:?}");
            }
            Ok(Message::Binary(_bin)) => {}
            Ok(Message::Ping(data)) => sender.send(Message::Pong(data)).await.unwrap(),
            Ok(Message::Pong(_)) => {}
            Ok(Message::Close(_)) => return,
            Err(err) => {
                log::error!("[{who:?}]: {err:?}");
                return;
            }
        }
    }
}
