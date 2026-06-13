FROM alpine:3.21

ARG XRAY_VERSION=1.8.23

RUN apk add --no-cache \
    nginx \
    gettext \
    curl \
    unzip \
    && rm -rf /var/cache/apk/*

RUN mkdir -p /usr/local/xray && \
    curl -sSL https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip -o /tmp/xray.zip && \
    unzip /tmp/xray.zip -d /usr/local/xray && \
    rm /tmp/xray.zip && \
    chmod +x /usr/local/xray/xray

RUN mkdir -p /run/nginx /usr/local/etc/xray /var/log/xray

COPY entrypoint.sh /entrypoint.sh
COPY config.template.json /etc/xray/config.template.json
COPY nginx.template.conf /etc/nginx/nginx.template.conf

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]