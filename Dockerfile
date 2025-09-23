FROM rust:slim-bookworm

RUN apt-get update
RUN apt-get install -y curl xz-utils chromium git pkg-config libavutil-dev libavcodec-dev libavformat-dev libavfilter-dev libswscale-dev libswresample-dev libavdevice-dev clang libclang-dev llvm-dev

RUN cargo install cargo-make

# # download Flutter SDK
RUN curl -L https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.22.3-stable.tar.xz | tar xJ 
RUN mv flutter /usr/local/flutter

RUN git config --global --add safe.directory /usr/local/flutter

# # Set flutter environment path
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"
ENV CHROME_EXECUTABLE="/usr/bin/chromium"


# # Run flutter doctor
RUN flutter doctor

WORKDIR /usr/local/karaoke

COPY importer importer
COPY karaoke-server karaoke-server
COPY karaokeparty karaokeparty
COPY Cargo.toml .
COPY Makefile.toml .


RUN cargo make build-flutter
RUN cargo make build-server


COPY docker-run.sh .
RUN chmod +x docker-run.sh

COPY config.docker.yaml .
ENTRYPOINT ["./docker-run.sh"]
#ENTRYPOINT ["tail", "-f", "/dev/null"]


