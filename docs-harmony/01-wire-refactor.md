# Phase 1: happy-wire 重构方案

> 优先级：**P0（阻塞后续所有工作）**
> 预估改动：~10 个文件，小型重构

## 目标

将 happy-wire 从"RN/Web/CLI 共享的 JS 类型包"升级为"所有客户端共享的协议定义包"，为鸿蒙客户端提供可消费的类型定义。

## 当前问题

### 问题 1：Socket.IO 类型未共享

`ServerToClientEvents` / `ClientToServerEvents` 仅在 happy-cli `src/api/types.ts` 中定义，happy-app 和 happy-server 各自独立处理。鸿蒙客户端无法获取统一的协议类型。

**当前定义位置**：
- `packages/happy-cli/src/api/types.ts` — Socket.IO 事件类型
- `packages/happy-app/sources/sync/apiTypes.ts` — 仅导入 happy-wire 的 Schema
- `packages/happy-server/sources/app/api/socket.ts` — 独立实现事件处理

### 问题 2：MessageMeta 重复定义

`MessageMetaSchema` 在两处独立定义：
- `packages/happy-wire/src/messageMeta.ts`
- `packages/happy-cli/src/api/types.ts`

内容一致但独立维护，容易产生不一致。

### 问题 3：无法供非 JS 环境消费

happy-wire 基于 Zod（JS 运行时），ArkTS 无法直接使用。需要导出语言无关的 JSON Schema。

## 具体改动

### 1. 将 Socket.IO 类型移入 happy-wire

**新增文件**：`packages/happy-wire/src/socketEvents.ts`

```typescript
// 从 happy-cli/src/api/types.ts 提取，移入 happy-wire

// Server -> Client 事件
export const ServerToClientEventsSchema = {
  update: CoreUpdateContainerSchema,           // 持久化更新
  ephemeral: EphemeralEventSchema,             // 临时事件
  'rpc-request': RpcRequestSchema,             // RPC 请求
  'rpc-registered': RpcRegisteredSchema,       // RPC 注册确认
  'rpc-unregistered': RpcUnregisteredSchema,   // RPC 注销确认
  'rpc-error': RpcErrorSchema,                 // RPC 错误
  error: ErrorEventSchema,                     // 错误消息
}

// Client -> Server 事件
export const ClientToServerEventsSchema = {
  message: MessageEventSchema,                 // 发送消息
  'session-alive': SessionAliveSchema,         // 心跳
  'session-end': SessionEndSchema,             // 会话结束
  'update-metadata': UpdateMetadataSchema,     // 更新元数据
  'update-state': UpdateStateSchema,           // 更新状态
  ping: z.void(),                              // 心跳
  'rpc-register': RpcRegisterSchema,           // 注册 RPC
  'rpc-unregister': RpcUnregisterSchema,       // 注销 RPC
  'rpc-call': RpcCallSchema,                   // 调用 RPC
  'usage-report': UsageReportSchema,           // 使用量报告
}
```

**同步更新**：
- `packages/happy-cli/src/api/types.ts` — 改为从 happy-wire 导入
- `packages/happy-app/sources/sync/apiTypes.ts` — 改为从 happy-wire 导入
- `packages/happy-server/sources/app/api/socket.ts` — 改为从 happy-wire 导入事件类型

### 2. 消除 MessageMeta 重复定义

**改动**：
- 删除 `packages/happy-cli/src/api/types.ts` 中的 `MessageMetaSchema`
- 改为从 `@slopus/happy-wire` 导入

### 3. 导出 JSON Schema

**新增文件**：`packages/happy-wire/src/jsonSchema.ts`

```typescript
import { z } from 'zod'
import { zodToJsonSchema } from 'zod-to-json-schema'

// 将所有 Zod Schema 转为 JSON Schema，供 ArkTS 等非 JS 环境使用
export const wireJsonSchemas = {
  SessionMessage: zodToJsonSchema(SessionMessageSchema),
  CoreUpdateContainer: zodToJsonSchema(CoreUpdateContainerSchema),
  UpdateNewMessage: zodToJsonSchema(UpdateNewMessageBodySchema),
  UpdateSession: zodToJsonSchema(UpdateSessionBodySchema),
  UpdateMachine: zodToJsonSchema(UpdateMachineBodySchema),
  MessageMeta: zodToJsonSchema(MessageMetaSchema),
  ServerToClientEvents: /* 事件级 JSON Schema */,
  ClientToServerEvents: /* 事件级 JSON Schema */,
}
```

**新增构建脚本**：`packages/happy-wire/scripts/export-json-schema.ts`

```bash
# 构建时自动导出 JSON Schema 文件
yarn build:schema  # 输出到 packages/happy-wire/dist/schemas/
```

输出示例 `dist/schemas/SessionMessage.json`：
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "id": { "type": "string" },
    "content": { ... },
    "meta": { "$ref": "MessageMeta.json" }
  }
}
```

### 4. 新增依赖

`packages/happy-wire/package.json`：
```diff
+ "zod-to-json-schema": "^3.24.0"
```

## 改动清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `happy-wire/src/socketEvents.ts` | 新增 | Socket.IO 事件类型定义 |
| `happy-wire/src/jsonSchema.ts` | 新增 | JSON Schema 导出 |
| `happy-wire/scripts/export-json-schema.ts` | 新增 | 构建脚本 |
| `happy-wire/package.json` | 修改 | 新增 zod-to-json-schema 依赖 + build:schema 脚本 |
| `happy-wire/src/index.ts` | 修改 | 导出新增模块 |
| `happy-cli/src/api/types.ts` | 修改 | 删除重复定义，改为从 happy-wire 导入 |
| `happy-app/sources/sync/apiTypes.ts` | 修改 | 改为从 happy-wire 导入事件类型 |
| `happy-server/sources/app/api/socket.ts` | 修改 | 改为从 happy-wire 导入事件类型 |

## 验证标准

- [ ] happy-wire 导出所有 Socket.IO 事件类型
- [ ] happy-cli / happy-app / happy-server 从 happy-wire 导入事件类型（无重复定义）
- [ ] `yarn build:schema` 成功生成 JSON Schema 文件
- [ ] 现有客户端（RN/Web）功能不受影响（回归测试）
- [ ] JSON Schema 可被标准 JSON Schema 验证器解析
