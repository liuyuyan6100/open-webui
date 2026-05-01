# Open WebUI 用户注册、审批与模型授权运维

更新时间：2026-05-01

## 适用范围

本文记录当前生产 Open WebUI 的测试用户注册、管理员审批、普通用户模型可见性、以及脚本化运维入口。

生产入口：

```text
https://openweb.aiclawonline.website
```

项目目录：

```text
/home/ubuntu/openwebui-custom
```

## 当前策略

```text
注册入口：默认关闭
临时开放注册：允许
新用户默认角色：pending
管理员审批后角色：user
禁止给测试用户：admin
API Keys：关闭
模型后端：Hermes API Server
普通用户可用模型：hermes-agent
```

原则：

1. 不长期开放公网注册。
2. 需要新增家人/测试用户时，短期开启注册。
3. 注册后管理员审批为 `user`。
4. 审批完成后立即关闭注册。
5. 普通用户只使用管理员统一发布的模型，不自行配置 Provider/API Key。

## 主控脚本

主控脚本路径：

```text
deploy/scripts/openwebui-ops.sh
```

已安装全局命令包装器：

```text
/usr/local/bin/openwebui-ops
```

因此可以在任意目录直接执行：

```bash
# 查看健康状态
openwebui-ops status

# 查看注册、用户、健康状态
openwebui-ops signup status

# 临时开启注册，新用户仍为 pending
openwebui-ops signup enable

# 关闭注册
openwebui-ops signup disable

# 执行备份
openwebui-ops backup

# 启动生产服务
openwebui-ops up

# 查看用户用量
openwebui-ops usage status --period today

# 按阈值巡检，dry-run 不会真的禁用
openwebui-ops usage enforce --daily-tokens 50000 --daily-messages 100 --dry-run

# 手动禁用指定用户
openwebui-ops usage disable 506490465@qq.com --dry-run

# 镜像更新 dry-run
openwebui-ops update-image --image ghcr.io/open-webui/open-webui:v0.9.2 --dry-run
```

## 注册控制脚本

注册控制脚本路径：

```text
deploy/scripts/signup-control.sh
```

直接调用：

```bash
cd /home/ubuntu/openwebui-custom

bash deploy/scripts/signup-control.sh status
bash deploy/scripts/signup-control.sh enable
bash deploy/scripts/signup-control.sh disable
```

脚本行为：

- `status`
  - 读取公网 `/api/config`
  - 读取 DB 中 `ui.enable_signup` / `ui.default_user_role`
  - 列出用户及角色
  - 检查公网 `/health`

- `enable`
  - 备份 SQLite 数据库
  - 设置 `ui.enable_signup=true`
  - 设置 `ui.default_user_role=pending`
  - 重启 `open-webui`
  - 等待容器 healthy
  - 验证公网配置

- `disable`
  - 备份 SQLite 数据库
  - 设置 `ui.enable_signup=false`
  - 保持 `ui.default_user_role=pending`
  - 重启 `open-webui`
  - 等待容器 healthy
  - 验证公网配置

数据库路径：

```text
容器内：/app/backend/data/webui.db
Docker volume：compose_open-webui-data
```

备份文件格式：

```text
/app/backend/data/webui.db.pre-enable-signup-YYYYmmddHHMMSS.bak
/app/backend/data/webui.db.pre-disable-signup-YYYYmmddHHMMSS.bak
```

## 管理员审批用户

用户注册后，如果看到：

```text
账号待激活
请联系管理员以获取访问权限
```

说明该账号角色是 `pending`。

管理员处理方式：

1. 用管理员账号登录 Open WebUI。
2. 进入 Admin Panel / 管理员面板。
3. 进入 Users / 用户。
4. 找到新注册用户。
5. 将角色从 `pending` 改为 `user`。
6. 不要授予 `admin`。

当前管理员：

```text
lyy6100 / liuyuyan6100@163.com
```

## 普通 user 看不到模型的原因与修复

### 原因

当前 Open WebUI 使用 OpenAI-compatible 方式接入 Hermes API Server：

```text
OPENAI_API_BASE_URL=http://host.docker.internal:8642/v1
模型：hermes-agent
```

Open WebUI v0.9.2 对普通 `user` 会执行模型访问控制。

如果模型只是从外部 OpenAI-compatible `/v1/models` 动态拉取，而数据库中没有对应的 model override / access grant，现象是：

```text
admin 能看到模型
普通 user 看不到模型
```

原因是无 DB 授权记录的动态模型仅 admin 可见，普通用户会被过滤。

### 当前修复状态

已在 Open WebUI 数据库中为 `hermes-agent` 建立模型 override，并授予所有已审批用户只读访问：

```text
model.id = hermes-agent
model.is_active = 1
access_grant.resource_type = model
access_grant.resource_id = hermes-agent
access_grant.principal_type = user
access_grant.principal_id = *
access_grant.permission = read
```

含义：

```text
所有通过审批的 user 都能看到并使用 hermes-agent
但不能管理模型配置
```

普通用户不需要配置 Provider、API Key 或模型后端。

## 用户用量统计与超额禁用

用量控制脚本路径：

```text
deploy/scripts/user-usage.sh
```

推荐统一通过主控脚本调用：

```bash
cd /home/ubuntu/openwebui-custom

# 今日用量，默认跳过 admin
openwebui-ops usage status --period today

# 本月用量，包含 admin
openwebui-ops usage status --period month --include-admin

# 按默认阈值 dry-run 巡检
openwebui-ops usage enforce --dry-run

# 自定义阈值 dry-run 巡检
openwebui-ops usage enforce --daily-tokens 50000 --daily-messages 100 --monthly-tokens 1000000 --monthly-messages 1000 --dry-run

# 真正执行：超额用户会被改为 pending
openwebui-ops usage enforce --daily-tokens 50000 --daily-messages 100

# 手动禁用某个用户
openwebui-ops usage disable 506490465@qq.com
```

默认阈值：

```text
daily_tokens=50000
daily_messages=100
monthly_tokens=1000000
monthly_messages=1000
```

脚本统计来源：

```text
chat_message.role = assistant
chat_message.usage.input_tokens / output_tokens / total_tokens
chat_message.created_at
```

脚本行为：

- `status`：输出用户消息数、input tokens、output tokens、total tokens。
- `enforce`：超过阈值的非 admin 用户改为 `pending`。
- `disable`：按 email 或 user id 将指定非 admin 用户改为 `pending`。
- 默认跳过 admin；除非显式传 `--include-admin`。
- `--dry-run` 只打印将执行的动作，不改数据库。

注意：这是“巡检后禁用”，不是请求前硬拦截。可能出现用户超出一点后才被禁用。若需要严格硬限额，应后续在 Hermes API Server / Gateway 层实现请求前拦截。

### 自动执行

当前已通过系统 cron 每小时自动执行一次用量巡检：

```text
/etc/cron.d/openwebui-usage-enforce
```

计划任务内容：

```cron
0 * * * * ubuntu cd /home/ubuntu/openwebui-custom && /usr/local/bin/openwebui-ops usage enforce >> /var/log/openwebui-usage-enforce.log 2>&1
```

执行日志：

```text
/var/log/openwebui-usage-enforce.log
```

查看 cron：

```bash
sudo sed -n '1,120p' /etc/cron.d/openwebui-usage-enforce
systemctl is-active cron
```

查看执行日志：

```bash
tail -n 100 /var/log/openwebui-usage-enforce.log
```

关闭自动限额：

```bash
sudo rm -f /etc/cron.d/openwebui-usage-enforce
```

## 敏感信息与 Git 提交检查

最近一次检查结论：未发现真实密钥被提交到 Git。

检查范围：

```text
最近 5 个提交
最近提交涉及的 deploy/scripts 与 docs 文件
主仓库 deploy/docs 下的敏感关键词
.gitignore 与 deploy/env/.env.prod 跟踪状态
```

确认结果：

```text
deploy/env/.env.prod 未被 git 跟踪
deploy/env/.env.prod 被 .gitignore env/ 规则忽略
当前工作区干净
```

允许出现在仓库中的仅为模板或占位符，例如：

```text
WEBUI_SECRET_KEY=dummy
WEBUI_SECRET_KEY=change-me-to-a-long-random-string
OPENAI_API_KEY=change-me
<Hermes API_SERVER_KEY>
```

不允许提交：

```text
真实 WEBUI_SECRET_KEY
真实 OPENAI_API_KEY / API_SERVER_KEY
GitHub token
Cloudflare token
Let's Encrypt 私钥
任意 *.pem / 私钥块
生产备份包中的 secrets/.env.prod
```

建议每次 push 前执行：

```bash
cd /home/ubuntu/openwebui-custom

git status --short

git grep -n -I -E '(sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]+|BEGIN .*PRIVATE KEY|OPENAI_API_KEY=|API_SERVER_KEY=|WEBUI_SECRET_KEY=|CF_TOKEN=)' -- deploy docs .github 2>/dev/null || true

git check-ignore -v deploy/env/.env.prod

git ls-files deploy/env/.env.prod
```

预期：

```text
git ls-files deploy/env/.env.prod 无输出
敏感扫描只允许出现 dummy/change-me/<...> 这类占位符
```

注意：`deploy/scripts/backup.sh` 会把 `.env.prod` 备份到本机备份包中用于恢复。备份包不得上传到公开仓库或外发。

## 验证命令

查看注册状态：

```bash
cd /home/ubuntu/openwebui-custom
openwebui-ops signup status
```

检查模型授权：

```bash
docker exec open-webui sh -lc "python - <<'PY'
import sqlite3
con=sqlite3.connect('/app/backend/data/webui.db')
print('models:')
for row in con.execute('select id,name,is_active from model'):
    print(row)
print('model grants:')
for row in con.execute(\"select resource_id,principal_type,principal_id,permission from access_grant where resource_type='model'\"):
    print(row)
con.close()
PY"
```

预期包含：

```text
('hermes-agent', 'hermes-agent', 1)
('hermes-agent', 'user', '*', 'read')
```

检查公网健康：

```bash
curl -sS https://openweb.aiclawonline.website/health
```

预期：

```json
{"status":true}
```

## 风险与注意事项

1. 注册不要长期开放，避免垃圾注册和后台管理噪音。
2. 即使默认 `pending`，注册接口长期开放仍会增加公网攻击面。
3. 普通测试用户只给 `user`，不要给 `admin`。
4. 不要开启普通用户 API Keys，除非明确需要。
5. 模型授权使用 `user:* read`，只开放模型使用权，不开放模型管理权。
6. 修改数据库前必须备份；当前脚本已内置备份。
7. Open WebUI 升级后需复查：
   - `ui.enable_signup`
   - `ui.default_user_role`
   - `model` 表
   - `access_grant` 表
   - 普通 user 是否仍能看到 `hermes-agent`

## 最近一次验证状态

```text
时间：2026-05-01
注册：关闭，enable_signup=false
默认新用户角色：pending
用户：cici=user, lyy6100=admin
模型：hermes-agent active
授权：user:* read
容器：open-webui healthy
公网 health：{"status":true}
提交：8fa058222 feat: add Open WebUI ops controller and signup control
```
