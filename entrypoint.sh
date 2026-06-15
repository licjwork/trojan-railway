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

# ── URL 编码函数（用于 trojan:// 导入链接） ────────────
urlencode() {
    printf '%s' "$1" | awk '
    BEGIN {
        for (n = 0; n < 256; n++) {
            c = sprintf("%c", n)
            if (c ~ /[A-Za-z0-9_.~-]/)
                map[c] = c
            else
                map[c] = sprintf("%%%02X", n)
        }
    }
    {
        out = ""
        for (i = 1; i <= length($0); i++) {
            c = substr($0, i, 1)
            out = out map[c]
        }
        print out
    }'
}

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

# ── 导出环境变量供 envsubst 使用 ──────────────────────
export PORT PASSWORD WS_PATH DOMAIN

# ── 生成 Xray 配置 ────────────────────────────────────
echo "[xray] generating config..."
envsubst < /etc/xray/config.template.json > /etc/xray/config.json
echo "Config generated successfully."

# ── 生成 Nginx 配置 ────────────────────────────────────
# 仅替换 PORT / WS_PATH，保留 nginx 原生变量（$host, $http_upgrade 等）
echo "[nginx] generating config..."
envsubst '${PORT} ${WS_PATH}' \
    < /etc/nginx/nginx.template.conf \
    > /etc/nginx/conf.d/default.conf
echo "Config generated successfully."

# ── 验证 Xray 配置合法性 ───────────────────────────────
echo "[xray] testing config..."
if ! /usr/local/xray/xray run -test -config /etc/xray/config.json 2>&1; then
    echo "ERROR: xray config is invalid"
    cat /etc/xray/config.json
    exit 1
fi
echo "[xray] config OK"

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
/usr/local/xray/xray run -config /etc/xray/config.json > /var/log/xray/stdout.log 2>&1 &
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

# ── 组装公网域名（优先自定义 DOMAIN，否则 Railway 自动分配） ──
PUBLIC_DOMAIN="${DOMAIN:-${RAILWAY_PUBLIC_DOMAIN:-}}"
if [ -z "$PUBLIC_DOMAIN" ]; then
    PUBLIC_DOMAIN="<your-domain>"
fi

# ── URL 编码密码和路径（用于 trojan:// 导入链接） ──────
ENC_PASSWORD=$(urlencode "$PASSWORD")
ENC_WS_PATH=$(urlencode "$WS_PATH")

# ── 启动 Nginx（前台） ─────────────────────────────────
echo "[nginx] Starting Nginx on 0.0.0.0:$PORT..."
echo ""
echo "============================================"
echo "  Trojan Railway — Ready"
echo "============================================"
echo "  Health:   https://${PUBLIC_DOMAIN}/"
echo "  Trojan:   trojan://${ENC_PASSWORD}@${PUBLIC_DOMAIN}:443?security=tls&type=ws&path=${ENC_WS_PATH}&sni=${PUBLIC_DOMAIN}#Trojan-Railway"
echo ""
echo "  ── Client config ──"
echo "  Server:        ${PUBLIC_DOMAIN}"
echo "  Port:          443"
echo "  Password:      ${PASSWORD}"
echo "  Network:       ws"
echo "  WS Path:       ${WS_PATH}"
echo "  TLS:           on"
echo "  SNI:           ${PUBLIC_DOMAIN}"
echo ""
echo "  ── Import ──"
echo "  trojan://${ENC_PASSWORD}@${PUBLIC_DOMAIN}:443?security=tls&type=ws&path=${ENC_WS_PATH}&sni=${PUBLIC_DOMAIN}#Trojan-Railway"
echo "============================================"

exec nginx -g "daemon off;"