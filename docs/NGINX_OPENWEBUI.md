# Open WebUI Nginx 反向代理模板
#
# 当前本机状态：
# - Nginx 已安装并运行
# - 已启用站点：hermes.aiclawonline.website、chat.aiclawonline.website
# - Open WebUI 本机端口：http://127.0.0.1:3000
# - 目标域名：openweb.aiclawonline.website
#
# 本文件作为启用说明和模板来源，避免直接改动现有成功链路。

## 启用步骤

1. 准备域名解析

将一个子域名解析到本机公网 IP。

当前检测到本机公网 IP：

```text
134.185.87.243
```

建议域名：

```text
openweb.aiclawonline.website
```

2. 复制模板

```bash
sudo cp deploy/nginx/open-webui.example.conf /etc/nginx/sites-available/open-webui
```

3. 修改域名

将模板里的：

```text
ai.example.com
```

替换成实际域名，例如：

```text
openweb.aiclawonline.website
```

4. 先只启用 HTTP 版本申请证书

如果使用 certbot nginx 插件，可先保留 80 server，临时注释 443 server，或让 certbot 自动改写：

```bash
sudo ln -s /etc/nginx/sites-available/open-webui /etc/nginx/sites-enabled/open-webui
sudo nginx -t
sudo systemctl reload nginx
sudo certbot --nginx -d openweb.aiclawonline.website
```

5. 验证

```bash
curl -I http://openweb.aiclawonline.website
curl -I https://openweb.aiclawonline.website
curl -sS https://openweb.aiclawonline.website/health
```

## 关键配置说明

Open WebUI 聊天和流式输出依赖长连接/SSE/WebSocket。反代必须包含：

```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_buffering off;
proxy_cache off;
proxy_read_timeout 3600s;
proxy_send_timeout 3600s;
client_max_body_size 100m;
```

## 已有站点保护

当前已启用：

```text
/etc/nginx/sites-enabled/hermes -> /etc/nginx/sites-available/hermes-webui
/etc/nginx/sites-enabled/chat -> /etc/nginx/sites-available/chat
```

不要修改这两个文件来承载 Open WebUI，避免影响现有成功链路。
