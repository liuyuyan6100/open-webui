# Roadmap

## 阶段 1：仓库初始化

- fork / clone Open WebUI
- 添加 upstream remote
- 建立 develop 分支
- 添加 docs/、deploy/、overlays/、patches/
- 添加 AGENTS.md

## 阶段 2：基础部署

- 添加 docker compose
- 添加 env 模板
- 添加 Nginx 配置
- 添加 healthcheck、backup、upgrade、rollback 脚本
- 完成本地或 staging 验证

## 阶段 3：品牌轻定制

- logo
- 名称
- 登录页文案
- 页脚链接

## 阶段 4：Provider 策略

- 梳理 Provider 接入方式
- 统一 OpenAI Compatible API
- usage 标记 actual / estimated / unavailable

## 阶段 5：生产发布

- staging 验证
- tag 发布
- 生产部署
- 发布后健康检查
- 回滚演练
