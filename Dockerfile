FROM rust:slim-bookworm AS builder

RUN apt-get update && \
  apt-get install -y curl xz-utils chromium pkg-config libavutil-dev libavformat-dev libavdevice-dev git clang && \
  curl -L https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.22.3-stable.tar.xz | tar xJ && \
  mv flutter /usr/local/flutter && \
  git config --global --add safe.directory /usr/local/flutter

# # Set flutter environment path
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"
ENV CHROME_EXECUTABLE="/usr/bin/chromium"


WORKDIR /usr/local/karaoke

COPY importer importer
COPY karaoke-server karaoke-server
COPY karaokeparty karaokeparty
COPY Cargo.toml .
COPY Makefile.toml .


RUN cd karaokeparty && \
  dart run slang && \
  flutter build web --release --wasm && \
  cd .. && \
  cargo build --bin importer --release && \
  cargo build --bin karaoke-server --release


FROM rust:slim-bookworm

RUN apt-get update && apt-get install -y libavutil57 libavformat59 libavdevice59 

WORKDIR /usr/local/karaoke
COPY --from=builder /usr/local/karaoke/target/release/karaoke-server karaoke-server
COPY --from=builder /usr/local/karaoke/target/release/importer importer
COPY --from=builder /usr/local/karaoke/karaokeparty/build/web karaokeparty/build/web
COPY docker-run.sh .
RUN chmod +x docker-run.sh

COPY config.docker.yaml .
ENTRYPOINT ["./docker-run.sh"]


