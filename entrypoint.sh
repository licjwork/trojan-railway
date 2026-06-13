#!/bin/sh
set -e

# ── 默认值 ──────────────────────────────────────────────
PORT="${PORT:-8080}"
PASSWORD="${PASSWORD:-}"
WS_PATH="${WS_PATH:-/ws}"
DOMAIN="${DOMAIN:-}"

# 确保 WS_PATH 以 / 开头
case "$WS_PATH" in
    /*) ;;
    *)  WS_PATH="/$WS_PATH" ;;
esac

# ── 校验必要环境变量 ──────────────────────────────────
if [ -z "$PASSWORD" ]; then
    echo "ERROR: PASSWORD environment variable is required"
    exit 1
fi

echo "============================================"
echo "  Trojan Railway — Starting up"
echo "============================================"
echo "  PORT:      $PORT"
echo "  WS_PATH:   $WS_PATH"
echo "  DOMAIN:    $DOMAIN"
echo "  PASSWORD:  ****"
echo "============================================"

# ── sed 转义函数 ───────────────────────────────────────
# 转义: \ & （使用 # 作分隔符，无需转义 /）
escape_sed() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/&/\\&/g'
}

ESC_PASSWORD=$(escape_sed "$PASSWORD")
ESC_WS_PATH=$(escape_sed "$WS_PATH")
ESC_PORT=$(escape_sed "$PORT")

# ── 生成 Xray 配置 ────────────────────────────────────
echo "[xray] generating config..."
sed \
    -e "s#__PASSWORD__#${ESC_PASSWORD}#g" \
    -e "s#__WS_PATH__#${ESC_WS_PATH}#g" \
    /etc/xray/config.template.json > /usr/local/etc/xray/config.json
echo "[xray] config written to /usr/local/etc/xray/config.json"

# ── 生成 Nginx 配置 ────────────────────────────────────
echo "[nginx] generating config..."
sed \
    -e "s#__PORT__#${ESC_PORT}#g" \
    -e "s#__WS_PATH__#${ESC_WS_PATH}#g" \
    /etc/nginx/nginx.template.conf > /etc/nginx/conf.d/default.conf
echo "[nginx] config written to /etc/nginx/conf.d/default.conf"

# ── 验证 Nginx 配置语法 ────────────────────────────────
echo "[nginx] testing config..."
if ! nginx -t 2>&1; then
    echo "ERROR: nginx config is invalid"
    cat /etc/nginx/conf.d/default.conf
    exit 1
fi
echo "[nginx] config OK"

# ── 启动 Xray ──────────────────────────────────────────
export XRAY_LOCATION_ASSET=/usr/local/xray
echo "[xray] Starting Xray..."
/usr/local/xray/xray -config /usr/local/etc/xray/config.json > /var/log/xray/stdout.log 2>&1 &
XRAY_PID=$!

# 等待 Xray 进程就绪
for i in 1 2 3 4 5 6 7 8 9 10; do
    if kill -0 "$XRAY_PID" 2>/dev/null; then
        echo "[xray] Xray started (pid=$XRAY_PID)"
        break
    fi
    sleep 0.5
done

if ! kill -0 "$XRAY_PID" 2>/dev/null; then
    echo "ERROR: Xray failed to start"
    echo "--- Xray log ---"
    cat /var/log/xray/stdout.log
    exit 1
fi

# ── 启动 Nginx（前台） ─────────────────────────────────
echo "[nginx] Starting Nginx on 0.0.0.0:$PORT..."
echo "[nginx] Health check: GET / → 200 OK"
echo "[nginx] WebSocket:   $WS_PATH → proxy to 127.0.0.1:10000"
echo "============================================"
echo "  All services started. Ready."
echo "============================================"

exec nginx -g "daemon off;"