# 生产状态记录

更新时间：2026-04-30

## 入口

```text
https://openweb.aiclawonline.website
```

## 域名与 DNS

Cloudflare DNS：

```text
openweb.aiclawonline.website A 134.185.87.243
proxied: false
TTL: 120
```

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
Compose 文件：deploy/compose/docker-compose.prod.yml
镜像：ghcr.io/open-webui/open-webui:v0.9.2
宿主机端口：3000
容器端口：8080
数据卷：compose_open-webui-data
网络：compose_open-webui-net
```

## Hermes 接入

Open WebUI 通过 OpenAI-compatible 接口接入 Hermes API Server：

```text
OPENAI_API_BASE_URL=http://host.docker.internal:8642/v1
模型：hermes-agent
```

API Key 来自：

```text
/home/ubuntu/.hermes/.env: API_SERVER_KEY
```

该 key 已写入 `.env.prod`，不得提交到 Git。

## 健康检查

公网：

```bash
curl -sS https://openweb.aiclawonline.website/health
```

本机：

```bash
curl -sS http://127.0.0.1:3000/health
```

容器：

```bash
cd /home/ubuntu/openwebui-custom
docker compose --env-file deploy/env/.env.prod -f deploy/compose/docker-compose.prod.yml ps
```

## 运维命令

重启：

```bash
cd /home/ubuntu/openwebui-custom
docker compose --env-file deploy/env/.env.prod -f deploy/compose/docker-compose.prod.yml restart
```

日志：

```bash
docker logs -f open-webui
sudo tail -f /var/log/nginx/access.log /var/log/nginx/error.log
```

备份：

```bash
cd /home/ubuntu/openwebui-custom
bash deploy/scripts/backup.sh
```

## 风险点

1. `.env.prod` 含密钥，只能本机保存，不提交 Git。
2. Cloudflare 当前为 DNS only，暂不打开代理小云朵，避免影响 WebSocket/SSE。
3. 升级前必须先备份 Docker volume。
4. 魔改前必须从 `develop` 新建 `feature/*` 分支。
