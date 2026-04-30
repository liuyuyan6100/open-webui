# Open WebUI 定制化项目

本仓库基于 Open WebUI 进行长期维护与轻量定制，目标是替代现有 huduiwebui，作为统一 AI Web 入口。

## 目标

- 保持 Open WebUI 上游可升级
- 将本地定制控制在 overlays、deploy、docs 等边界内
- 支持多模型 / 多 Provider 接入
- 支持可验证的部署、升级与回滚
- 避免把博客、官网等无关功能揉进 Open WebUI 主体

## 推荐分支

- main：尽量贴近官方 upstream/main
- develop：长期集成本地定制
- feature/*：单功能开发
- release/*：发布准备
- hotfix/*：线上紧急修复

## 目录说明

```text
docs/       架构、部署、升级、回滚、Provider 策略文档
deploy/     compose、env、nginx、运维脚本
overlays/   品牌、配置、Provider 适配等轻量覆盖
patches/    必要补丁记录
AGENTS.md   给 AI Agent 和协作者的项目约束
```

## 基本原则

1. 先保持上游可升级，再做本地定制。
2. 优先新增配置、脚本、overlay，不直接改核心逻辑。
3. 修改部署链路必须更新 docs/DEPLOY.md。
4. 修改升级流程必须更新 docs/UPGRADE.md。
5. 修改 Provider 或 usage 逻辑必须更新 docs/PROVIDER_STRATEGY.md。
6. 发布前必须验证页面、登录、聊天、流式输出、模型列表、历史会话和反代链路。
