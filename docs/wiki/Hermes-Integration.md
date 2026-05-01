# Hermes Integration

Open WebUI 当前不直接配置 OpenAI/OpenRouter 等模型 key，而是复用 Hermes API Server。

## 架构

```text
Open WebUI
  -> OpenAI Compatible API
  -> http://host.docker.internal:8642/v1
  -> Hermes API Server
  -> Hermes 当前模型配置
```

## Open WebUI 配置

生产 env：

```text
/home/ubuntu/openwebui-custom/deploy/env/.env.prod
```

关键变量：

```text
OPENAI_API_BASE_URL=http://host.docker.internal:8642/v1
OPENAI_API_KEY=<Hermes API_SERVER_KEY>
```

Open WebUI 容器内验证：

```bash
docker exec open-webui sh -lc 'echo $OPENAI_API_BASE_URL; echo ${#OPENAI_API_KEY}'
```

期望：

```text
http://host.docker.internal:8642/v1
67
```

## Hermes API Server

API Server 监听：

```text
0.0.0.0:8642
```

Key 来源：

```text
/home/ubuntu/.hermes/.env: API_SERVER_KEY
```

验证：

```bash
KEY=$(awk -F= '/^API_SERVER_KEY=/{print $2; exit}' /home/ubuntu/.hermes/.env)
curl -sS -H "Authorization: Bearer $KEY" http://127.0.0.1:8642/v1/models
unset KEY
```

期望返回：

```json
{
  "object": "list",
  "data": [
    {
      "id": "hermes-agent"
    }
  ]
}
```

## Hermes 当前模型

Hermes 当前配置：

```text
Provider: custom
Model: gpt-5.5
Base URL: https://ai.dzzzz.cf/v1
```

因此 Open WebUI 页面里看到的是：

```text
hermes-agent
```

实际请求由 Hermes 再路由到当前模型。

## 常见问题

### Open WebUI 提示需要配置模型

检查 Hermes API Server：

```bash
sudo lsof -nP -iTCP:8642 -sTCP:LISTEN
```

检查容器内访问：

```bash
docker exec open-webui sh -lc 'curl -sS -H "Authorization: Bearer $OPENAI_API_KEY" "$OPENAI_API_BASE_URL/models"'
```

### 401 Invalid API key

说明 Open WebUI 的 `OPENAI_API_KEY` 与 Hermes 的 `API_SERVER_KEY` 不一致。

重新同步：

```bash
KEY=$(awk -F= '/^API_SERVER_KEY=/{print $2; exit}' /home/ubuntu/.hermes/.env)
# 编辑 deploy/env/.env.prod，将 OPENAI_API_KEY 设置为 $KEY
unset KEY
```

然后重建：

```bash
cd /home/ubuntu/openwebui-custom
docker compose --env-file deploy/env/.env.prod -f deploy/compose/docker-compose.prod.yml up -d --force-recreate open-webui
```
