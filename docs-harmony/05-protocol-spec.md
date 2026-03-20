# WebSocket 通信协议规范

> 鸿蒙客户端专用，与 Socket.IO 共享同一套业务逻辑

## 连接

### 端点

```
ws://{server}:{port}/v1/ws
```

### 认证

通过 URL query 参数传递 JWT token：

```
ws://server:3000/v1/ws?token=eyJhbGciOiJIUzI1NiIs...&clientType=user-scoped
```

### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| token | string | 是 | JWT Bearer Token |
| clientType | string | 是 | 连接作用域，见下表 |

### clientType 取值

| 值 | 说明 | 鸿蒙客户端使用 |
|----|------|---------------|
| `user-scoped` | 用户级连接，接收所有更新 | **是** |
| `session-scoped` | 会话级连接（需传 sessionId） | 否 |
| `machine-scoped` | 机器级连接（需传 machineId） | 否 |

### session-scoped / machine-scoped 额外参数

| 参数 | 类型 | 说明 |
|------|------|------|
| sessionId | string | 会话 ID（session-scoped 时必填） |
| machineId | string | 机器 ID（machine-scoped 时必填） |

## 消息帧格式

所有消息均为标准 JSON 文本帧：

```typescript
interface WsFrame<T = unknown> {
  event: string
  data: T
}
```

## 服务端 -> 客户端事件

### update

持久化更新事件（消息/会话/机器状态变更）。

```json
{
  "event": "update",
  "data": {
    "type": "new-message" | "update-session" | "update-machine",
    "seq": 1234,
    "body": { ... }
  }
}
```

#### new-message

```json
{
  "event": "update",
  "data": {
    "type": "new-message",
    "seq": 1234,
    "body": {
      "id": "msg_xxx",
      "sessionId": "sess_xxx",
      "role": "user" | "agent",
      "content": { ... },
      "createdAt": "2026-03-20T12:00:00.000Z",
      "meta": {
        "model": "claude-sonnet-4-6",
        "permissionMode": "default"
      }
    }
  }
}
```

#### update-session

```json
{
  "event": "update",
  "data": {
    "type": "update-session",
    "seq": 1235,
    "body": {
      "id": "sess_xxx",
      "metadata": { ... },
      "agentState": { ... }
    }
  }
}
```

#### update-machine

```json
{
  "event": "update",
  "data": {
    "type": "update-machine",
    "seq": 1236,
    "body": {
      "id": "mach_xxx",
      "daemonState": "running" | "stopped",
      "metadata": { ... }
    }
  }
}
```

### ephemeral

临时事件（不持久化，用于 UI 状态更新）。

```json
{
  "event": "ephemeral",
  "data": {
    "type": "session-active",
    "id": "sess_xxx",
    "active": true,
    "activeAt": "2026-03-20T12:00:00.000Z",
    "thinking": false
  }
}
```

### rpc-request

RPC 请求（服务端请求客户端执行操作）。

```json
{
  "event": "rpc-request",
  "data": {
    "method": "sess_xxx:spawn-happy-session",
    "params": { ... }
  }
}
```

### error

错误消息。

```json
{
  "event": "error",
  "data": {
    "message": "Authentication failed"
  }
}
```

## 客户端 -> 服务端事件

### message

发送消息到指定会话。

```json
{
  "event": "message",
  "data": {
    "sid": "sess_xxx",
    "message": {
      "content": { ... },
      "meta": {
        "model": "claude-sonnet-4-6"
      }
    }
  }
}
```

### session-alive

心跳 / 存活信号。

```json
{
  "event": "session-alive",
  "data": {
    "sid": "sess_xxx",
    "time": "2026-03-20T12:00:00.000Z",
    "thinking": false,
    "mode": "claude"
  }
}
```

### session-end

标记会话结束。

```json
{
  "event": "session-end",
  "data": {
    "sid": "sess_xxx",
    "time": "2026-03-20T12:00:00.000Z"
  }
}
```

### update-metadata

更新会话元数据（乐观锁，需传 expectedVersion）。

```json
{
  "event": "update-metadata",
  "data": {
    "sid": "sess_xxx",
    "expectedVersion": 5,
    "metadata": {
      "title": "New Title"
    }
  }
}
```

### update-state

更新 agent 状态（乐观锁）。

```json
{
  "event": "update-state",
  "data": {
    "sid": "sess_xxx",
    "expectedVersion": 5,
    "agentState": {
      "status": "idle"
    }
  }
}
```

### usage-report

上报使用量。

```json
{
  "event": "usage-report",
  "data": {
    "key": "claude-sonnet-4-6",
    "sessionId": "sess_xxx",
    "tokens": 1500,
    "cost": 0.015
  }
}
```

## 心跳机制

```
客户端                          服务端
  │                               │
  │──── WebSocket 连接建立 ───────>│
  │                               │
  │<──── ping ────────────────────│  (每 25s)
  │──── pong ────────────────────>│
  │                               │
  │      (30s 无 pong → 断开)      │
```

服务端每 25 秒发送 ping 帧，客户端需回复 pong 帧。超过 30 秒未收到 pong 则断开连接。

## 重连策略

客户端断线后使用指数退避重连：

| 重试次数 | 等待时间 |
|---------|---------|
| 1 | 1s |
| 2 | 2s |
| 3 | 4s |
| 4 | 8s |
| 5+ | 30s (最大) |

重连时携带相同的 JWT token。如果 token 过期，需重新走认证流程获取新 token。

## 加密消息

消息内容可能为加密形式，客户端需根据 `content.t` 字段判断：

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
1. 用会话的 data encryption key 解密
2. data encryption key 本身用服务端公钥加密存储
3. 解密后得到明文 content

## REST API 参考

WebSocket 连接建立前，需通过 REST API 完成认证和初始数据拉取。

### 认证

```
POST /v1/auth
Content-Type: application/json

{
  "publicKey": "base64-encoded-ed25519-public-key",
  "challenge": "base64-encoded-challenge",
  "signature": "base64-encoded-signature"
}

Response:
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "user": { "id": "xxx", "publicKey": "xxx" }
}
```

### 初始数据拉取

```
GET /v1/sessions
Authorization: Bearer <token>

GET /v1/machines
Authorization: Bearer <token>

GET /v1/account/profile
Authorization: Bearer <token>
```

### 完整 API 端点列表

见 `packages/happy-server/sources/app/api/routes/` 目录下各路由文件。
