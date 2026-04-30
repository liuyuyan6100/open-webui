# Provider 接入策略

## 目标

支持多个模型后端，同时避免把各 Provider 的差异扩散到 UI 和核心业务逻辑。

## 接入原则

1. 优先使用 OpenAI Compatible API。
2. Provider 差异收口到 adapter / gateway 层。
3. 不在前端硬编码 Provider 私有字段。
4. usage 统计必须标记来源。

## usage 结构

建议统一成：

```json
{
  "prompt_tokens": 123,
  "completion_tokens": 456,
  "total_tokens": 579,
  "usage_source": "actual",
  "provider": "openai",
  "model": "gpt-4o-mini"
}
```

usage_source 可选值：

- actual：Provider 真实返回
- estimated：本地估算
- unavailable：不可用

## 风险

不要把 estimated 当成精确计费依据。
不同 Provider 的 token 口径可能不同。
