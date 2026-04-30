# 升级说明

## 上游同步

```bash
git fetch upstream
git checkout main
git merge upstream/main
git push origin main
```

## 合并到 develop

```bash
git checkout develop
git merge main
```

如有冲突，优先保留 upstream 主体，再重新应用本地定制。

## 升级验证

至少验证：

- 构建成功
- 页面可打开
- 登录正常
- 聊天正常
- 流式输出正常
- 模型列表正常
- 历史会话正常
- Provider 接入正常
- usage 显示符合预期
- 反代无异常 4xx/5xx

## 升级原则

1. 先 staging，后 production。
2. 先备份数据，再执行可能涉及迁移的升级。
3. 不在生产直接合并未知改动。
4. 每次生产发布必须保留上一个可回滚版本。
