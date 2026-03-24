# WebSocket 通信协议规范

> 鸿蒙客户端与 Server 之间的完整通信契约

## 连接

### 端点

```
ws://{server}:{port}/v1/ws
```

### 认证

```
ws://server:3000/v1/ws?token=eyJhbGciOiJIUzI1NiIs...&clientType=user-scoped
```

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| token | string | 是 | JWT Bearer Token |
| clientType | string | 是 | 鸿蒙客户端固定 `user-scoped` |

## 消息帧格式

### Push 帧（fire-and-forget）

```typescript
interface WsPush<T = unknown> {
  event: string
  data: T
}
```

```json
{ "event": "message", "data": { "sid": "sess_xxx", "message": { ... } } }
```

### Request 帧（需要 ACK）

```typescript
interface WsRequest<T = unknown> {
  event: string
  id: string          // cuid2 格式，客户端生成
  data: T
}
```

```json
{
  "event": "update-metadata",
  "id": "clx0upd001",
  "data": { "sid": "sess_xxx", "expectedVersion": 5, "metadata": "..." }
}
```

### Response 帧（ACK）

```typescript
interface WsResponse<T = unknown> {
  event: string       // 格式: `${originalEvent}:ack`
  id: string
  data: T
  error?: string      // 有值表示失败
}
```

```json
{
  "event": "update-metadata:ack",
  "id": "clx0upd001",
  "data": { "result": "success", "version": 6, "metadata": "..." }
}
```

## 服务端 → 客户端事件

### Push 事件

#### update — 持久化更新

```json
{
  "event": "update",
  "data": {
    "type": "new-message",
    "seq": 1234,
    "body": { ... }
  }
}
```

**`body.t` 完整取值**（13 种）：

| `body.t` | 说明 | 鸿蒙处理 |
|----------|------|---------|
| `new-message` | 新消息 | 解密 → 入队 → UI 刷新 |
| `new-session` | 新会话 | 重新拉取 sessions 列表 |
| `update-session` | 会话状态变更 | 更新本地 session 数据 |
| `update-account` | 账户变更 | 重新拉取 profile/settings |
| `new-machine` | 新机器注册 | 重新拉取 machines |
| `update-machine` | 机器状态变更 | 更新本地 machine 数据 |
| `new-artifact` | 新产物 | 重新拉取 artifacts |
| `update-artifact` | 产物更新 | 更新本地 artifact |
| `delete-artifact` | 产物删除 | 删除本地 artifact |
| `delete-session` | 会话删除 | 清理本地状态 |
| `relationship-updated` | 好友关系变更 | 重新拉取 friends |
| `new-feed-post` | 新动态 | 追加到 feed |
| `kv-batch-update` | KV 批量更新 | 更新本地 KV |

#### ephemeral — 瞬时事件

```json
{
  "event": "ephemeral",
  "data": {
    "type": "activity",
    "id": "sess_xxx",
    "active": true,
    "activeAt": 1710937200000,
    "thinking": false
  }
}
```

| `type` | 说明 | 鸿蒙处理 |
|--------|------|---------|
| `activity` | 会话活跃状态 | 更新 thinking 指示器 |
| `machine-activity` | 机器在线/离线 | 更新机器在线状态 |
| `usage` | Token 用量 | 更新用量显示 |
| `machine-status` | 机器详细状态 | 更新机器详情 |

#### error — 错误通知

```json
{
  "event": "error",
  "data": { "message": "Authentication failed" }
}
```

## 客户端 → 服务端事件

### Push 事件

#### message — 发送消息

```json
{
  "event": "message",
  "data": {
    "sid": "sess_xxx",
    "message": {
      "content": { "t": "text", "text": "hello" },
      "meta": { "model": "claude-sonnet-4-6" }
    }
  }
}
```

> 注意：也可以通过 REST `POST /v3/sessions/:id/messages` 发送，可靠性更高。

### Request 事件

#### ping — 心跳

请求：`{ "event": "ping", "id": "clx0ping001", "data": {} }`
响应：`{ "event": "ping:ack", "id": "clx0ping001", "data": {} }`
超时：10s

#### rpc-call — RPC 调用

请求：
```json
{
  "event": "rpc-call",
  "id": "clx0rpc001",
  "data": {
    "method": "sess_xxx:spawn-happy-session",
    "params": "base64-encrypted-params"
  }
}
```

响应（成功）：
```json
{
  "event": "rpc-call:ack",
  "id": "clx0rpc001",
  "data": { "ok": true, "result": "..." }
}
```

响应（失败）：
```json
{
  "event": "rpc-call:ack",
  "id": "clx0rpc001",
  "data": null,
  "error": "Target daemon not responding"
}
```

超时：30s

#### update-metadata — 更新会话元数据

```json
{
  "event": "update-metadata",
  "id": "clx0upd001",
  "data": { "sid": "sess_xxx", "expectedVersion": 5, "metadata": "base64-encrypted" }
}
```

响应：`{ "result": "success" | "version-mismatch" | "error", "version": N, "metadata": "..." }`

#### update-state — 更新 Agent 状态

格式同 update-metadata，`data` 中用 `agentState` 替代 `metadata`。

#### access-key-get — 获取访问密钥

请求：`{ "event": "access-key-get", "id": "...", "data": { "sessionId": "...", "machineId": "..." } }`
响应：`{ "ok": true, "accessKey": { ... } }`

#### usage-report — 上报使用量

请求：
```json
{
  "event": "usage-report",
  "id": "...",
  "data": {
    "key": "claude-sonnet-4-6",
    "sessionId": "sess_xxx",
    "tokens": { "total": 1500, "input": 1000, "output": 500 },
    "cost": { "total": 0.015, "input": 0.005, "output": 0.01 }
  }
}
```

响应：`{ "success": true, "reportId": "rpt_xxx", "createdAt": ..., "updatedAt": ... }`

## ACK 事件完整契约表

| 请求事件 | 请求 DTO | 响应事件 | 响应 DTO | 超时 |
|---------|---------|---------|---------|------|
| `ping` | `{}` | `ping:ack` | `{}` | 10s |
| `rpc-call` | `{ method, params }` | `rpc-call:ack` | `{ ok, result?, error? }` | 30s |
| `update-metadata` | `{ sid, expectedVersion, metadata }` | `update-metadata:ack` | `{ result, version, metadata }` | 无 |
| `update-state` | `{ sid, expectedVersion, agentState }` | `update-state:ack` | `{ result, version, agentState }` | 无 |
| `access-key-get` | `{ sessionId, machineId }` | `access-key-get:ack` | `{ ok, accessKey? }` | 无 |
| `usage-report` | `{ key, sessionId, tokens, cost }` | `usage-report:ack` | `{ success, reportId, createdAt, updatedAt }` | 无 |

## 心跳机制

```
客户端                              服务端
  │                                   │
  │──── WebSocket 连接建立 ──────────>│
  │                                   │
  │<──── ws ping 帧 ─────────────────│  (25s 间隔，全局定时器)
  │──── ws pong 帧 ─────────────────>│
  │                                   │
  │      (30s 无 pong → terminate)     │
```

客户端还需发送 `ping` request（10s 超时），超时后断开重连。

## 重连策略

| 重试次数 | 等待时间 |
|---------|---------|
| 1 | 1s |
| 2 | 2s |
| 3 | 4s |
| 4 | 8s |
| 5+ | 30s (最大) |

重连时携带相同的 JWT token。token 过期则跳转登录页。

## 加密消息

消息内容可能为加密形式，客户端根据 `content.t` 判断：

```json
{
  "content": {
    "t": "encrypted",
    "iv": "base64-encoded-iv",
    "data": "base64-encoded-ciphertext"
  }
}
```

解密流程：
1. 用会话的 Data Encryption Key (DEK) 解密
2. DEK 本身用 contentKeyPair 的 Box 加密存储
3. 解密后得到明文 content

## REST API 参考

WebSocket 连接前，需通过 REST API 完成认证和初始数据拉取。

### 认证

```
POST /v1/auth
{
  "publicKey": "base64-encoded-ed25519-public-key",
  "challenge": "base64-encoded-challenge",
  "signature": "base64-encoded-signature"
}
→ { "token": "eyJ...", "user": { "id": "xxx", "publicKey": "xxx" } }
```

### 初始数据拉取

```
GET /v1/sessions          → 会话列表
GET /v1/machines          → 机器列表
GET /v1/account/profile   → 用户资料
GET /v1/artifacts         → Artifact 列表
GET /v1/friends           → 好友列表
GET /v1/kv?prefix=        → KV 存储
```

### 消息

```
GET  /v3/sessions/:id/messages?after_seq=N&limit=100  → 分页消息
POST /v3/sessions/:id/messages                          → 批量发送消息
```

### 批准 CLI 认证

```
POST /v1/auth/response
{ "publicKey": "...", "response": "encrypted-response" }
```

### QR 码恢复

```
POST /v1/auth/account/request   → { "state": "requested" }
POST /v1/auth/account/request   → 轮询直到 { "state": "authorized", "response": "..." }
```
