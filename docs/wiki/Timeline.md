# Timeline

## 2026-04-30

### 仓库初始化

- Fork Open WebUI 到 `liuyuyan6100/open-webui`
- Clone 到 `/home/ubuntu/openwebui-custom`
- 配置 remote：
  - `origin`: `https://github.com/liuyuyan6100/open-webui.git`
  - `upstream`: `https://github.com/open-webui/open-webui.git`
- 创建 `develop` 分支

### 文档和部署目录

新增：

```text
AGENTS.md
docs/
deploy/compose/
deploy/env/
deploy/nginx/
deploy/scripts/
```

关键文档：

```text
docs/DEPLOY.md
docs/ROLLBACK.md
docs/UPGRADE.md
docs/PROVIDER_STRATEGY.md
docs/PRODUCTION_STATUS.md
docs/CUSTOMIZATION_WORKFLOW.md
```

### Docker 部署

- 创建生产 Compose：`deploy/compose/docker-compose.prod.yml`
- 创建 env 模板：`deploy/env/.env.example`
- 创建真实生产 env：`deploy/env/.env.prod`，不提交 Git
- 生成随机 `WEBUI_SECRET_KEY`
- 启动容器 `open-webui`
- 初次健康检查通过

### 旧项目配置评估

检查：

```text
/home/ubuntu/tool/hermes-web-ui-zh
/home/ubuntu/tool/hermes-hudui
```

结论：

- `hermes-web-ui-zh` 是 Hermes 管理 UI，不能直接复用到 Open WebUI
- `hermes-hudui` 无 Docker Compose 配置
- 可复用运维模式：独立 network、restart 策略、端口规划、deploy 目录分层

### DNS 和 HTTPS

- Cloudflare DNS 新增：

```text
openweb.aiclawonline.website A 134.185.87.243
```

- Nginx 新增站点：

```text
/etc/nginx/sites-available/open-webui
```

- Certbot 申请证书成功：

```text
/etc/letsencrypt/live/openweb.aiclawonline.website/
```

- HTTPS 验证通过：

```text
https://openweb.aiclawonline.website/health -> {"status": true}
```

### Hermes 模型接入

Open WebUI 接入 Hermes API Server：

```text
OPENAI_API_BASE_URL=http://host.docker.internal:8642/v1
OPENAI_API_KEY=<Hermes API_SERVER_KEY>
```

验证：

```text
/v1/models -> hermes-agent
```

页面模型验证 OK。

### 生产固化

- 镜像从 `main` 固定到 `v0.9.2`
- 新增真实备份脚本 `deploy/scripts/backup.sh`
- 测试备份成功，备份包约 964M
- 新增生产状态和魔改工作流文档

## 当前状态

```text
Open WebUI: healthy
入口：https://openweb.aiclawonline.website
镜像：ghcr.io/open-webui/open-webui:v0.9.2
模型：hermes-agent
```
