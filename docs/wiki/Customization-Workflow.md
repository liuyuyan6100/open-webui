# Customization Workflow

本页说明后续如果要魔改 Open WebUI，应该如何操作。

## 当前原则

1. 暂不魔改生产。
2. 魔改前必须先备份。
3. 不直接在 `main` 上改。
4. 每个功能单独开 `feature/*` 分支。
5. 优先轻定制，少改核心。
6. 修改后必须验证登录、模型、聊天、流式输出和历史会话。

## 分支模型

```text
main       跟随 upstream/main
develop    本地定制和部署配置
feature/*  单个魔改功能
hotfix/*   线上紧急修复
```

## 开始魔改

```bash
cd /home/ubuntu/openwebui-custom
git checkout develop
git pull --ff-only origin develop
git checkout -b feature/your-change-name
```

## 推荐先做的轻定制

优先级从高到低：

1. 站点名称
2. logo
3. 登录页中文文案
4. 页脚链接
5. 默认欢迎语
6. 默认模型选择
7. 简单导航入口

这些通常风险较低，容易回滚。

## 谨慎修改区域

以下区域不要随便动：

- 认证流程
- 用户权限
- 数据库 schema
- migration
- 聊天主流程
- 文件上传
- Provider 计费和 usage 统计
- Hermes API Server 适配

## 开发后验证

基础验证：

```bash
git diff --stat
docker compose --env-file deploy/env/.env.prod -f deploy/compose/docker-compose.prod.yml config
bash deploy/scripts/healthcheck.sh http://127.0.0.1:3000
```

页面验证：

- 登录正常
- 模型列表正常
- `hermes-agent` 可选
- 简短聊天正常
- 长回答流式输出正常
- 历史会话正常

## 上生产流程

1. 备份：

```bash
bash deploy/scripts/backup.sh
```

2. 合并：

```bash
git checkout develop
git merge --no-ff feature/your-change-name
```

3. 部署：

```bash
docker compose --env-file deploy/env/.env.prod -f deploy/compose/docker-compose.prod.yml up -d
```

4. 验证：

```bash
curl -sS https://openweb.aiclawonline.website/health
```

## 回滚

如果只是应用层问题，回滚镜像或 Git 变更。

如果数据损坏，按 [[Backup-and-Restore]] 恢复 Docker volume。

## 提交格式

```text
feat: customize login branding
fix: repair streaming proxy config
docs: record production deployment status
chore: pin open webui image version
```
