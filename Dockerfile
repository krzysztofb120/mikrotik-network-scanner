FROM alpine:3.19

RUN apk add --no-cache \
    nmap \
    nmap-scripts \
    nmap-doc \
    libxslt \
    && rm -rf /var/cache/apk/*

WORKDIR /root
ENTRYPOINT ["/bin/sh", "-c"]
