# Open WebUI 运维首页

本 Wiki 记录 `liuyuyan6100/open-webui` 当前生产部署、运维命令、备份恢复、升级回滚和后续魔改流程。

## 当前生产入口

```text
https://openweb.aiclawonline.website
```

健康检查：

```bash
curl -sS https://openweb.aiclawonline.website/health
```

期望返回：

```json
{"status": true}
```

## 当前状态摘要

- Open WebUI 已部署上线
- HTTPS 已启用
- 首次管理员账号初始化已完成
- 模型接入复用 Hermes API Server
- 当前模型在 Open WebUI 中显示为 `hermes-agent`
- Docker 镜像已固定为 `ghcr.io/open-webui/open-webui:v0.9.2`
- Cloudflare DNS 当前为 DNS only，不启用代理小云朵

## Wiki 页面

- [[Production-Status]]：生产状态、路径、端口、域名、证书、容器
- [[Operations-Runbook]]：日常运维命令
- [[Backup-and-Restore]]：备份和恢复
- [[Upgrade-and-Rollback]]：升级和回滚
- [[Hermes-Integration]]：Hermes API Server 接入方式
- [[Customization-Workflow]]：后续魔改流程
- [[Timeline]]：本次部署过程记录

## 仓库与分支

仓库：

```text
https://github.com/liuyuyan6100/open-webui
```

当前主要分支：

```text
main      跟随 upstream/main
develop   本地定制和部署配置
```

本机项目路径：

```text
/home/ubuntu/openwebui-custom
```

## 重要原则

1. 不在 `main` 上做长期定制。
2. 生产配置 `.env.prod` 不提交 Git。
3. 升级、魔改、回滚前先执行备份。
4. 反代、证书、Docker 变更后必须验证 `/health`。
5. Cloudflare 小云朵暂不打开，避免影响 WebSocket/SSE/流式输出。
