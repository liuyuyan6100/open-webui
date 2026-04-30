# 旧 Hermes Web UI / HUDUI Docker 配置复用评估

## 检查范围

已检查本机目录：

```text
/home/ubuntu/tool/hermes-web-ui-zh
/home/ubuntu/tool/hermes-hudui
```

## 结论

旧项目的 Docker 配置不能直接复用到 Open WebUI。

原因：

- `hermes-web-ui-zh` 是 Hermes Agent 的管理/聊天 Web UI，服务端口主要是 `6060`，并代理 Hermes Gateway `8642`。
- `hermes-hudui` 是 Hermes HUD 监控面板，默认端口 `3001`，没有 Docker Compose 配置。
- Open WebUI 是独立 AI Web 入口，容器内端口是 `8080`，数据目录是 `/app/backend/data`，镜像是 `ghcr.io/open-webui/open-webui`。

因此旧配置里的镜像、volume、entrypoint、UPSTREAM、HERMES_HOME、HERMES_BIN、patch-upstream.js 都不应迁移到 Open WebUI。

## 可复用项

可以复用的是运维经验和少量模式：

1. `restart: unless-stopped`
2. 通过 compose 管理端口和环境变量
3. 使用独立 bridge network
4. 生产配置放 deploy/ 下
5. 不把真实密钥提交到 Git
6. 旧服务当前占用 6060，Open WebUI 应避免使用 6060。
7. 使用独立 bridge network 隔离服务网络。

已采纳到当前 Open WebUI 模板：

- `restart: unless-stopped`
- `deploy/compose` + `deploy/env` 分层
- `open-webui-net` 独立 bridge network
- 避免使用 6060，默认使用 3000

## 当前运行态观察

检查时发现：

```text
hermes-webui-zh  ekkoye8888/hermes-web-ui:latest  0.0.0.0:6060->6060/tcp  Up 2 days
```

未发现 3000 端口占用，因此 Open WebUI 当前可优先使用 3000。

## hermes-web-ui-zh 关键配置摘要

```yaml
services:
  hermes-webui:
    image: ekkoye8888/hermes-web-ui:latest
    container_name: hermes-webui-zh
    ports:
      - "6060:6060"
    volumes:
      - /home/ubuntu/.hermes:/home/agent/.hermes:rw
      - /home/ubuntu/tool/hermes-web-ui-zh/deploy/patch-upstream.js:/patch-upstream.js:ro
    environment:
      - PORT=6060
      - UPSTREAM=http://10.0.0.35:8642
      - HERMES_HOME=/home/agent/.hermes
      - HERMES_BIN=/usr/bin/hermes
      - AUTH_DISABLED=false
    entrypoint: ["sh", "-c", "node /patch-upstream.js && node dist/server/index.js"]
    restart: unless-stopped
```

该配置是 Hermes Web UI 专用，不适合 Open WebUI。

## hermes-hudui 关键配置摘要

`hermes-hudui` 未发现 Docker Compose / Dockerfile。

项目运行方式是本机 Python/FastAPI：

```bash
hermes-hudui --port 3001
```

开发模式：

```bash
hermes-hudui --dev          # backend on :3001
cd frontend && npm run dev  # frontend on :5173
```

## 对 Open WebUI 的建议

继续保持当前 Open WebUI 生产 compose：

- 宿主机端口：3000
- 容器内端口：8080
- 容器名：open-webui
- 数据卷：open-webui-data:/app/backend/data
- 镜像：ghcr.io/open-webui/open-webui:<固定版本或 main>

不要复用：

- `UPSTREAM=http://10.0.0.35:8642`
- `HERMES_HOME=/home/agent/.hermes`
- `HERMES_BIN=/usr/bin/hermes`
- `patch-upstream.js`
- `6060:6060`

## 后续如果要并存

建议端口规划：

```text
6060  hermes-webui-zh，保留
3001  hermes-hudui，如需要
3000  Open WebUI
8642  Hermes Gateway / API Server
```

如后续统一上反代，可用域名区分：

```text
hermes.example.com  -> hermes-webui-zh:6060
hud.example.com     -> hermes-hudui:3001
ai.example.com      -> open-webui:3000
```
