use std::{
    net::{SocketAddr, ToSocketAddrs},
    path::{Path, PathBuf},
};

use serde::{Deserialize, Deserializer};
use tokio::fs::read;

#[derive(Deserialize, Debug)]
pub struct Paths {
    /// The path to the sqlite database with the song information.
    pub database: PathBuf,
    /// Path to the directory structure for the covers.
    pub media: PathBuf,
    /// Path to the web app (directory containing index.html).
    pub web_app: PathBuf,
    /// The path to the persisted playlist file. Will be created if it doesn't exist.
    pub playlist: PathBuf,
    /// Path to the file that should contain the history of what was played.
    pub song_log: Option<PathBuf>,
    /// Path to the file that should contain the song suggestions that were made.
    pub suggestion_log: PathBuf,
    /// Path to the file that should contain the song bug reports that were made.
    pub bug_log: PathBuf,
}

#[derive(Deserialize, Debug)]
pub struct Server {
    /// The address and port to listen on.
    #[serde(deserialize_with = "flatten_resolve_addr")]
    pub listen: Option<SocketAddr>,
    /// The admin password for managing the playlist.
    pub password: String,
}

#[derive(Deserialize, Debug)]
pub struct Config {
    pub paths: Paths,
    pub server: Server,
    pub logging: log4rs::config::RawConfig,
}

pub async fn parse_config(path: impl AsRef<Path>) -> anyhow::Result<Config> {
    Ok(serde_yaml::from_slice(&read(path).await?)?)
}

fn flatten_resolve_addr<'de, D>(de: D) -> Result<Option<SocketAddr>, D::Error>
where
    D: Deserializer<'de>,
{
    // Being a little lazy here about allocations and error handling.
    // Because again, you shouldn't do this.
    let unresolved = String::deserialize(de)?;
    Ok(unresolved
        .to_socket_addrs()
        .map_err(serde::de::Error::custom)?
        .next())
}
