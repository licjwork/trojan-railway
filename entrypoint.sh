#!/bin/sh
set -e

# ── 默认值 ──────────────────────────────────────────────
PORT="${PORT:-8080}"
PASSWORD="${PASSWORD:-}"
WS_PATH="${WS_PATH:-/ws}"
DOMAIN="${DOMAIN:-}"

# ── 校验必要环境变量 ──────────────────────────────────
if [ -z "$PASSWORD" ]; then
    echo "ERROR: PASSWORD environment variable is required"
    exit 1
fi

echo "============================================"
echo "Trojan Railway - Starting up"
echo "============================================"
echo "PORT:     $PORT"
echo "WS_PATH:  $WS_PATH"
echo "DOMAIN:   $DOMAIN"
echo "PASSWORD: ****"
echo "============================================"

# ── 生成 Xray 配置 ────────────────────────────────────
escaped_password=$(printf '%s' "$PASSWORD" | sed -e 's/\\/\\\\/g' -e 's/&/\\&/g')
escaped_ws=$(printf '%s' "$WS_PATH" | sed -e 's/\\/\\\\/g' -e 's/&/\\&/g')

sed \
    -e "s#__PASSWORD__#${escaped_password}#g" \
    -e "s#__WS_PATH__#${escaped_ws}#g" \
    /etc/xray/config.template.json > /usr/local/etc/xray/config.json

echo "[xray] config written"

# ── 生成 Nginx 配置 ────────────────────────────────────
export PORT WS_PATH
envsubst '${PORT} ${WS_PATH}' \
    < /etc/nginx/nginx.template.conf \
    > /etc/nginx/conf.d/default.conf

echo "[nginx] config written"

# ── 测试 nginx 配置语法 ────────────────────────────────
nginx -t

# ── 启动 Xray（后台） ──────────────────────────────────
export XRAY_LOCATION_ASSET=/usr/local/xray
echo "[xray] starting..."
/usr/local/xray/xray -config /usr/local/etc/xray/config.json &
XRAY_PID=$!

# 等待 Xray 就绪（最多 5 秒）
for i in $(seq 1 10); do
    if kill -0 "$XRAY_PID" 2>/dev/null; then
        echo "[xray] started (pid=$XRAY_PID)"
        break
    fi
    sleep 0.5
done

if ! kill -0 "$XRAY_PID" 2>/dev/null; then
    echo "ERROR: xray failed to start"
    exit 1
fi

# ── 启动 Nginx（前台，作为主进程） ────────────────────
echo "[nginx] starting in foreground..."
exec nginx -g "daemon off;"