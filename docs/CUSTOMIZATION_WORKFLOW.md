# 魔改工作流

本文说明后续如果要自己魔改 Open WebUI，应如何操作，尽量避免破坏上游升级能力和生产链路。

## 总原则

1. 不直接在 `main` 上改。
2. 生产稳定代码从 `develop` 出。
3. 每个魔改点单独开 `feature/*` 分支。
4. 优先配置、overlay、插件化，少改核心。
5. 修改前先备份，修改后必须验证。
6. 能不改数据库 schema 就不改数据库 schema。
7. 能不改认证和聊天主流程就不改。

## 分支模型

```text
main       跟随 upstream/main，尽量不做业务修改
develop    集成本地长期定制
feature/*  单个魔改功能
hotfix/*   线上紧急修复
```

## 开始一个魔改

```bash
cd /home/ubuntu/openwebui-custom
git checkout develop
git pull --ff-only origin develop
git checkout -b feature/your-change-name
```

## 推荐魔改顺序

### 1. 品牌轻定制

适合先做：

- 名称
- logo
- 登录页文案
- 页脚链接
- 默认欢迎语
- 默认模型选择

优先找配置项或前端静态资源，不要改后端核心。

### 2. Provider / 模型接入

当前生产已通过 Hermes API Server 接入：

```text
http://host.docker.internal:8642/v1
model: hermes-agent
```

如需新增直连 Provider，建议先在 Open WebUI 管理后台配置，不要直接写死到代码。

### 3. UI 交互改造

可改，但要注意上游升级冲突。建议：

- 改动集中在少量组件
- 每次改完记录路径
- 截图或写验收说明

### 4. 后端逻辑改造

谨慎。尤其避免随意修改：

- 认证
- 用户权限
- 数据库迁移
- 聊天主流程
- 文件上传
- Provider 适配核心

## 开发验证

每次改动至少执行：

```bash
git diff --stat
docker compose --env-file deploy/env/.env.prod -f deploy/compose/docker-compose.prod.yml config
bash deploy/scripts/healthcheck.sh http://127.0.0.1:3000
```

如果改了前端或后端源码，还需要按 Open WebUI 官方项目实际命令执行构建/测试。

## 上生产前

1. 备份：

```bash
bash deploy/scripts/backup.sh
```

2. 合并到 develop：

```bash
git checkout develop
git merge --no-ff feature/your-change-name
```

3. 构建或拉取目标镜像。

4. 重启：

```bash
docker compose --env-file deploy/env/.env.prod -f deploy/compose/docker-compose.prod.yml up -d
```

5. 验证：

```bash
curl -sS https://openweb.aiclawonline.website/health
```

并在页面确认：

- 登录正常
- 模型列表正常
- 聊天正常
- 流式输出正常
- 历史会话正常

## 回滚

如只是应用版本问题：

```bash
APP_IMAGE=<previous-image> docker compose --env-file deploy/env/.env.prod -f deploy/compose/docker-compose.prod.yml up -d
```

如数据已损坏，用备份包恢复 Docker volume。详见备份包内 `RESTORE.md`。

## 什么情况要特别小心

以下变更必须先单独计划，不要直接改：

- 数据库 schema / migration
- 登录认证
- 用户权限
- 多租户隔离
- 文件上传和对象存储
- Provider 计费统计
- Hermes API Server 协议适配
- 生产域名/Nginx/证书

## 推荐提交格式

```text
feat: customize login branding
fix: repair streaming proxy config
docs: record production deployment status
chore: pin open webui image version
```
