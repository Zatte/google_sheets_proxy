FROM golang:1.14.4-alpine3.12 as BuildEnv

ENV CGO_ENABLED 0
ENV GOOS linux
ENV PROTOC_VERSION_TAG v1.3.1
ENV PATH $PATH:/root/google-cloud-sdk/bin:/root/
ENV GOPATH /go
ENV TERM xterm-256color

# Install dependencies that change infrequently:
RUN set -x \
    && apk add --no-cache --update git python3 python3-dev openssl-dev \
    bash libffi-dev py-pip docker gcc musl-dev openssh curl libc6-compat protobuf \
    protobuf-dev make bash which \
    && rm -f /var/cache/apk/* \
    && curl -sfL https://install.goreleaser.com/github.com/golangci/golangci-lint.sh | sh -s ${LINTVER}

RUN pip install docker-compose

WORKDIR /app
ADD Makefile /app/Makefile
RUN make dev-deps

# Build ------------------------------------------------------------------------------------------
FROM BuildEnv AS builder

ARG VERSION=snapshot

WORKDIR /app
ADD . /app

RUN make build

# ------------ RUN -----------
FROM alpine:3.8
ENTRYPOINT ["/app/go-app"]
WORKDIR /app
RUN apk --update --no-cache add ca-certificates && update-ca-certificates && rm -f /var/cache/apk/*
COPY --from=builder /app/dist/go-app /app/go-app
