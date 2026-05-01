# Backup and Restore

## 备份原则

以下操作前必须备份：

- 升级 Open WebUI 镜像
- 修改生产 env
- 修改 Nginx
- 魔改源码并部署
- 迁移服务器
- 重要 Provider/认证配置变更

## 执行备份

```bash
cd /home/ubuntu/openwebui-custom
bash deploy/scripts/backup.sh
```

默认备份目录：

```text
/home/ubuntu/openwebui-custom/backups/
```

备份包命名：

```text
openwebui-YYYYMMDD-HHMMSS.tar.gz
```

## 备份内容

备份脚本会包含：

```text
open-webui-data.tar.gz       Docker volume 数据
deploy/compose/              Compose 配置
deploy/nginx/                仓库内 Nginx 模板
secrets/.env.prod            生产 env，含密钥，权限 600
nginx/open-webui             实际 Nginx 站点配置
RESTORE.md                   恢复说明
```

## 当前数据卷

```text
compose_open-webui-data
```

查看：

```bash
docker volume inspect compose_open-webui-data
```

## 恢复流程

先停止服务：

```bash
cd /home/ubuntu/openwebui-custom
docker compose --env-file deploy/env/.env.prod -f deploy/compose/docker-compose.prod.yml down
```

解压备份包：

```bash
cd /home/ubuntu/openwebui-custom/backups
tar xzf openwebui-YYYYMMDD-HHMMSS.tar.gz
cd openwebui-YYYYMMDD-HHMMSS
```

恢复 volume：

```bash
docker volume create compose_open-webui-data
docker run --rm \
  -v compose_open-webui-data:/data \
  -v "$(pwd):/backup" \
  alpine:3.20 \
  sh -c 'cd /data && tar xzf /backup/open-webui-data.tar.gz'
```

恢复 env：

```bash
cp secrets/.env.prod /home/ubuntu/openwebui-custom/deploy/env/.env.prod
chmod 600 /home/ubuntu/openwebui-custom/deploy/env/.env.prod
```

恢复 Nginx，如需要：

```bash
sudo cp nginx/open-webui /etc/nginx/sites-available/open-webui
sudo nginx -t
sudo systemctl reload nginx
```

启动：

```bash
cd /home/ubuntu/openwebui-custom
docker compose --env-file deploy/env/.env.prod -f deploy/compose/docker-compose.prod.yml up -d
```

验证：

```bash
curl -sS https://openweb.aiclawonline.website/health
```

## 注意

- 备份包包含 `.env.prod`，里面有 API key，不要上传公开位置。
- 当前一次测试备份约 964M，因为 Open WebUI 数据卷内含 embedding 模型缓存。
- 如果只是应用镜像回滚，不一定需要恢复 volume。
