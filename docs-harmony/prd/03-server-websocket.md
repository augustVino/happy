# Server WebSocket 改造（最小化）

> **优先级：P0（阻塞鸿蒙客户端通信）**
> **预估：~3 个新文件 + 2 个文件微调，零现有代码重构**

## 为什么需要

| 现状 | 问题 |
|------|------|
| 服务端仅支持 Socket.IO | Socket.IO 有自己的握手协议、心跳、命名空间，不是标准 WebSocket |
| 鸿蒙无 Socket.IO 客户端 | `@ohos.webSocket` 是标准 WebSocket API |
| 不能替换现有 Socket.IO | Web 客户端仍依赖 Socket.IO |

## 设计原则

1. **纯新增** — 不修改任何现有 Socket.IO handler 代码
2. **独立实现** — WebSocket handler 独立于 Socket.IO，不共享抽象
3. **零回归** — 现有 Web 客户端和 CLI daemon 完全不受影响

## 架构

```
                    ┌── Socket.IO 传输层 (现有，不动) ── happy-app (RN/Web)
happy-server ──────┤
                    └── WebSocket 传输层 (新增) ────── happy-harmony (ArkTS)
                         │
                         │  业务逻辑直接调用
                         │  eventRouter / database
                         ▼
                    Server 内部服务（不改动）
```

WebSocket handler 的业务逻辑**直接调用** eventRouter 和数据库操作，不经过 Socket.IO 的 handler 函数。这避免了重构现有代码。

## 具体改动

### 1. 新增 WebSocket 传输层

**新增文件**：`packages/happy-server/sources/app/api/wsTransport.ts`

```typescript
import { WebSocketServer, WebSocket } from 'ws'
import { FastifyInstance } from 'fastify'
import { auth } from '../auth/auth'
import { eventRouter } from '../events/eventRouter'
import { handleWsMessage, handleWsRequest } from './wsHandlers'

interface WsContext {
  userId: string
  clientType: string
  scopeId?: string
}

export function setupWebSocketTransport(fastify: FastifyInstance): WebSocketServer {
  const wss = new WebSocketServer({ noServer: true })

  // HTTP 升级处理
  fastify.server.on('upgrade', (req, socket, head) => {
    if (!req.url?.startsWith('/v1/ws')) return

    const params = new URL(req.url, `http://${req.headers.host}`)
    const token = params.searchParams.get('token')
    const user = auth.verifyTokenSync(token) // 同步验证，复用现有逻辑
    if (!user) {
      socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n')
      socket.destroy()
      return
    }

    const clientType = params.searchParams.get('clientType') ?? 'user-scoped'
    const scopeId = params.searchParams.get('sessionId')
      ?? params.searchParams.get('machineId')

    wss.handleUpgrade(req, socket, head, (ws) => {
      wss.emit('connection', ws, { userId: user.userId, clientType, scopeId })
    })
  })

  // 全局心跳（单一 interval）
  const heartbeatInterval = setInterval(() => {
    wss.clients.forEach((ws) => {
      if (ws.readyState !== WebSocket.OPEN) return
      if (!ws.isAlive) { ws.terminate(); return }
      ws.isAlive = false
      ws.ping()
    })
  }, 25000)
  wss.on('close', () => clearInterval(heartbeatInterval))

  // 消息分发
  wss.on('connection', (ws: WebSocket & { isAlive?: boolean }, ctx: WsContext) => {
    ws.isAlive = true
    ws.on('pong', () => { ws.isAlive = true })

    // 注册到 eventRouter（复用现有路由逻辑）
    const connId = eventRouter.registerConnection(ctx.userId, {
      type: ctx.clientType as any,
      send: (event: string, data: unknown) => {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({ event, data }))
        }
      },
      getUserId: () => ctx.userId,
    })

    ws.on('message', (raw) => {
      try {
        const frame = JSON.parse(raw.toString())

        if (frame.id) {
          // Request 帧 — 需要 ACK
          handleWsRequest(frame.event, frame.id, frame.data, ctx)
            .then((result) => {
              ws.send(JSON.stringify({
                event: `${frame.event}:ack`,
                id: frame.id,
                data: result,
              }))
            })
            .catch((err) => {
              ws.send(JSON.stringify({
                event: `${frame.event}:ack`,
                id: frame.id,
                data: null,
                error: err.message,
              }))
            })
        } else {
          // Push 帧 — fire-and-forget
          handleWsMessage(frame.event, frame.data, ctx)
        }
      } catch (e) {
        ws.send(JSON.stringify({ event: 'error', data: { message: 'Invalid frame' } }))
      }
    })

    ws.on('close', () => {
      eventRouter.unregisterConnection(connId)
    })
  })

  return wss
}
```

### 2. 新增 WebSocket 业务 handler

**新增文件**：`packages/happy-server/sources/app/api/wsHandlers.ts`

```typescript
import { eventRouter } from '../events/eventRouter'
import { db } from '../database'
import { WsContext } from './wsTransport'

// ─── Push handlers (fire-and-forget) ───

export async function handleWsMessage(
  event: string, data: unknown, ctx: WsContext
): Promise<void> {
  switch (event) {
    case 'message':
      // 复用现有的 messageHandler 核心逻辑
      return handleClientMessage(data, ctx)
    default:
      console.warn(`[WS] Unknown push event: ${event}`)
  }
}

// ─── Request handlers (need ACK) ───

export async function handleWsRequest(
  event: string, requestId: string, data: unknown, ctx: WsContext
): Promise<unknown> {
  switch (event) {
    case 'ping':
      return {}
    case 'rpc-call':
      return handleRpcCall(data, ctx)
    case 'update-metadata':
      return handleUpdateMetadata(data, ctx)
    case 'update-state':
      return handleUpdateState(data, ctx)
    case 'access-key-get':
      return handleAccessKeyGet(data, ctx)
    case 'usage-report':
      return handleUsageReport(data, ctx)
    default:
      throw new Error(`Unknown request event: ${event}`)
  }
}

// ─── 具体实现（从现有 socket handlers 复制核心逻辑） ───

async function handleClientMessage(data: any, ctx: WsContext): Promise<void> {
  // 核心逻辑来自 sessionUpdateHandler.handleMessage
  // 验证、持久化、通过 eventRouter 广播
  const { sid, message, localId } = data
  // ... (从现有 handler 复制，约 30 行)
}

async function handleRpcCall(data: any, ctx: WsContext): Promise<any> {
  // 核心逻辑来自 rpcHandler
  // 查找目标 socket，转发请求，等待响应
  const { method, params } = data
  // ... (从现有 handler 复制，约 50 行)
}

async function handleUpdateMetadata(data: any, ctx: WsContext): Promise<any> {
  // 核心逻辑来自 sessionUpdateHandler
  const { sid, metadata, expectedVersion } = data
  // ... (从现有 handler 复制，约 20 行)
}

// ... 其他 handlers 类似
```

### 3. 挂载到 Fastify

**修改文件**：`packages/happy-server/sources/main.ts`

```diff
+ import { setupWebSocketTransport } from './app/api/wsTransport'

// 在 Fastify 启动后
+ setupWebSocketTransport(fastify)
```

### 4. 新增依赖

**修改文件**：`packages/happy-server/package.json`

```diff
+ "ws": "^8.18.0"
```

## 消息帧格式

与 docs-harmony-bat/05-protocol-spec.md 一致：

```typescript
// Push 帧 — fire-and-forget
interface WsPush<T = unknown> {
  event: string
  data: T
}

// Request 帧 — 需要 ACK
interface WsRequest<T = unknown> {
  event: string
  id: string          // correlation ID (cuid2)
  data: T
}

// Response 帧 — ACK
interface WsResponse<T = unknown> {
  event: string       // 格式: `${originalEvent}:ack`
  id: string          // 对应 Request 的 id
  data: T
  error?: string
}
```

## 认证方式

```
ws://server:3000/v1/ws?token=<JWT>&clientType=user-scoped
```

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| token | string | 是 | JWT Bearer Token |
| clientType | string | 是 | `user-scoped`（鸿蒙客户端） |

## 心跳机制

```
客户端                              服务端
  │                                   │
  │──── WebSocket 连接建立 ──────────>│
  │                                   │
  │<──── ws ping 帧 ─────────────────│  (25s 间隔)
  │──── ws pong 帧 ─────────────────>│
  │                                   │
  │      (30s 无 pong → terminate)     │
```

客户端还需发送 `ping` request（10s 超时）：

```json
{ "event": "ping", "id": "clx0ping001", "data": {} }
→ { "event": "ping:ack", "id": "clx0ping001", "data": {} }
```

## RPC 转发机制

鸿蒙客户端通过 WebSocket `rpc-call` 调用 CLI daemon 上的方法。服务端作为中间人转发：

```
鸿蒙客户端                 Server                    CLI daemon
    │                        │                          │
    │ rpc-call {method,      │                          │
    │   id, params}          │                          │
    │───────────────────────>│                          │
    │                        │ emitWithAck              │
    │                        │ rpc-request              │
    │                        │─────────────────────────>│
    │                        │                          │ (执行)
    │                        │<─────────────────────────│
    │                        │     result               │
    │<───────────────────────│                          │
    │ rpc-call:ack {id,      │                          │
    │   data}                │                          │
```

服务端维护 `Map<method, socket>` 注册表。CLI daemon 连接后通过 Socket.IO `rpc-register` 注册方法，WebSocket 客户端通过 `rpc-call` 调用。

## 改动清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `sources/app/api/wsTransport.ts` | 新增 | WebSocket 连接 + JWT 认证 + 消息分发 + 心跳 |
| `sources/app/api/wsHandlers.ts` | 新增 | 业务 handler（从 socket handlers 复制核心逻辑） |
| `sources/main.ts` | 修改 +5 行 | 启动时挂载 WebSocket |
| `package.json` | 修改 +1 行 | 添加 `ws` 依赖 |

## 验证标准

- [ ] 现有 Socket.IO 客户端（Web）功能不受影响
- [ ] 原生 WebSocket 客户端能成功连接 `/v1/ws?token=xxx`
- [ ] 无 token 返回 401
- [ ] Push 事件双向收发正常
- [ ] Request/Response 事件正常（correlation ID 正确传递）
- [ ] RPC 30s 超时正常触发
- [ ] 心跳：全局单一定时器
- [ ] 心跳：连接断开后不产生重复 ping

## 工作量估算

| 步骤 | 预估时间 |
|------|---------|
| wsTransport.ts（连接 + 认证 + 分发） | 0.5 天 |
| wsHandlers.ts（业务 handler 复制） | 1 天 |
| 挂载 + 依赖 + 测试 | 0.5 天 |
| **合计** | **2 天** |
