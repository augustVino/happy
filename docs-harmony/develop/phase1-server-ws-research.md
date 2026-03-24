# Phase 1: Server WebSocket 传输层研究文档

> **任务**: 为鸿蒙客户端提供独立的 WebSocket 通道，保持现有 Socket.IO 端不受影响
> **状态**: 准备工作中，等待 Task #7（架构设计）完成

---

## 一、现有 Socket.IO 实现

### 1.1 启动流程

**入口**: `packages/happy-server/sources/main.ts`

```typescript
// main.ts
await startApi();  // 启动 HTTP + Socket.IO
```

**API 启动**: `packages/happy-server/sources/app/api/api.ts`

```typescript
// Socket.IO 在 HTTP 启动后挂载
startSocket(typed);  // 启动 Socket.IO
```

### 1.2 Socket.IO 配置

**文件**: `packages/happy-server/sources/app/api/socket.ts`

```typescript
const io = new Server(app.server, {
    cors: { origin: "*", methods: ["GET", "POST", "OPTIONS"], credentials: true, allowedHeaders: ["*"] },
    transports: ['websocket', 'polling'],
    pingTimeout: 45000,
    pingInterval: 15000,
    path: '/v1/updates',           // Socket.IO 路径
    serveClient: false
});
```

**关键发现**:
- 现有 Socket.IO 路径: `/v1/updates`
- 新 WebSocket 将使用 `/v1/ws`
- 两者可以共存，互不干扰

### 1.3 认证机制

**流程**:
1. 客户端连接时在 handshake auth 中传递 token
2. 服务端通过 `auth.verifyToken(token)` 验证 JWT
3. 验证成功后建立连接

**文件**: `packages/happy-server/sources/app/api/socket.ts`

```typescript
socket.on('connection', async (socket) => {
    const token = socket.handshake.auth.token as string;
    const clientType = socket.handshake.auth.clientType as 'session-scoped' | 'user-scoped' | 'machine-scoped';
    const sessionId = socket.handshake.auth.sessionId as string | undefined;
    const machineId = socket.handshake.auth.machineId as string | undefined;

    const verified = await auth.verifyToken(token);
    if (!verified) {
        socket.emit('error', { message: 'Invalid authentication token' });
        socket.disconnect();
        return;
    }

    const userId = verified.userId;
    // ... 继续处理
});
```

**认证模块**: `packages/happy-server/sources/app/auth/auth.ts`

```typescript
class AuthModule {
    async verifyToken(token: string): Promise<{ userId: string; extras?: any } | null> {
        // 1. 检查缓存
        const cached = this.tokenCache.get(token);
        if (cached) return { userId: cached.userId, extras: cached.extras };

        // 2. 验证 token
        const verified = await this.tokens.verifier.verify(token);
        if (!verified) return null;

        return { userId: verified.user as string, extras: verified.extras };
    }
}
```

### 1.4 连接类型

| 类型 | 说明 | 额外参数 |
|------|------|---------|
| `user-scoped` | 用户级连接（移动/Web 客户端） | 无 |
| `session-scoped` | 会话级连接（CLI daemon） | `sessionId` |
| `machine-scoped` | 机器级连接（CLI daemon） | `machineId` |

鸿蒙客户端将使用 `user-scoped` 类型。

### 1.5 现有消息处理器

| Handler | 文件 | 事件 |
|---------|------|------|
| `pingHandler` | socket/pingHandler.ts | `ping` |
| `rpcHandler` | socket/rpcHandler.ts | `rpc-register`, `rpc-unregister`, `rpc-call`, `rpc-request` |
| `sessionUpdateHandler` | socket/sessionUpdateHandler.ts | `update-metadata`, `update-state`, `session-alive`, `message`, `session-end` |
| `machineUpdateHandler` | socket/machineUpdateHandler.ts | `update-machine-metadata`, `update-machine-daemon-state` |
| `artifactUpdateHandler` | socket/artifactUpdateHandler.ts | `update-artifact-header`, `update-artifact-body` |
| `accessKeyHandler` | socket/accessKeyHandler.ts | `access-key-get` |
| `usageHandler` | socket/usageHandler.ts | `usage-report` |

### 1.6 事件路由系统

**文件**: `packages/happy-server/sources/app/events/eventRouter.ts`

```typescript
class EventRouter {
    private userConnections = new Map<string, Set<ClientConnection>>();

    // 添加连接
    addConnection(userId: string, connection: ClientConnection): void;

    // 移除连接
    removeConnection(userId: string, connection: ClientConnection): void;

    // 发送持久化更新
    emitUpdate(params: { userId, payload, recipientFilter?, skipSenderConnection? }): void;

    // 发送瞬时事件
    emitEphemeral(params: { userId, payload, recipientFilter?, skipSenderConnection? }): void;
}
```

**接收者过滤器**:
- `all-interested-in-session`: 所有对该会话感兴趣的连接（session-scoped + user-scoped）
- `user-scoped-only`: 仅 user-scoped 连接
- `machine-scoped-only`: user-scoped + 特定 machine-scoped
- `all-user-authenticated-connections`: 所有连接类型

---

## 二、happy-wire 类型映射

### 2.1 消息类型

**文件**: `packages/happy-wire/src/messages.ts`

```typescript
// 会话事件
export const sessionEventSchema = z.discriminatedUnion('t', [
  sessionTextEventSchema,          // { t: 'text', text, thinking? }
  sessionServiceMessageEventSchema, // { t: 'service', text }
  sessionToolCallStartEventSchema,  // { t: 'tool-call-start', call, name, title, description, args }
  sessionToolCallEndEventSchema,    // { t: 'tool-call-end', call }
  sessionFileEventSchema,           // { t: 'file', ref, name, size, image? }
  sessionTurnStartEventSchema,      // { t: 'turn-start' }
  sessionStartEventSchema,          // { t: 'start', title? }
  sessionTurnEndEventSchema,        // { t: 'turn-end', status }
  sessionStopEventSchema,           // { t: 'stop' }
]);

// 会话信封
export const sessionEnvelopeSchema = z.object({
  id: z.string(),
  time: z.number(),
  role: z.enum(['user', 'agent']),
  turn: z.string().optional(),
  subagent: z.string().optional(),
  ev: sessionEventSchema,
});
```

### 2.2 协议消息

**文件**: `packages/happy-wire/src/messages.ts`

```typescript
// 会话协议消息
export const SessionProtocolMessageSchema = z.object({
  role: z.literal('session'),
  content: sessionEnvelopeSchema,
  meta: MessageMetaSchema.optional(),
});

// 消息内容（联合类型）
export const MessageContentSchema = z.discriminatedUnion('role', [
  UserMessageSchema,           // { role: 'user', content: { type: 'text', text }, meta? }
  AgentMessageSchema,          // { role: 'agent', content: { type, ... }, meta? }
  SessionProtocolMessageSchema // { role: 'session', content: SessionEnvelope, meta? }
]);

// 消息
export const SessionMessageSchema = z.object({
  id: z.string(),
  seq: z.number(),
  localId: z.string().nullish(),
  content: SessionMessageContentSchema, // { t: 'encrypted', c: string }
  createdAt: z.number(),
  updatedAt: z.number(),
});
```

### 2.3 更新事件

```typescript
// 新消息
export const UpdateNewMessageBodySchema = z.object({
  t: z.literal('new-message'),
  sid: z.string(),
  message: SessionMessageSchema,
});

// 会话更新
export const UpdateSessionBodySchema = z.object({
  t: z.literal('update-session'),
  id: z.string(),
  metadata: VersionedEncryptedValueSchema.nullish(),
  agentState: VersionedNullableEncryptedValueSchema.nullish(),
});

// 机器更新
export const UpdateMachineBodySchema = z.object({
  t: z.literal('update-machine'),
  machineId: z.string(),
  metadata: VersionedMachineEncryptedValueSchema.nullish(),
  daemonState: VersionedMachineEncryptedValueSchema.nullish(),
  active: z.boolean().optional(),
  activeAt: z.number().optional(),
});

// 联合类型
export const CoreUpdateBodySchema = z.discriminatedUnion('t', [
  UpdateNewMessageBodySchema,
  UpdateSessionBodySchema,
  UpdateMachineBodySchema,
  // ... 其他类型
]);
```

---

## 三、WebSocket 传输层设计方案

### 3.1 技术选型: ws 库

**选择理由**:
1. 纯 WebSocket 实现，无 Socket.IO 开销
2. 与现有 Socket.IO 可共存（不同路径）
3. 轻量级，API 简洁
4. 与鸿蒙 `@ohos.webSocket` 兼容

**安装**:
```bash
yarn add ws
yarn add -D @types/ws
```

### 3.2 连接端点设计

```
ws://server:3000/v1/ws?token=JWT&clientType=user-scoped
```

**参数映射**:
- Socket.IO: `socket.handshake.auth.token` → WebSocket: URL query param `token`
- Socket.IO: `socket.handshake.auth.clientType` → WebSocket: URL query param `clientType`

### 3.3 消息帧格式

**Push 帧**（服务端 → 客户端，fire-and-forget）:
```typescript
interface WsPush<T = unknown> {
  event: string;   // 'update', 'ephemeral', 'error'
  data: T;
}
```

**Request 帧**（客户端 → 服务端，需要 ACK）:
```typescript
interface WsRequest<T = unknown> {
  event: string;   // 'ping', 'rpc-call', 'update-metadata', etc.
  id: string;      // cuid2，客户端生成
  data: T;
}
```

**Response 帧**（服务端 → 客户端，ACK）:
```typescript
interface WsResponse<T = unknown> {
  event: string;   // '${originalEvent}:ack'
  id: string;      // 原始请求的 id
  data: T;
  error?: string;  // 有值表示失败
}
```

### 3.4 与现有 Socket.IO 共存策略

```typescript
// api.ts
export async function startApi() {
    // ... HTTP setup

    // Routes
    authRoutes(typed);
    // ... 其他 HTTP 路由

    // Start HTTP
    await app.listen({ port, host: '0.0.0.0' });

    // Start Socket.IO (现有)
    startSocket(typed);

    // Start WebSocket (新增) - 使用不同的路径
    startWebSocket(typed);  // 新增
}
```

**路径分配**:
- Socket.IO: `/v1/updates` (Socket.IO namespace)
- WebSocket: `/v1/ws` (纯 WebSocket)

### 3.5 认证流程设计

```typescript
// wsTransport.ts (新增)
import { WebSocketServer, WebSocket } from 'ws';
import { IncomingMessage } from 'http';

export function startWebSocket(app: Fastify) {
    const wss = new WebSocketServer({
        noServer: true,  // 手动升级
        path: '/v1/ws'
    });

    // 手动升级 HTTP 连接
    app.server.on('upgrade', (request: IncomingMessage, socket, head) => {
        const { pathname } = new URL(request.url || '', `http://${request.headers.host}`);

        if (pathname === '/v1/ws') {
            wss.handleUpgrade(request, socket, head, (ws) => {
                wss.emit('connection', ws, request);
            });
        }
    });

    // 连接处理
    wss.on('connection', async (ws: WebSocket, request: IncomingMessage) => {
        // 从 URL query 获取认证参数
        const url = new URL(request.url || '', `http://${request.headers.host}`);
        const token = url.searchParams.get('token');
        const clientType = url.searchParams.get('clientType') || 'user-scoped';

        if (!token) {
            ws.send(JSON.stringify({ event: 'error', data: { message: 'Missing token' } }));
            ws.close();
            return;
        }

        // 复用现有认证
        const verified = await auth.verifyToken(token);
        if (!verified) {
            ws.send(JSON.stringify({ event: 'error', data: { message: 'Invalid token' } }));
            ws.close();
            return;
        }

        const userId = verified.userId;

        // 创建连接对象（与 Socket.IO 兼容）
        const connection: ClientConnection = {
            connectionType: 'user-scoped',
            socket: adaptWebSocketToSocketIO(ws),  // 适配层
            userId
        };

        eventRouter.addConnection(userId, connection);

        // ... 消息处理
    });
}
```

### 3.6 WebSocket → Socket.IO 适配层

由于 `eventRouter` 期望 `Socket` 类型，需要适配：

```typescript
// wsAdapters.ts
interface WsAdapterSocket {
    emit: (event: string, data: any) => void;
    on: (event: string, handler: Function) => void;
    off: (event: string, handler: Function) => void;
    connected: boolean;
    id: string;
    disconnect: () => void;
}

function adaptWebSocketToSocketIO(ws: WebSocket): WsAdapterSocket {
    const handlers = new Map<string, Function>();

    ws.on('message', (data: Buffer) => {
        try {
            const frame = JSON.parse(data.toString('utf-8'));
            const handler = handlers.get(frame.event);
            if (handler) {
                handler(frame.data, (response: any) => {
                    // ACK callback
                    ws.send(JSON.stringify({
                        event: `${frame.event}:ack`,
                        id: frame.id,
                        data: response
                    }));
                });
            }
        } catch (error) {
            // 忽略解析错误
        }
    });

    return {
        emit: (event: string, data: any) => {
            if (ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({ event, data }));
            }
        },
        on: (event: string, handler: Function) => {
            handlers.set(event, handler);
        },
        off: (event: string) => {
            handlers.delete(event);
        },
        get connected() {
            return ws.readyState === WebSocket.OPEN;
        },
        id: `ws_${Math.random().toString(36).slice(2)}`,
        disconnect: () => ws.close()
    };
}
```

### 3.7 心跳机制

```typescript
// wsHandlers.ts (新增)
export function wsPingHandler(ws: WebSocket) {
    ws.on('message', (data: Buffer) => {
        try {
            const frame = JSON.parse(data.toString('utf-8'));

            if (frame.event === 'ping') {
                ws.send(JSON.stringify({
                    event: 'ping:ack',
                    id: frame.id,
                    data: {}
                }));
            }
        } catch (error) {
            // 忽略
        }
    });
}
```

### 3.8 RPC 调用支持

```typescript
// wsHandlers.ts (新增)
export function wsRpcHandler(
    userId: string,
    ws: WebSocket,
    connection: ClientConnection,
    rpcListeners: Map<string, WsAdapterSocket>
) {
    ws.on('message', (data: Buffer) => {
        try {
            const frame = JSON.parse(data.toString('utf-8'));

            if (frame.event === 'rpc-call') {
                const { method, params } = frame.data;
                const targetSocket = rpcListeners.get(method);

                if (!targetSocket || !targetSocket.connected) {
                    sendAck(ws, 'rpc-call', frame.id, {
                        ok: false,
                        error: 'RPC method not available'
                    });
                    return;
                }

                // 转发 RPC 请求（复用现有逻辑）
                targetSocket.emit('rpc-request', { method, params }, (response: any) => {
                    sendAck(ws, 'rpc-call', frame.id, {
                        ok: true,
                        result: response
                    });
                });
            }
        } catch (error) {
            // 忽略
        }
    });
}

function sendAck(ws: WebSocket, event: string, id: string, data: any) {
    ws.send(JSON.stringify({
        event: `${event}:ack`,
        id,
        data
    }));
}
```

---

## 四、实现计划

### 4.1 新增文件

| 文件 | 说明 | 预估行数 |
|------|------|---------|
| `app/api/wsTransport.ts` | WebSocket 服务端主逻辑 | 150 |
| `app/api/wsHandlers.ts` | WebSocket 消息处理器 | 200 |
| `app/api/wsAdapters.ts` | WebSocket → Socket.IO 适配层 | 100 |

### 4.2 修改文件

| 文件 | 修改内容 |
|------|---------|
| `app/api/api.ts` | 添加 `startWebSocket(typed)` 调用 |
| `package.json` | 添加 `ws` 和 `@types/ws` 依赖 |

### 4.3 实现步骤

1. **安装依赖**: `yarn add ws @types/ws`
2. **创建适配层**: `wsAdapters.ts` - WebSocket 适配到 Socket.IO 接口
3. **实现传输层**: `wsTransport.ts` - WebSocket 服务器、认证、连接管理
4. **实现处理器**: `wsHandlers.ts` - ping、rpc-call、message、update-metadata 等
5. **挂载到 API**: `api.ts` - 启动 WebSocket 服务器
6. **验证**: 用最小客户端脚本测试连接、心跳、消息、RPC

### 4.4 测试计划

```typescript
// test-websocket.ts
import WebSocket from 'ws';

const ws = new WebSocket('ws://localhost:3000/v1/ws?token=JWT&clientType=user-scoped');

ws.on('open', () => {
    console.log('Connected');

    // 测试 ping
    ws.send(JSON.stringify({
        event: 'ping',
        id: 'test001',
        data: {}
    }));
});

ws.on('message', (data) => {
    const frame = JSON.parse(data.toString('utf-8'));
    console.log('Received:', frame);
});

// 预期输出: { event: 'ping:ack', id: 'test001', data: {} }
```

---

## 五、风险与降级

### 5.1 风险

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| ws 与 Socket.IO 路径冲突 | 连接失败 | 使用不同路径 (`/v1/ws` vs `/v1/updates`) |
| eventRouter 不兼容 | 消息分发失败 | 实现适配层 `wsAdapters.ts` |
| 现有 Socket.IO 被影响 | Web/RN 客户端异常 | 完全独立新增，不修改现有代码 |

### 5.2 回退方案

如果 WebSocket 实现遇到问题：
1. 保留 Socket.IO 作为备选方案
2. 鸿蒙客户端可以临时使用 Socket.IO 客户端库（如果有）
3. 或者仅通过 REST API + 轮询实现功能（性能下降）

---

## 六、依赖关系

### 6.1 阻塞依赖

- **Task #7: 架构设计与协议对齐** - 需要确认消息帧格式、ACK 机制、RPC 协议

### 6.2 被依赖

- **Task #3: Phase 2: 鸿蒙客户端骨架 + 认证** - 需要 WebSocket 端点才能测试认证
- **Task #6: Phase 3: 核心功能闭环** - 需要稳定的 WebSocket 通信

---

## 七、后续步骤

等待 Task #7 完成后：
1. 确认协议帧格式（`docs-harmony/prd/05-protocol-spec.md`）
2. 确认 RPC 调用协议（`docs-harmony/prd/07-core-flows.md`）
3. 开始实际编码实现
4. 用最小客户端脚本验证
5. 确保现有 Socket.IO 不受影响（回归测试）
