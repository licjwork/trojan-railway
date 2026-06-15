---
name: railway-docker-glibc
description: 在 Railway 容器部署中使用官方 GitHub Release 的 Go 二进制时，必须用 Debian 而非 Alpine 基础镜像
source: auto-skill
extracted_at: '2026-06-13T13:30:02.654Z'
---

# Railway Docker 部署：Go 二进制需 glibc

## 规则

当 Docker 容器中需要使用从 GitHub Release 下载的官方 Go 二进制文件（如 Xray-core、Caddy、frp 等）时，**必须使用 Debian 基础镜像**（如 `debian:stable-slim`），**禁止使用 Alpine**。

## Why

Go 官方 Release 二进制默认链接 glibc。Alpine 使用 musl libc，两者 ABI 不兼容，导致二进制**静默崩溃**——容器看似正常启动，但进程瞬间退出，Railway 健康检查持续报 `service unavailable`，部署日志中无明确错误信息。

## How to apply

1. 将 `FROM alpine:3.x` 替换为 `FROM debian:stable-slim`
2. 包管理器从 `apk add` 改为 `apt-get install`
3. **Nginx 配置路径差异**：
   - Alpine: `/etc/nginx/http.d/default.conf`
   - Debian: `/etc/nginx/conf.d/default.conf`
4. Debian nginx 需要清理默认站点：`rm -f /etc/nginx/sites-enabled/default`
5. `gettext`（Alpine）→ `gettext-base`（Debian），两者都提供 `envsubst`
6. **ENTRYPOINT 显式指定 shell**：使用 `ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]`，避免 `ENTRYPOINT ["/entrypoint.sh"]` 潜在的 shebang 或执行权限问题
7. **Xray 启动前验证配置**：先执行 `xray run -test -config /path/to/config.json`，失败时打印配置内容便于排查

## 示例 Dockerfile 片段

```dockerfile
FROM debian:stable-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx gettext-base curl unzip ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 下载 Go 二进制（glibc 兼容）
RUN curl -fsSLo /tmp/binary.zip \
    https://github.com/example/releases/latest/download/binary-linux-64.zip \
    && unzip /tmp/binary.zip -d /usr/local/bin \
    && rm /tmp/binary.zip

RUN rm -f /etc/nginx/sites-enabled/default
```