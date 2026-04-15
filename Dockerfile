FROM node:24-alpine

RUN apk add --no-cache bash curl gzip tar unzip zip

RUN adduser -D -u 10001 builder

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN mkdir -p /build && chown builder:builder /build

USER builder

WORKDIR /build

ENTRYPOINT ["/entrypoint.sh"]
