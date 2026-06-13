# Trojan Railway

> 一键部署 Trojan over WebSocket 到 [Railway](https://railway.app)，配合 [Cloudflare CDN](https://cloudflare.com) 使用。

## 架构

```
客户端 ──TLS──▶ Cloudflare CDN ──HTTPS──▶ Railway Edge ──▶ 容器 (PORT)
                                                           │
                                                    ┌──────┴──────┐
                                                    │    nginx     │
                                                    │  GET / → OK  │
                                                    │  /ws → xray  │
                                                    └──────┬──────┘
                                                           │
                                                    ┌──────┴──────┐
                                                    │    xray      │
                                                    │  trojan+ws   │
                                                    └─────────────┘
```

- **TLS** 由 Cloudflare 和 Railway 边缘网络提供，容器内部无需管理证书。
- **Nginx** 负责健康检查 (`GET /`) 和 WebSocket 代理。
- **Xray-core** 运行 Trojan 协议，监听内部端口 `127.0.0.1:10000`。

## 部署

### 1. Fork 本项目

点击右上角 **Fork**，将项目复制到你的 GitHub 账号下。

### 2. Railway 部署

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/template?referralCode=)

或手动操作：

1. 进入 [Railway Dashboard](https://railway.app/dashboard)
2. 点击 **New Project → Deploy from GitHub repo**
3. 选择你 Fork 的仓库
4. Railway 会自动构建并部署

### 3. 配置环境变量

在 Railway 项目的 **Variables** 标签页中添加：

| 变量 | 说明 | 示例 |
|------|------|------|
| `PASSWORD` | Trojan 连接密码（必填） | `your-strong-password` |
| `WS_PATH` | WebSocket 路径 | `/ws` |
| `DOMAIN` | 你的自定义域名 | `railway.lili.qzz.io` |
| `PORT` | Railway 自动分配，无需手动设置 | — |

> **注意**：`PORT` 由 Railway 自动注入，不要手动设置。

### 4. 添加自定义域名

1. 在 Railway 项目 → **Settings → Custom Domains**
2. 添加你的域名，例如 `railway.lili.qzz.io`
3. Railway 会提供一个 CNAME 目标地址

### 5. Cloudflare DNS 配置

在你的 Cloudflare 控制面板中：

1. 添加 CNAME 记录：
   - **名称**：`railway.lili`（根据你的子域名）
   - **目标**：Railway 提供的 CNAME 目标
   - **代理状态**：✅ 已代理（橙色云朵）

2. SSL/TLS 设置：
   - 加密模式：**Full** 或 **Full (strict)**

### 6. 验证部署

浏览器访问你的域名：`https://railway.lili.qzz.io/`

应该看到：**OK**

## 客户端配置

### Trojan 客户端 (兼容 Xray-core / v2rayN / Shadowrocket 等)

| 参数 | 值 |
|------|-----|
| 协议 | Trojan |
| 服务器地址 | `railway.lili.qzz.io`（你的域名） |
| 端口 | `443` |
| 密码 | 你在 Railway 设置的 `PASSWORD` |
| 传输协议 | WebSocket (ws) |
| WebSocket Path | 你在 Railway 设置的 `WS_PATH`（如 `/ws`） |
| SNI | `railway.lili.qzz.io`（你的域名） |
| TLS | 开启 |
| AllowInsecure | 关闭 |

### 通用客户端 JSON 配置示例

```json
{
  "outbounds": [
    {
      "protocol": "trojan",
      "settings": {
        "servers": [
          {
            "address": "railway.lili.qzz.io",
            "port": 443,
            "password": "your-strong-password"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "serverName": "railway.lili.qzz.io"
        },
        "wsSettings": {
          "path": "/ws"
        }
      }
    }
  ]
}
```

## 文件说明

```
.
├── Dockerfile            # 容器构建文件
├── railway.json          # Railway 部署配置
├── entrypoint.sh         # 容器入口脚本
├── config.template.json  # Xray 配置模板
├── nginx.template.conf   # Nginx 配置模板
└── README.md             # 本文件
```

## 常见问题

**Q: 为什么不用 TLS 直连？**

Railway 的边缘网络已经提供 HTTPS 终止，配合 Cloudflare CDN，容器内运行 TLS 反而会造成双重加密和证书管理问题。本项目将 TLS 交给基础设施处理，容器内只跑纯 WebSocket，更轻量也更稳定。

**Q: 冷启动慢怎么办？**

Railway 的免费套餐可能存在冷启动延迟。本项目镜像基于 Alpine，体积约 30MB，启动时间在 5 秒以内。

**Q: 能否使用其他 CDN？**

可以。只要 CDN 支持 WebSocket 代理且提供 HTTPS，将域名 CNAME 指向 Railway 即可。

## 许可

MIT