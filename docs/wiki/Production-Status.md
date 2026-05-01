# Production Status

更新时间：2026-04-30

## 生产入口

```text
https://openweb.aiclawonline.website
```

## DNS

Cloudflare：

```text
openweb.aiclawonline.website A 134.185.87.243
proxied: false
TTL: 120
```

说明：

- 当前保持 DNS only。
- 暂不打开 Cloudflare 代理小云朵，避免影响 WebSocket、SSE、流式输出。

## 主机路径

```text
项目目录：/home/ubuntu/openwebui-custom
生产 env：/home/ubuntu/openwebui-custom/deploy/env/.env.prod
Nginx 配置：/etc/nginx/sites-available/open-webui
Nginx 启用：/etc/nginx/sites-enabled/open-webui
证书目录：/etc/letsencrypt/live/openweb.aiclawonline.website/
```

## Docker

```text
容器名：open-webui
Compose 文件：/home/ubuntu/openwebui-custom/deploy/compose/docker-compose.prod.yml
镜像：ghcr.io/open-webui/open-webui:v0.9.2
宿主机端口：3000
容器端口：8080
数据卷：compose_open-webui-data
网络：compose_open-webui-net
```

## Nginx

Open WebUI 反代：

```text
https://openweb.aiclawonline.website -> http://127.0.0.1:3000
```

关键配置：

```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_buffering off;
proxy_cache off;
proxy_read_timeout 3600s;
proxy_send_timeout 3600s;
client_max_body_size 100m;
```

## HTTPS

证书：

```text
/etc/letsencrypt/live/openweb.aiclawonline.website/fullchain.pem
/etc/letsencrypt/live/openweb.aiclawonline.website/privkey.pem
```

有效期：

```text
2026-07-29
```

Certbot 已配置自动续期。

## Hermes 接入

Open WebUI 使用 Hermes API Server 作为 OpenAI-compatible 后端：

```text
OPENAI_API_BASE_URL=http://host.docker.internal:8642/v1
OPENAI_API_KEY=<来自 /home/ubuntu/.hermes/.env 的 API_SERVER_KEY>
```

Open WebUI 中模型显示：

```text
hermes-agent
```

实际 Hermes 模型配置：

```text
Provider: custom
Model: gpt-5.5
Base URL: https://ai.dzzzz.cf/v1
```

## 当前健康状态

最后验证：

```text
open-webui container: healthy
https://openweb.aiclawonline.website/health -> {"status": true}
```
