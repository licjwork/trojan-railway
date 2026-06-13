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
# 转义 sed 替换字符串中的特殊字符: \ & 以及换行符
escaped_password=$(printf '%s' "$PASSWORD" | sed -e 's/\\/\\\\/g' -e 's/&/\\&/g')
escaped_ws=$(printf '%s' "$WS_PATH" | sed -e 's/\\/\\\\/g' -e 's/&/\\&/g')

# 使用 # 作为分隔符，避免路径中的 / 需要转义
sed \
    -e "s#__PASSWORD__#${escaped_password}#g" \
    -e "s#__WS_PATH__#${escaped_ws}#g" \
    /etc/xray/config.template.json > /usr/local/etc/xray/config.json

echo "[xray] config generated at /usr/local/etc/xray/config.json"

# ── 生成 Nginx 配置 ────────────────────────────────────
# 使用 envsubst，仅替换 ${PORT} ${WS_PATH}，保留 nginx 原生变量
export PORT WS_PATH
envsubst '${PORT} ${WS_PATH}' \
    < /etc/nginx/nginx.template.conf \
    > /etc/nginx/http.d/default.conf

echo "[nginx] config generated at /etc/nginx/http.d/default.conf"

# ── 启动 Xray（后台） ──────────────────────────────────
/usr/local/xray/xray -config /usr/local/etc/xray/config.json &
XRAY_PID=$!
echo "[xray] started (pid=$XRAY_PID)"

# ── 启动 Nginx（前台，作为主进程） ────────────────────
echo "[nginx] starting in foreground..."
exec nginx -g "daemon off;"