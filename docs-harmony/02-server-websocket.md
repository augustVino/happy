# Phase 2: happy-server WebSocket 适配方案

> 优先级：**P0（阻塞鸿蒙客户端开发）**
> 预估改动：~5 个新文件 + 3 个修改文件，中等改动

## 目标

在现有 Socket.IO 传输层之外，新增原生 WebSocket 传输层，使鸿蒙客户端能通过标准 WebSocket 协议与服务端通信。

## 为什么需要这个改动

| 现状 | 问题 |
|------|------|
| 服务端仅支持 Socket.IO | Socket.IO 有自己的握手协议、心跳机制、命名空间，不是标准 WebSocket |
| 鸿蒙无 Socket.IO 客户端 | `@ohos.webSocket` 是标准 WebSocket API，无法直接连接 Socket.IO 服务 |
| 不能替换现有 Socket.IO | RN/Web 客户端依赖 Socket.IO，不能破坏现有功能 |

## 架构设计

### 双传输层

```
                    ┌── Socket.IO 传输层 (现有) ── happy-app (RN/Web)
happy-server ──────┤
                    └── WebSocket 传输层 (新增) ── happy-harmony (ArkTS)
```

### 消息格式

WebSocket 传输层使用标准 JSON 文本帧，格式与 Socket.IO 事件保持一致：

```typescript
// 通用消息帧
interface WsFrame<T = unknown> {
  event: string        // 事件名，如 "update", "message"
  data: T              // 事件数据
  id?: string          // 消息 ID（用于确认）
}

// 示例：服务端推送更新
{
  "event": "update",
  "data": {
    "type": "new-message",
    "body": { ... }
  }
}

// 示例：客户端发送消息
{
  "event": "message",
  "data": {
    "sid": "session-xxx",
    "message": { ... }
  }
}
```

### 认证方式

复用现有 JWT 认证，通过 WebSocket 连接的 URL query 参数传递：

```
ws://server:port/v1/ws?token=<JWT>&clientType=user-scoped
```

## 具体改动

### 1. 新增 WebSocket 传输层

**新增文件**：`packages/happy-server/sources/app/api/wsTransport.ts`

```typescript
import { WebSocketServer, WebSocket } from 'ws'
import { FastifyInstance } from 'fastify'

// WebSocket 传输层 — 与 Socket.IO 共享业务逻辑
export function setupWebSocketTransport(
  fastify: FastifyInstance,
  sharedHandlers: SharedHandlers
) {
  const wss = new WebSocketServer({ noServer: true })

  // HTTP 升级处理
  fastify.server.on('upgrade', (req, socket, head) => {
    if (req.url?.startsWith('/v1/ws')) {
      // JWT 认证
      const token = new URL(req.url, 'http://localhost').searchParams.get('token')
      const user = verifyToken(token)
      if (!user) { socket.destroy(); return }

      wss.handleUpgrade(req, socket, head, (ws) => {
        wss.emit('connection', ws, req, user)
      })
    }
  })

  // 消息分发
  wss.on('connection', (ws, req, user) => {
    ws.on('message', (raw) => {
      const frame = JSON.parse(raw.toString())
      // 路由到共享的 handler
      sharedHandlers.handleClientEvent(ws, frame.event, frame.data, user)
    })
  })

  return wss
}
```

### 2. 提取共享业务逻辑

**核心思路**：将 Socket.IO handler 中的纯业务逻辑提取为平台无关函数，Socket.IO 和 WebSocket 两套传输层共享。

**新增文件**：`packages/happy-server/sources/app/api/sharedHandlers.ts`

```typescript
// 共享 handler — 不依赖任何传输层
export class SharedHandlers {
  constructor(
    private deps: {
      db: Database
      eventbus: EventBus
      // ...其他依赖
    }
  ) {}

  // 处理客户端消息（平台无关）
  async handleClientEvent(
    sender: MessageSender,  // 统一发送接口
    event: string,
    data: unknown,
    user: AuthUser
  ) {
    switch (event) {
      case 'message':
        return this.handleMessage(sender, data, user)
      case 'session-alive':
        return this.handleSessionAlive(sender, data, user)
      case 'update-metadata':
        return this.handleUpdateMetadata(sender, data, user)
      // ... 其他事件
    }
  }

  // 向客户端推送更新（平台无关）
  pushUpdate(sender: MessageSender, update: CoreUpdateContainer) {
    sender.send('update', update)
  }
}

// 统一发送接口 — Socket.IO 和 WebSocket 都实现这个接口
interface MessageSender {
  send(event: string, data: unknown): void
  getClientType(): string
  getUserId(): string
}
```

### 3. 适配现有 Socket.IO handler

**修改文件**：`packages/happy-server/sources/app/api/socket.ts`

将现有 Socket.IO handler 改为调用 SharedHandlers，而非直接处理业务逻辑。

```typescript
// 改造前：Socket.IO 直接处理业务
io.on('connection', (socket) => {
  socket.on('message', (data) => {
    // 直接写业务逻辑...
  })
})

// 改造后：Socket.IO 转发到 SharedHandlers
io.on('connection', (socket) => {
  const sender: MessageSender = {
    send: (event, data) => socket.emit(event, data),
    getClientType: () => socket.data.clientType,
    getUserId: () => socket.data.userId,
  }
  socket.on('message', (data) => {
    sharedHandlers.handleClientEvent(sender, 'message', data, socket.data.user)
  })
})
```

### 4. 适配心跳机制

Socket.IO 有内置心跳，原生 WebSocket 需要自行实现：

```typescript
// wsTransport.ts
ws.on('connection', (ws, req, user) => {
  // 心跳：客户端每 25s 发 ping，服务端回 pong
  ws.isAlive = true
  ws.on('pong', () => { ws.isAlive = true })

  const interval = setInterval(() => {
    wss.clients.forEach((client) => {
      if (!client.isAlive) return client.terminate()
      client.isAlive = false
      client.ping()
    })
  }, 25000)

  ws.on('close', () => clearInterval(interval))
})
```

### 5. 华为推送（可选，Phase 4）

**新增文件**：`packages/happy-server/sources/modules/push/huaweiPush.ts`

```typescript
// 华为 Push Kit 集成
export class HuaweiPushService {
  async sendPushToken(userId: string, token: string) {
    // 存储 Huawei Push Token（类似现有的 FCM/APNs token）
  }

  async sendNotification(userId: string, title: string, body: string) {
    // 通过华为 Push Kit 发送推送
    // POST https://push.hicloud.com/v2/{appId}/messages:send
  }
}
```

## 新增依赖

`packages/happy-server/package.json`：
```diff
+ "ws": "^8.18.0"
```

> `ws` 是 Node.js 最成熟的 WebSocket 库，Socket.IO 底层也使用它。

## 改动清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `sources/app/api/wsTransport.ts` | 新增 | WebSocket 传输层 |
| `sources/app/api/sharedHandlers.ts` | 新增 | 共享业务逻辑（平台无关） |
| `sources/app/api/wsSender.ts` | 新增 | WebSocket 的 MessageSender 实现 |
| `sources/modules/push/huaweiPush.ts` | 新增 | 华为推送（Phase 4） |
| `sources/app/api/socket.ts` | 修改 | 重构为调用 SharedHandlers |
| `sources/app/api/socket/*.ts` | 修改 | 各 handler 改为接收 MessageSender 参数 |
| `package.json` | 修改 | 新增 ws 依赖 |
| `sources/main.ts` | 修改 | 启动时初始化 WebSocket 传输层 |

## 验证标准

- [ ] 现有 Socket.IO 客户端（RN/Web）功能不受影响
- [ ] 原生 WebSocket 客户端能成功连接 `/v1/ws?token=xxx`
- [ ] JWT 认证正常工作
- [ ] 双向消息收发正常（客户端 -> 服务端、服务端 -> 客户端）
- [ ] 心跳保活正常，断线重连正常
- [ ] Socket.IO 和 WebSocket 两套传输共享同一套业务逻辑
- [ ] 无 token 或 token 无效时连接被拒绝

## 协议对比

| 特性 | Socket.IO (现有) | WebSocket (新增) |
|------|-----------------|-----------------|
| 连接路径 | `/v1/updates` | `/v1/ws?token=xxx` |
| 认证方式 | `handshake.auth.token` | URL query `token` |
| 消息格式 | Socket.IO 帧协议 | 标准 JSON 文本帧 |
| 心跳 | 内置（25s 间隔） | 自实现（ping/pong） |
| 重连 | 内置自动重连 | 客户端自行实现 |
| 命名空间 | 支持 | 不支持（用路径区分） |
| 回退 | 支持 polling 回退 | 无回退 |
| 适用客户端 | RN/Web (iOS/Android) | ArkTS (鸿蒙) |
