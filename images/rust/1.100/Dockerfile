# syntax=docker/dockerfile:1

FROM rust:1.100.0-alpine3.24 AS builder

LABEL org.opencontainers.image.url="https://github.com/gustavofreze/docker-images" \
      org.opencontainers.image.title="gustavofreze/rust-builder" \
      org.opencontainers.image.source="https://github.com/gustavofreze/docker-images" \
      org.opencontainers.image.vendor="gustavofreze" \
      org.opencontainers.image.authors="Gustavo Freze" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.description="Rust 1.100 Cargo and musl toolchain for application builder stages" \
      org.opencontainers.image.documentation="https://github.com/gustavofreze/docker-images/blob/main/images/rust/README.md"

RUN apk add --no-cache --upgrade zlib \
    && addgroup -g 1000 app \
    && adduser -u 1000 -G app -D -h /app app

WORKDIR /app

USER 1000

FROM builder AS cli

LABEL org.opencontainers.image.title="gustavofreze/rust-cli" \
      org.opencontainers.image.description="Rust 1.100 CLI tooling image: Cargo, Clippy, rustfmt, git, bash, curl"

# hadolint ignore=DL3002
USER 0

RUN apk add --no-cache bash curl git \
    && git config --system --add safe.directory /app

RUN rustup component add clippy rustfmt \
    && rm -rf "${RUSTUP_HOME}/downloads" "${RUSTUP_HOME}/tmp"

FROM alpine:3.24.4 AS rootfs

RUN apk add --no-cache --upgrade zlib \
    && addgroup -g 1000 app \
    && adduser -u 1000 -G app -D -h /app app

FROM scratch AS runtime

LABEL org.opencontainers.image.url="https://github.com/gustavofreze/docker-images" \
      org.opencontainers.image.title="gustavofreze/rust" \
      org.opencontainers.image.source="https://github.com/gustavofreze/docker-images" \
      org.opencontainers.image.vendor="gustavofreze" \
      org.opencontainers.image.authors="Gustavo Freze" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.description="Hardened non-root production runtime for statically linked Rust binaries" \
      org.opencontainers.image.documentation="https://github.com/gustavofreze/docker-images/blob/main/images/rust/README.md"

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    RUST_BACKTRACE=1

# hadolint ignore=DL3067
COPY --from=rootfs / /

WORKDIR /app

USER 1000

CMD ["/bin/sh"]

FROM runtime AS development

LABEL org.opencontainers.image.title="gustavofreze/rust-development" \
      org.opencontainers.image.description="Rust 1.100 development runtime: runtime plus Cargo, Clippy, rustfmt, bash, and git"

ENV PATH="/usr/local/cargo/bin:${PATH}" \
    CARGO_HOME=/usr/local/cargo \
    RUSTUP_HOME=/usr/local/rustup

USER 0

RUN apk add --no-cache bash gcc git musl-dev \
    && git config --system --add safe.directory /app

COPY --from=cli /usr/local/rustup /usr/local/rustup
COPY --from=cli /usr/local/cargo /usr/local/cargo

USER 1000
