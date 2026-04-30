# 回滚说明

## 回滚范围

回滚分两类：

1. 应用版本回滚
2. 数据层回滚或恢复

## 应用回滚

推荐通过镜像 tag 回滚：

```bash
APP_IMAGE=openwebui-custom:<previous-tag> docker compose -f deploy/compose/docker-compose.prod.yml up -d
```

## 数据保护

发布前执行备份：

```bash
bash deploy/scripts/backup.sh
```

如果升级包含不可逆数据库迁移，必须先在 staging 验证，并明确回滚策略。

## 回滚后验证

- 页面可打开
- 登录正常
- 聊天正常
- 历史会话可读
- 模型列表正常
- 反代无异常 4xx/5xx
