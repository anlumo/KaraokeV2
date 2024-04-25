# Karaoke v2

A management solution for running large Karaoke parties using software compatible with the [Ultrastar Deluxe](https://usdx.eu/) [song format](https://usdx.eu/format/).

In these parties, people want to queue up for singing songs. They want to discover what's available and see when their song is going to come up. The traditional way is to have a huge paper list of all songs, and pieces of paper with a form on it to fill out and throw to the DJ. This works, but is cumbersome for everyone involved.

This implementation solves the problem by using technology.

* The DJ has a computer at their station where they can host a central management server in the local WiFi, and they can see the list of upcoming songs.
* The participants access the song database using their cellphone (or a shared station provided by the karaoke bar). They can search for songs, filter them, and then add  songs to the queue.
* The DJ can also rearrange the song queue in case there's some special needs (like someone needing to sing right away because they're about to leave).

The project consists of three programs:

* The [importer](importer/), which scans the song library for metadata information and stores it in a sqlite database (for performance reasons).
* The [karaoke-server](karaoke-server/), which has to run on the local network during the party.
* The [karaokeparty](karaokeparty/) app, which is the (web) frontend people (participants and the DJ) are supposed to use during the party.

## Dependencies

The importer and server need Rust installed, see [rustup.rs](https://rustup.rs). Also install cargo-make using:

```
cargo install cargo-make
```

Building the web client needs Flutter 3.16.9 (3.19.x doesn't work yet). Install as instructed on [flutter.dev](https://docs.flutter.dev/get-started/install).

Then, build the frontend and server using

```
cargo make build-flutter
cargo make build-server
```

Parse the Ultrastar library using

```
cargo run --bin importer -- --db songs.db -s <num> "<path>"
```

where `<path>` is the path to the song collection. The directory is scanned recursively, so the precise structure doesn't matter. Note that invalid entries are skipped.

The `-s <num>` indicates how many parts of the path have to be skipped (removed) to make the HTTP requests work. This probably needs a bit of experimentation.

## Configuration

Copy config.example.yaml to config.yaml and edit for your needs.

## Running the server

'''TODO: This needs to be updated to include concrete steps for setting up the file tree!'''

Running the server itself is easy:

```
karaoke-server -c config.yaml
```

The server can serve the frontend, the song database, and its own REST/WebSocket API at the same time. It's possible to have a reverse proxy in front of it, but it's not really necessary (unless TLS is desired).

## Contributions

Contributions are welcome, please fork and open a pull request! You have to agree to use the same license as this project.

## License

    Copyright (C) 2024 Andreas Monitzer

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

See [LICENSE.md](LICENSE.md) for the full license.
