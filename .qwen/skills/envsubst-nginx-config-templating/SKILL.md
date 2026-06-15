---
name: envsubst-nginx-config-templating
description: 用 envsubst 为 nginx 配置做模板替换时，必须用 SHELL-FORMAT 限制变量范围，否则 nginx 原生变量会被清空；同时 sed 模板方案有分隔符冲突陷阱
source: auto-skill
extracted_at: '2026-06-13T13:56:27.316Z'
---

# 容器配置模板：envsubst 优于 sed，但 nginx 需要特殊处理

## 规则

Docker 容器入口脚本中生成配置文件时，**优先使用 `envsubst` 而非 `sed`** 做变量替换。但 nginx 配置由于其原生变量（`$host`、`$http_upgrade` 等）与 shell 变量语法相似，**必须使用 SHELL-FORMAT 参数限制替换范围**。

## Why

### sed 的陷阱

sed 的 `s` 命令使用分隔符（如 `/`、`#`），当替换内容（如密码、路径）恰好包含分隔符时，会报 `unknown option to 's'`。虽然可以换分隔符，但无法预知用户输入的所有字符。反斜杠和 `&` 的转义也极易出错。**sed 不适合用于用户提供的任意字符串替换。**

### envsubst 的优势

`envsubst` 直接做文本替换，不依赖分隔符，不存在内容冲突。它的 SHELL-FORMAT 参数可以精确控制要替换哪些变量。

### nginx 兼容性

nginx 配置中大量使用 `$var` 语法（`$host`、`$http_upgrade`、`$remote_addr`、`$proxy_add_x_forwarded_for`）。如果对 nginx 模板直接使用 `envsubst < template > output`（不限制变量），这些 nginx 变量会被替换为空字符串，导致配置失效。

## How to apply

### 普通配置模板（如 JSON/YAML）

直接使用，无需限制：

```bash
envsubst < /etc/app/config.template.json > /etc/app/config.json
```

### nginx 配置模板

**必须**用 SHELL-FORMAT 限制只替换自己的变量：

```bash
# ❌ 错误 —— 会清空 $host、$http_upgrade 等 nginx 变量
envsubst < nginx.template.conf > /etc/nginx/conf.d/default.conf

# ✅ 正确 —— 仅替换 ${PORT} 和 ${WS_PATH}
envsubst '${PORT} ${WS_PATH}' < nginx.template.conf > /etc/nginx/conf.d/default.conf
```

### nginx 模板写法

模板中使用 `${VAR}` 双引号风格，与 nginx 的 `$var` 风格区分：

```nginx
server {
    listen 0.0.0.0:${PORT};        # ← 会被 envsubst 替换
    server_name _;

    location ${WS_PATH} {           # ← 会被 envsubst 替换
        proxy_pass http://127.0.0.1:10000;
        proxy_set_header Host $host;  # ← 不会被替换（不在 SHELL-FORMAT 中）
    }
}
```

### 完整入口脚本模式

```bash
#!/bin/sh
set -e

export PORT PASSWORD WS_PATH DOMAIN

# Xray/JSON 配置 —— 模板无冲突变量，直接 envsubst
envsubst < /etc/xray/config.template.json > /etc/xray/config.json

# Nginx 配置 —— 必须限制变量范围
envsubst '${PORT} ${WS_PATH}' \
    < /etc/nginx/nginx.template.conf \
    > /etc/nginx/conf.d/default.conf

# 验证生成的配置
nginx -t
xray run -test -config /etc/xray/config.json
```