use std::net::SocketAddr;

use axum::{
    extract::{ws::WebSocket, ConnectInfo, WebSocketUpgrade},
    response::IntoResponse,
};
use axum_extra::{headers, TypedHeader};
use futures_util::StreamExt;

pub async fn ws_handler(
    ws: WebSocketUpgrade,
    user_agent: Option<TypedHeader<headers::UserAgent>>,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
) -> impl IntoResponse {
    let user_agent = if let Some(TypedHeader(user_agent)) = user_agent {
        user_agent.to_string()
    } else {
        String::from("Unknown browser")
    };
    println!("`{user_agent}` at {addr} connected.");
    // finalize the upgrade process by returning upgrade callback.
    // we can customize the callback by sending additional info such as address.
    ws.on_upgrade(move |socket| handle_socket(socket, addr))
}

async fn handle_socket(socket: WebSocket, _who: SocketAddr) {
    let (mut sender, mut receiver) = socket.split();

    while let Some(msg) = receiver.next().await {
        log::debug!("Received msg {msg:?}");
        // TODO
    }
}
