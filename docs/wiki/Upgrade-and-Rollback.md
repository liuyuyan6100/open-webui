# Upgrade and Rollback

## 当前版本

```text
ghcr.io/open-webui/open-webui:v0.9.2
```

生产不使用 `main`，避免未来重启或拉镜像时不可控升级。

## 升级前准备

1. 确认当前状态：

```bash
cd /home/ubuntu/openwebui-custom
docker compose --env-file deploy/env/.env.prod -f deploy/compose/docker-compose.prod.yml ps
curl -sS https://openweb.aiclawonline.website/health
```

2. 备份：

```bash
bash deploy/scripts/backup.sh
```

3. 记录当前镜像：

```bash
docker inspect open-webui --format '{{.Config.Image}}'
```

## 升级镜像

推荐使用自动化脚本完成备份、更新、验证和失败回滚：

```bash
cd /home/ubuntu/openwebui-custom
bash deploy/scripts/update-image.sh --image ghcr.io/open-webui/open-webui:v0.x.x
```

先 dry-run：

```bash
bash deploy/scripts/update-image.sh --image ghcr.io/open-webui/open-webui:v0.x.x --dry-run
```

详见：`docs/AUTOMATED_IMAGE_UPDATE.md`。

手动方式如下。

修改：

```text
/home/ubuntu/openwebui-custom/deploy/env/.env.prod
```

将：

```text
APP_IMAGE=ghcr.io/open-webui/open-webui:v0.9.2
```

改为目标版本，例如：

```text
APP_IMAGE=ghcr.io/open-webui/open-webui:v0.x.x
```

验证 compose：

```bash
docker compose --env-file deploy/env/.env.prod -f deploy/compose/docker-compose.prod.yml config >/tmp/openwebui-compose.yml
```

部署：

```bash
docker compose --env-file deploy/env/.env.prod -f deploy/compose/docker-compose.prod.yml up -d
```

## 升级后验证

```bash
docker compose --env-file deploy/env/.env.prod -f deploy/compose/docker-compose.prod.yml ps
curl -sS https://openweb.aiclawonline.website/health
```

页面验证：

- 登录正常
- 模型列表正常
- `hermes-agent` 可见
- 简短聊天正常
- 长回答流式输出正常
- 历史会话正常

## 回滚应用镜像

如果只是应用版本问题，先把 `.env.prod` 的 APP_IMAGE 改回旧版本：

```text
APP_IMAGE=ghcr.io/open-webui/open-webui:v0.9.2
```

然后：

```bash
cd /home/ubuntu/openwebui-custom
docker compose --env-file deploy/env/.env.prod -f deploy/compose/docker-compose.prod.yml up -d
```

验证：

```bash
curl -sS https://openweb.aiclawonline.website/health
```

## 数据恢复

如果升级导致数据库或配置损坏，按 [[Backup-and-Restore]] 恢复 Docker volume。

## Git 分支同步

上游同步建议：

```bash
cd /home/ubuntu/openwebui-custom
git fetch upstream
git checkout main
git merge upstream/main
git push origin main
git checkout develop
git merge main
```

解决冲突后再验证和部署。

## 风险提示

- Open WebUI 可能包含数据库迁移，升级前必须备份。
- 不要从旧版本跨太多大版本直接升级生产。
- 先 staging 后 production 是更稳妥做法。
