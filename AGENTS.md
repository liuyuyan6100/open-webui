# AGENTS.md

本文件约束 AI Agent 和协作者如何修改本仓库。

## 项目定位

本仓库是基于 Open WebUI 的长期定制版本，用于替代 huduiwebui，作为统一 AI Web 入口。

## 修改原则

1. 最小改动优先。
2. 不要为了短期需求破坏 upstream 可合并性。
3. 优先使用 deploy/、docs/、overlays/、patches/ 承载定制。
4. 非必要不修改认证、聊天主流程、数据库 schema、迁移逻辑。
5. 修改前先确认影响面，修改后必须给出验证证据。

## 分支规则

- main：贴近 Open WebUI 官方 main，不承载长期业务开发。
- develop：集成本地定制。
- feature/*：每个功能单独分支。
- hotfix/*：线上紧急修复。

## Provider 与 usage 规则

多 Provider 接入时，差异应收口到兼容层。

usage 必须区分：

- actual：Provider 返回的真实 usage
- estimated：本地估算 usage
- unavailable：不可用

不得把估算值伪装成精确计费数据。

## 部署规则

部署资产统一放在 deploy/：

- deploy/compose/
- deploy/env/
- deploy/nginx/
- deploy/scripts/

修改部署配置后必须更新 docs/DEPLOY.md。

## 发布前验收

至少验证：

- 页面可打开
- 登录正常
- 聊天正常
- 流式输出正常
- 模型列表正常
- 历史会话正常
- OpenAI 类 Provider 正常
- 本地模型 Provider 正常
- usage 显示符合预期
- Nginx/Caddy 反代无明显 4xx/5xx
