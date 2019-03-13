FROM elixir:1.8.1-alpine as builder

ARG APP_NAME

ADD . /app

WORKDIR /app

ENV MIX_ENV=prod

RUN apk add git build-base && \
    git log --pretty=format:"%H %cd %s" > commits.txt && \
    APP_VSN=$(grep 'version:' apps/${APP_NAME}/mix.exs | cut -d '"' -f2) && \
    mix do \
    local.hex --force, \
    local.rebar --force, \
    deps.get, \
    deps.compile, \
    release --name=${APP_NAME} && \
    mv _build/prod/rel/${APP_NAME}/releases/${APP_VSN}/${APP_NAME}.tar.gz ${APP_NAME}.tar.gz 

FROM alpine:3.9

ARG APP_NAME

RUN apk add --no-cache \
  ncurses-libs \
  zlib \
  ca-certificates \
  openssl \
  bash

WORKDIR /app

ENV REPLACE_OS_VARS=true \
  APP=${APP_NAME}

COPY --from=builder /app/commits.txt /app
COPY --from=builder /app/${APP_NAME}.tar.gz /app

RUN tar -xzf ${APP_NAME}.tar.gz; rm ${APP_NAME}.tar.gz

CMD ./bin/${APP} foreground
