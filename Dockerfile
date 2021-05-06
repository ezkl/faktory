FROM golang:alpine AS builder
WORKDIR /build

COPY go.mod .
COPY go.sum .

RUN go mod download &&\
    go get github.com/benbjohnson/ego/...

ENV UPXV=3.96
ENV UPXU=https://github.com/upx/upx/releases/download/v${UPXV}

RUN case `arch` in\
        x86_64)\
            uarch="amd64" \
            ;;\
        aarch64)\
            uarch="arm64" \
            ;;\
        *)\
            echo "unknown architecture" && exit 1\
            ;;\
    esac &&\
    wget -qO- "${UPXU}/upx-${UPXV}-${uarch}_linux.tar.xz" | xzcat - | tar xvf - -C /tmp/ &&\
    mv /tmp/upx-*/upx /usr/bin/upx

COPY . .

RUN go generate github.com/contribsys/faktory/webui &&\
    go build -o ./faktory cmd/faktory/daemon.go &&\
    upx -qq /build/faktory

FROM alpine:3.13
RUN apk add --no-cache redis ca-certificates socat
COPY --from=builder /build/faktory /faktory

RUN mkdir -p /root/.faktory/db &&\
    mkdir -p /var/lib/faktory/db &&\
    mkdir -p /etc/faktory

EXPOSE 7419 7420
CMD ["/faktory", "-w", "0.0.0.0:7420", "-b", "0.0.0.0:7419"]
