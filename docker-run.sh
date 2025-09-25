#!/bin/bash

if [[ ! -f ./songsdb/songs.db ]]; then
  ./importer --db ./songsdb/songs.db -s 5 ./songs/
fi

./karaoke-server -c config.docker.yaml
