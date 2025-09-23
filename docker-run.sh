#!/bin/bash

if [[ ! -f ./songsdb/songs.db ]]; then
  cargo run --bin importer -- --db ./songsdb/songs.db -s 5 ./songs/
fi

./target/release/karaoke-server -c config.docker.yaml
