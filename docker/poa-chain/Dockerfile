FROM golang:1.26-alpine AS builder

RUN apk add --no-cache gcc musl-dev linux-headers git

WORKDIR /go-ethereum
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN go run build/ci.go install -static ./cmd/geth ./cmd/devp2p ./cmd/ethkey

FROM alpine:latest

RUN apk add --no-cache bash ca-certificates curl jq
COPY --from=builder /go-ethereum/build/bin/geth /usr/local/bin/geth
COPY --from=builder /go-ethereum/build/bin/devp2p /usr/local/bin/devp2p
COPY --from=builder /go-ethereum/build/bin/ethkey /usr/local/bin/ethkey

WORKDIR /workspace
