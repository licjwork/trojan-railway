FROM debian:stable-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    gettext-base \
    curl \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/local/xray && \
    curl -fsSLo /tmp/xray.zip \
        https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip && \
    unzip /tmp/xray.zip -d /usr/local/xray && \
    rm /tmp/xray.zip && \
    chmod +x /usr/local/xray/xray

RUN mkdir -p /run/nginx /usr/local/etc/xray /var/log/xray /var/log/nginx && \
    rm -f /etc/nginx/sites-enabled/default

COPY entrypoint.sh /entrypoint.sh
COPY config.template.json /etc/xray/config.template.json
COPY nginx.template.conf /etc/nginx/nginx.template.conf

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]