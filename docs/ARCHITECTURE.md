# 架构说明

## 总体定位

Open WebUI 负责 AI 聊天入口、模型选择、会话管理、用户界面与基础管理能力。

博客、官网、文档站等内容系统不建议直接放进 Open WebUI，应独立部署。

推荐域名划分：

```text
yourdomain.com      主站 / 博客
ai.yourdomain.com   Open WebUI
```

## 推荐架构

```text
Browser
  ↓ HTTPS
Nginx / Caddy
  ↓
Open WebUI
  ↓
Provider Adapter / OpenAI Compatible API
  ↓
LLM Providers / Local Models / Gateway
```

## 定制边界

推荐定制：

- logo
- 品牌名
- 登录页文案
- 页脚链接
- 默认配置
- Provider 兼容层
- 部署脚本

谨慎修改：

- 认证流程
- 聊天核心逻辑
- 数据库 schema
- 迁移脚本
- 上游频繁变化的核心文件
