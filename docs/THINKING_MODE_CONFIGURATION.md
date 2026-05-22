# DeerFlow 思考模式配置说明

> 本文档记录 DeerFlow 四种思考模式（闪速、思考、Pro、Ultra）的配置、转换逻辑和请求参数组合。

---

## 一、模式概述

DeerFlow 前端提供四种思考模式，通过组合 `thinking_enabled`、`reasoning_effort`、`is_plan_mode`、`subagent_enabled` 参数实现不同程度的功能：

| 模式 | 中文名 | 特点 |
|------|--------|------|
| **Flash** | 闪速 | 快速响应，不开启思考，适合简单任务 |
| **Reasoning** | 思考 | 开启基础思考，低推理深度，平衡速度与准确性 |
| **Pro** | 专业 | 开启思考 + 计划模式，中等推理深度，适合复杂任务 |
| **Ultra** | 极致 | 全功能开启（思考 + 计划 + 子代理），高推理深度，能力最强 |

---

## 二、前端转换逻辑

前端 `hooks.ts` 中 `sendMessage` 函数将用户选择的模式转换为后端参数：

```typescript
// frontend/src/core/threads/hooks.ts:367-385
context: {
  ...extraContext,
  ...context,
  thinking_enabled: context.mode !== "flash",
  is_plan_mode: context.mode === "pro" || context.mode === "ultra",
  subagent_enabled: context.mode === "ultra",
  reasoning_effort:
    context.reasoning_effort ??
    (context.mode === "ultra"
      ? "high"
      : context.mode === "pro"
        ? "medium"
        : context.mode === "thinking"
          ? "low"
          : undefined),
  thread_id: threadId,
}
```

### 模式 → 参数映射表

| 前端模式 | `thinking_enabled` | `reasoning_effort` | `is_plan_mode` | `subagent_enabled` |
|----------|:------------------:|:------------------:|:--------------:|:------------------:|
| Flash | `false` | `undefined` → `minimal` | `false` | `false` |
| Reasoning | `true` | `"low"` | `false` | `false` |
| Pro | `true` | `"medium"` | `true` | `false` |
| Ultra | `true` | `"high"` | `true` | `true` |

---

## 三、后端处理逻辑

后端 `factory.py` 中 `create_chat_model` 函数处理这些参数：

```python
# backend/packages/harness/deerflow/models/factory.py

# 1. 当 thinking_enabled=True 且模型支持思考
if thinking_enabled and has_thinking_settings:
    model_settings_from_config.update(effective_wte)
    # 合入 {"extra_body": {"thinking": {"type": "enabled"}}}

# 2. 当 thinking_enabled=False
if not thinking_enabled and has_thinking_settings:
    if effective_wte.get("extra_body", {}).get("thinking", {}).get("type"):
        kwargs.update({"extra_body": {"thinking": {"type": "disabled"}}})
        kwargs.update({"reasoning_effort": "minimal"})
    elif effective_wte.get("thinking", {}).get("type"):
        kwargs.update({"thinking": {"type": "disabled"}})

# 3. 如果模型不支持 reasoning_effort，删除该参数
if not model_config.supports_reasoning_effort and "reasoning_effort" in kwargs:
    del kwargs["reasoning_effort"]
```

### 关键字段说明

| 字段 | 来源 | 说明 |
|------|------|------|
| `supports_thinking` | config.yaml | 声明模型是否支持思考模式 |
| `supports_reasoning_effort` | config.yaml | 声明模型是否支持推理深度参数 |
| `when_thinking_enabled` | config.yaml | 思考开启时的额外参数配置 |
| `thinking.type` | API 请求 | 控制是否开启思考 (`enabled`/`disabled`/`auto`) |
| `reasoning_effort` | API 请求 | 控制思考深度 (`minimal`/`low`/`medium`/`high`) |

---

## 四、最终请求参数组合

经过前端 → 后端转换后，发送到模型 API 的参数组合：

| 模式 | thinking.type | reasoning_effort | is_plan_mode | subagent_enabled | 完整请求参数 |
|------|---------------|------------------|:------------:|:----------------:|--------------|
| **闪速** | `disabled` | `minimal` | `false` | `false` | `{"extra_body": {"thinking": {"type": "disabled"}}, "reasoning_effort": "minimal"}` |
| **思考** | `enabled` | `low` | `false` | `false` | `{"extra_body": {"thinking": {"type": "enabled"}}, "reasoning_effort": "low"}` |
| **Pro** | `enabled` | `medium` | `true` | `false` | `{"extra_body": {"thinking": {"type": "enabled"}}, "reasoning_effort": "medium"}` |
| **Ultra** | `enabled` | `high` | `true` | `true` | `{"extra_body": {"thinking": {"type": "enabled"}}, "reasoning_effort": "high"}` |

---

## 五、配置示例

### config.yaml 模型配置

```yaml
models:
  - name: Doubao-Seed-2.0-pro
    display_name: Doubao Seed 2.0 Pro
    use: deerflow.models.patched_deepseek:PatchedChatDeepSeek
    model: doubao-seed-2.0-pro
    api_base: https://ark.cn-beijing.volces.com/api/coding/v3
    api_key: $VOLCENGINE_API_KEY          # 使用环境变量
    supports_thinking: true               # 必须设置，否则前端不显示思考模式选项
    supports_reasoning_effort: true       # 必须设置，否则前端不显示推理深度选项
    supports_vision: true
    when_thinking_enabled:
      extra_body:
        thinking:
          type: enabled                   # 思考开启时的默认配置
```

### .env 环境变量

```bash
VOLCENGINE_API_KEY=your-api-key-here
```

---

## 六、验证结果

通过 Python 测试验证转换逻辑正确性：

```python
# 测试结果
=== thinking_enabled=True ===
合并结果: {'reasoning_effort': 'high', 'model': 'doubao-seed-2.0-pro', 
           'extra_body': {'thinking': {'type': 'enabled'}}}

=== thinking_enabled=False ===
合并结果: {'reasoning_effort': 'minimal', 'model': 'doubao-seed-2.0-pro', 
           'extra_body': {'thinking': {'type': 'disabled'}}}
```

| 模式 | thinking.type | reasoning_effort | 组合正确 |
|------|:-------------:|:----------------:|:--------:|
| 闪速 | `disabled` | `minimal` | ✓ |
| 思考 | `enabled` | `low` | ✓ |
| Pro | `enabled` | `medium` | ✓ |
| Ultra | `enabled` | `high` | ✓ |

---

## 七、火山引擎 Doubao API 说明

### API 端点

```
https://ark.cn-beijing.volces.com/api/coding/v3
```

### 参数配合使用

火山引擎 Doubao Seed 2.0 系列 API 需要以下参数配合：

- **`thinking.type`**: 控制是否开启思考模式
  - `enabled` - 强制开启
  - `disabled` - 关闭
  - `auto` - 自动判断

- **`reasoning_effort`**: 控制思考深度（当 thinking 开启时生效）
  - `minimal` - 最浅，快速响应
  - `low` - 浅层推演
  - `medium` - 多层逻辑分析
  - `high` - 全维度逻辑推演 + 多路径验证

### 模型字段继承

`PatchedChatDeepSeek` 继承 `langchain_deepseek.ChatDeepSeek`，支持以下字段：

```python
# ChatDeepSeek 支持的字段
dict_keys(['reasoning_effort', 'reasoning', 'extra_body', ...])
```

---

## 八、常见问题

### Q1: 前端不显示思考/推理深度选项

**原因**: `config.yaml` 中缺少以下配置：
```yaml
supports_thinking: true
supports_reasoning_effort: true
```

**解决**: 在模型配置中添加上述字段。

### Q2: API 返回错误 "thinking not supported"

**原因**: 模型不支持思考模式，但配置了 `supports_thinking: true`。

**解决**: 检查模型文档确认是否支持，或移除该配置。

### Q3: thinking.type 未生效

**原因**: 后端判断逻辑中 `supports_reasoning_effort` 为 false 时会删除 reasoning_effort 参数。

**解决**: 确保 `supports_reasoning_effort: true` 已配置。

---

## 九、相关文件

| 文件 | 说明 |
|------|------|
| `frontend/src/core/threads/hooks.ts` | 前端模式转换逻辑 |
| `frontend/src/components/workspace/input-box.tsx` | 模式选择 UI |
| `backend/packages/harness/deerflow/models/factory.py` | 后端模型创建和参数处理 |
| `backend/packages/harness/deerflow/config/model_config.py` | 模型配置 Schema 定义 |
| `backend/packages/harness/deerflow/models/patched_deepseek.py` | DeepSeek/Doubao 模型适配 |

---

*文档生成时间: 2026-04-20*