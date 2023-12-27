use std::{net::SocketAddr, sync::Arc};

use axum::{
    extract::{
        ws::{Message, WebSocket},
        ConnectInfo, State, WebSocketUpgrade,
    },
    response::IntoResponse,
};
use futures_util::{select, FutureExt, SinkExt, StreamExt};
use serde::{Deserialize, Serialize};
use tokio::sync::mpsc::unbounded_channel;
use uuid::Uuid;

use crate::AppState;

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "camelCase", tag = "cmd")]
enum Command {
    Authenticate { password: String },
    Add { song: i64, singer: String },
    Play { id: Uuid },
    Remove { id: Uuid },
    Swap { id1: Uuid, id2: Uuid },
    MoveAfter { id: Uuid, after: Uuid },
    MoveTop { id: Uuid },
}

pub async fn ws_handler(
    ws: WebSocketUpgrade,
    State(state): State<Arc<AppState>>,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
) -> impl IntoResponse {
    log::info!("[{addr:?}] Websocket connected.");
    ws.on_upgrade(move |socket| handle_socket(socket, addr, state))
}

async fn handle_socket(socket: WebSocket, who: SocketAddr, state: Arc<AppState>) {
    let (mut sender, mut receiver) = socket.split();

    let (listen_sender, mut listen_receiver) = unbounded_channel();
    match state.playlist.subscribe(listen_sender).await {
        Err(err) => log::error!("[{who:?}] {err:?}"),
        Ok(subscription) => {
            let mut authenticated = false;
            loop {
                select! {
                    json = listen_receiver.recv().fuse() => if let Some(json) = json {
                        if let Err(err) = sender.send(Message::Text(json)).await {
                            log::error!("[{who:?}] Send failed: {err:?}");
                            break;
                        }
                    } else {
                        break;
                    },
                    msg = receiver.next().fuse() => match msg {
                        Some(Ok(Message::Text(text))) => {
                            log::debug!("[{who:?}] Received text {text:?}");
                            match serde_json::from_str::<'_, Command>(&text) {
                                Err(err) => {
                                    log::error!("[{who:?}] Failed parsing command: {err:?}");
                                    break;
                                }
                                Ok(cmd) => {
                                    let result = match cmd {
                                        Command::Authenticate { password } => {
                                            if authenticated {
                                                // logout
                                                authenticated = false
                                            } else if password == state.password {
                                                authenticated = true;
                                            }
                                            sender.send(Message::Binary(vec![authenticated as u8])).await.map_err(anyhow::Error::from)
                                        }
                                        Command::Add { song, singer } => {
                                            state.playlist.add(song, singer).await.map(|_| ())
                                        }
                                        Command::Play { id } if authenticated => {
                                            state.playlist.play(id, &state.index).await.map(|_| ())
                                        }
                                        Command::Remove { id } if authenticated => {
                                            state.playlist.remove(id).await.map(|_| ())
                                        }
                                        Command::Swap { id1, id2 } if authenticated => {
                                            state.playlist.swap(id1, id2).await.map(|_| ())
                                        }
                                        Command::MoveAfter { id, after } if authenticated => {
                                            state.playlist.move_after(id, after).await.map(|_| ())
                                        }
                                        Command::MoveTop { id } if authenticated => {
                                            state.playlist.move_top(id).await.map(|_| ())
                                        }
                                        _ => sender.send(Message::Text("Unauthenticated".to_owned())).await.map_err(anyhow::Error::from),
                                    };
                                    if let Err(err) = result {
                                        log::error!("[{who:?}]: {err:?}");
                                        break;
                                    }
                                }
                            }
                        }
                        Some(Ok(Message::Binary(_bin))) => {}
                        Some(Ok(Message::Ping(data))) => sender.send(Message::Pong(data)).await.unwrap(),
                        Some(Ok(Message::Pong(_))) => {}
                        Some(Ok(Message::Close(reason))) => {
                            if let Some(reason) = reason {
                                log::info!("[{who:?}] Connection closed: {reason:?}");
                            } else {
                                log::info!("[{who:?}] Connection closed.");
                            }
                            // Don't close our stream here!
                            state.playlist.unsubscribe(subscription).await;
                            return;
                        },
                        Some(Err(err)) => {
                            log::error!("[{who:?}]: {err:?}");
                            break;
                        }
                        None => break,
                    }
                }
            }
            state.playlist.unsubscribe(subscription).await;
        }
    }

    match sender.reunite(receiver) {
        Ok(socket) => {
            if let Err(err) = socket.close().await {
                log::error!("[{who:?}] Close failed: {err:?}");
            }
        }
        Err(err) => log::error!("[{who:?}] Reunite failed: {err:?}"),
    }
    log::debug!("[{who:?}] Websocket disconnected.");
}
