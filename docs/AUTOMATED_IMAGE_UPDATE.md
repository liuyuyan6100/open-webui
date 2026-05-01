# 自动化镜像更新与备份

本项目提供：

```text
deploy/scripts/update-image.sh
```

用于自动完成 Open WebUI 生产镜像更新。脚本会在更新前备份，更新后验证，失败时自动回滚到旧镜像。

## 适用场景

- Open WebUI 从一个固定版本升级到另一个固定版本
- 当前版本重建验证
- 小版本安全升级
- 回滚演练前的自动化验证

不适合：

- 跨大版本且包含重大数据库迁移的升级
- 未先阅读 release notes 的生产升级
- 使用浮动 `main` tag

## 基本命令

Dry run，不改任何文件、不重启容器：

```bash
cd /home/ubuntu/openwebui-custom
bash deploy/scripts/update-image.sh --image ghcr.io/open-webui/open-webui:v0.9.2 --dry-run
```

正式更新：

```bash
cd /home/ubuntu/openwebui-custom
bash deploy/scripts/update-image.sh --image ghcr.io/open-webui/open-webui:v0.9.2
```

非交互执行：

```bash
bash deploy/scripts/update-image.sh --image ghcr.io/open-webui/open-webui:v0.9.2 -y
```

## 脚本流程

1. 检查参数和 `.env.prod`
2. 拒绝 `:main` 浮动 tag
3. 读取当前旧镜像
4. 执行 `deploy/scripts/backup.sh`
5. 拉取目标镜像
6. 修改 `.env.prod` 中的 `APP_IMAGE`
7. 执行 `docker compose config` 验证
8. `docker compose up -d --force-recreate open-webui`
9. 等待容器健康
10. 检查本机健康接口
11. 检查公网健康接口
12. 成功则输出实际镜像和备份包路径
13. 失败则自动把 `APP_IMAGE` 改回旧镜像并重建容器

## 参数

```text
--image <image>   目标镜像，必须是明确 tag
--dry-run         仅验证，不修改、不重启
--skip-backup     跳过备份，不推荐
--skip-pull       跳过 docker pull
-y, --yes         非交互执行
-h, --help        帮助
```

## 环境变量

```text
HEALTH_URL        公网健康检查，默认 https://openweb.aiclawonline.website/health
LOCAL_HEALTH_URL  本机健康检查，默认 http://127.0.0.1:3000
BACKUP_DIR        备份输出根目录，传给 backup.sh
TIMEOUT_SECONDS   等待容器健康超时，默认 180
```

## 验证命令

脚本语法：

```bash
bash -n deploy/scripts/update-image.sh
```

Compose 渲染：

```bash
bash deploy/scripts/update-image.sh --image ghcr.io/open-webui/open-webui:v0.9.2 --dry-run
```

健康检查：

```bash
bash deploy/scripts/healthcheck.sh http://127.0.0.1:3000
curl -sS https://openweb.aiclawonline.website/health
```

## 回滚说明

脚本内置应用镜像回滚：

- 如果容器没有变 healthy/running
- 或公网健康检查失败

脚本会把 `.env.prod` 中的 `APP_IMAGE` 改回旧镜像并重新创建容器。

注意：

- 这只处理应用镜像回滚。
- 如果升级触发了不可逆数据库迁移，需要使用 `deploy/scripts/backup.sh` 生成的备份包恢复 Docker volume。

## 安全注意

- `.env.prod` 含密钥，不提交 Git。
- 备份包含 `.env.prod`，不要上传公开位置。
- 不要使用 `main` tag 作为生产镜像。
- 生产升级前应阅读 Open WebUI release notes。
