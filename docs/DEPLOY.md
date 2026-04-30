# 部署说明

## 目录

```text
deploy/compose/   Docker Compose 文件
deploy/env/       环境变量模板
deploy/nginx/     反向代理配置
deploy/scripts/   构建、启动、健康检查脚本
```

## 环境变量

从模板复制：

```bash
cp deploy/env/.env.example deploy/env/.env.prod
```

生产环境不要把真实密钥提交到 Git。

## 启动生产服务

```bash
bash deploy/scripts/up-prod.sh
```

## 健康检查

```bash
bash deploy/scripts/healthcheck.sh http://127.0.0.1:3000
```

## 反代重点

Nginx/Caddy 必须支持：

- WebSocket
- SSE / 流式输出
- 长超时
- 上传大小限制
- X-Forwarded-* 头
- HTTPS 终止

聊天输出卡住时，优先检查反代是否正确转发流式响应。
