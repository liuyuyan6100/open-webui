# 部署说明

## 目录

```text
deploy/compose/   Docker Compose 文件
deploy/env/       环境变量模板
deploy/nginx/     反向代理配置
deploy/scripts/   构建、启动、健康检查脚本
```

## 当前生产 Compose

生产模板：

```text
deploy/compose/docker-compose.prod.yml
```

关键兼容点：

- 服务名：`open-webui`
- 容器名：`open-webui`
- 容器内端口：`8080`
- 宿主机端口：`${OPEN_WEBUI_PORT:-3000}`
- 数据目录：`/app/backend/data`
- 默认镜像：`ghcr.io/open-webui/open-webui:main`

生产建议将 `APP_IMAGE` 固定为明确版本 tag，不建议长期使用 `main`。

## 环境变量

从模板复制：

```bash
cp deploy/env/.env.example deploy/env/.env.prod
chmod 600 deploy/env/.env.prod
```

然后修改：

```text
APP_IMAGE
OPEN_WEBUI_PORT
WEBUI_NAME
WEBUI_SECRET_KEY
OLLAMA_BASE_URL
OPENAI_API_BASE_URL
OPENAI_API_KEY
```

生产环境不要把真实密钥提交到 Git。

## 启动生产服务

```bash
bash deploy/scripts/up-prod.sh
```

## 健康检查

本地检查：

```bash
bash deploy/scripts/healthcheck.sh http://127.0.0.1:3000
```

容器状态：

```bash
docker compose --env-file deploy/env/.env.prod -f deploy/compose/docker-compose.prod.yml ps
```

## 反代重点

Nginx/Caddy 必须支持：

- WebSocket
- SSE / 流式输出
- 长超时
- 上传大小限制
- X-Forwarded-* 头
- HTTPS 终止

聊天输出卡住时，优先检查反代是否正确转发流式响应。

## Compose 语法验证

```bash
cp deploy/env/.env.example /tmp/openwebui.env
WEBUI_SECRET_KEY=dummy docker compose --env-file /tmp/openwebui.env -f deploy/compose/docker-compose.prod.yml config >/tmp/openwebui-compose.yml
```
