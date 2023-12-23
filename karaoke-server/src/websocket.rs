use std::{net::SocketAddr, sync::Arc};

use axum::{
    extract::{
        ws::{Message, WebSocket},
        ConnectInfo, State, WebSocketUpgrade,
    },
    response::IntoResponse,
};
use futures_util::{SinkExt, StreamExt};

use crate::AppState;

pub async fn ws_handler(
    ws: WebSocketUpgrade,
    State(state): State<Arc<AppState>>,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
) -> impl IntoResponse {
    log::debug!("Websocket at {addr} connected.");
    ws.on_upgrade(move |socket| handle_socket(socket, addr, state))
}

async fn handle_socket(socket: WebSocket, who: SocketAddr, state: Arc<AppState>) {
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
