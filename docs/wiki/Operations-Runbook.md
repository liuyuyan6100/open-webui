# Operations Runbook

## 全局运维入口

已安装全局命令：

```bash
openwebui-ops
```

实际路径：

```text
/usr/local/bin/openwebui-ops
```

实现方式：root 拥有的可执行 wrapper 文件，不是 symlink。

wrapper 源文件：

```text
/home/ubuntu/openwebui-custom/deploy/scripts/openwebui-ops-global-wrapper.sh
```

实际控制器：

```text
/home/ubuntu/openwebui-custom/deploy/scripts/openwebui-ops.sh
```

默认项目目录：

```text
/home/ubuntu/openwebui-custom
```

核验：

```bash
command -v openwebui-ops
ls -l /usr/local/bin/openwebui-ops
openwebui-ops status
```

项目目录移动时可覆盖：

```bash
OPENWEBUI_CUSTOM_ROOT=/path/to/openwebui-custom openwebui-ops status
```

常用命令：

```bash
openwebui-ops status
openwebui-ops backup
openwebui-ops signup status
openwebui-ops usage status --period today
openwebui-ops usage enforce --dry-run
```

## 进入项目目录

```bash
cd /home/ubuntu/openwebui-custom
```

## 查看容器状态

```bash
docker compose --env-file deploy/env/.env.prod -f deploy/compose/docker-compose.prod.yml ps
```

或：

```bash
docker ps --filter name=open-webui
```

## 健康检查

本机：

```bash
curl -sS http://127.0.0.1:3000/health
```

公网：

```bash
curl -sS https://openweb.aiclawonline.website/health
```

期望：

```json
{"status": true}
```

项目脚本：

```bash
bash deploy/scripts/healthcheck.sh http://127.0.0.1:3000
```

## 查看日志

Open WebUI：

```bash
docker logs -f open-webui
```

Nginx：

```bash
sudo tail -f /var/log/nginx/access.log /var/log/nginx/error.log
```

Hermes Gateway：

```bash
tail -f /home/ubuntu/.hermes/logs/gateway.log
```

或 profile 日志：

```bash
tail -f /home/ubuntu/.hermes/profiles/hermes-msg/logs/gateway.log
```

## 重启 Open WebUI

```bash
cd /home/ubuntu/openwebui-custom
docker compose --env-file deploy/env/.env.prod -f deploy/compose/docker-compose.prod.yml restart
```

## 重新创建容器

用于 env 或镜像变化后：

```bash
cd /home/ubuntu/openwebui-custom
docker compose --env-file deploy/env/.env.prod -f deploy/compose/docker-compose.prod.yml up -d
```

## 停止服务

```bash
cd /home/ubuntu/openwebui-custom
docker compose --env-file deploy/env/.env.prod -f deploy/compose/docker-compose.prod.yml down
```

注意：默认不会删除 Docker volume，数据仍保留。

## 检查 Nginx

```bash
sudo nginx -t
sudo systemctl status nginx --no-pager
```

Reload：

```bash
sudo systemctl reload nginx
```

## 检查证书

```bash
sudo certbot certificates -d openweb.aiclawonline.website
```

## 检查 Hermes API Server

```bash
sudo lsof -nP -iTCP:8642 -sTCP:LISTEN
```

测试模型接口：

```bash
KEY=$(awk -F= '/^API_SERVER_KEY=/{print $2; exit}' /home/ubuntu/.hermes/.env)
curl -sS -H "Authorization: Bearer $KEY" http://127.0.0.1:8642/v1/models
unset KEY
```

## 常见问题

### 页面提示需要配置模型

检查：

```bash
docker exec open-webui sh -lc 'echo $OPENAI_API_BASE_URL; echo ${#OPENAI_API_KEY}'
```

期望：

```text
http://host.docker.internal:8642/v1
67
```

再从容器内测：

```bash
docker exec open-webui sh -lc 'curl -sS -H "Authorization: Bearer $OPENAI_API_KEY" "$OPENAI_API_BASE_URL/models"'
```

### HTTPS 正常但聊天卡住

优先检查 Nginx 是否有：

```nginx
proxy_buffering off;
proxy_read_timeout 3600s;
proxy_send_timeout 3600s;
```

### 502/504

检查：

1. `docker ps` 中 open-webui 是否运行
2. `curl http://127.0.0.1:3000/health`
3. `sudo nginx -t`
4. `docker logs --tail 100 open-webui`
