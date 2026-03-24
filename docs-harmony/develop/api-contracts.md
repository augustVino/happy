# API 契约文档

> 完整的 HTTP API 端点清单、WebSocket 消息类型与数据模型定义

## REST API 端点清单

### 认证 (Auth)

#### POST /v1/auth — 创建账户/登录

```typescript
// Request
interface AuthRequest {
  publicKey: string      // base64-encoded Ed25519 public key
  challenge: string      // base64-encoded challenge
  signature: string      // base64-encoded signature
}

// Response
interface AuthResponse {
  success: true
  token: string          // JWT Bearer Token
}
```

#### POST /v1/auth/request — CLI 认证请求

```typescript
// Request
interface AuthRequestRequest {
  publicKey: string      // base64-encoded X25519 public key
  supportsV2?: boolean
}

// Response (pending)
interface AuthRequestPending {
  state: 'requested'
}

// Response (authorized)
interface AuthRequestAuthorized {
  state: 'authorized'
  token: string
  response: string       // 加密的 secret
}
```

#### GET /v1/auth/request/status — 查询认证请求状态

```typescript
// Request
interface AuthRequestStatusQuery {
  publicKey: string
}

// Response
interface AuthRequestStatusResponse {
  status: 'not_found' | 'pending' | 'authorized'
  supportsV2: boolean
}
```

#### POST /v1/auth/response — 批准 CLI 认证

```typescript
// Request
interface AuthResponseRequest {
  publicKey: string
  response: string       // 加密的 response
}

// Response
interface AuthResponseResponse {
  success: true
}
```

#### POST /v1/auth/account/request — 账户恢复请求（QR 码）

```typescript
// Request
interface AccountAuthRequestRequest {
  publicKey: string      // 临时 X25519 公钥
}

// Response (pending)
interface AccountAuthRequestPending {
  state: 'requested'
}

// Response (authorized)
interface AccountAuthRequestAuthorized {
  state: 'authorized'
  token: string
  response: string       // 加密的 master secret
}
```

### 会话 (Sessions)

#### GET /v1/sessions — 获取会话列表

```typescript
// Response
interface SessionsResponse {
  sessions: SessionItem[]
}

interface SessionItem {
  id: string
  seq: number
  createdAt: number
  updatedAt: number
  active: boolean
  activeAt: number
  metadata: string | null              // 加密的元数据
  metadataVersion: number
  agentState: string | null            // 加密的 Agent 状态
  agentStateVersion: number
  dataEncryptionKey: string | null     // base64-encoded DEK bundle
  lastMessage: null
}
```

#### GET /v2/sessions — 游标分页会话列表

```typescript
// Query
interface SessionsV2Query {
  cursor?: string       // cursor_v1_xxx
  limit?: number        // default: 50, max: 200
  changedSince?: number // timestamp
}

// Response
interface SessionsV2Response {
  sessions: SessionItem[]
  nextCursor: string | null
  hasNext: boolean
}
```

#### POST /v1/sessions — 创建或加载会话

```typescript
// Request
interface CreateSessionRequest {
  tag: string
  metadata: string                 // 加密的元数据
  agentState?: string              // 加密的 Agent 状态
  dataEncryptionKey?: string       // base64-encoded DEK
}

// Response
interface CreateSessionResponse {
  session: SessionItem
}
```

#### DELETE /v1/sessions/:sessionId — 删除会话

```typescript
// Response
interface DeleteSessionResponse {
  success: true
}
```

### 消息 (Messages)

#### GET /v1/sessions/:sessionId/messages — 获取会话消息（旧版）

```typescript
// Response
interface MessagesResponse {
  messages: MessageItem[]
}

interface MessageItem {
  id: string
  seq: number
  content: SessionMessageContent
  localId: string | null
  createdAt: number
  updatedAt: number
}

interface SessionMessageContent {
  c: string             // base64-encoded ciphertext
  t: 'encrypted'
}
```

#### GET /v3/sessions/:sessionId/messages — 分页获取消息（新版）

```typescript
// Query
interface MessagesV3Query {
  after_seq?: number    // default: 0
  limit?: number        // default: 100, max: 500
}

// Response
interface MessagesV3Response {
  messages: MessageItem[]
  hasMore: boolean
}
```

#### POST /v3/sessions/:sessionId/messages — 批量发送消息

```typescript
// Request
interface SendMessagesRequest {
  messages: Array<{
    content: string     // base64-encoded ciphertext
    localId: string
  }>
}

// Response
interface SendMessagesResponse {
  messages: Array<{
    id: string
    seq: number
    localId: string | null
    createdAt: number
    updatedAt: number
  }>
}
```

### 机器 (Machines)

#### GET /v1/machines — 获取机器列表

```typescript
// Response
interface MachinesResponse {
  machines: MachineItem[]
}

interface MachineItem {
  id: string
  metadata: string                 // 加密的元数据
  metadataVersion: number
  daemonState: string | null       // 加密的 daemon 状态
  daemonStateVersion: number
  dataEncryptionKey: string | null // base64-encoded DEK bundle
  seq: number
  active: boolean
  activeAt: number
  createdAt: number
  updatedAt: number
}
```

#### GET /v1/machines/:id — 获取单个机器

```typescript
// Response
interface MachineResponse {
  machine: MachineItem
}
```

#### POST /v1/machines — 创建或加载机器

```typescript
// Request
interface CreateMachineRequest {
  id: string
  metadata: string                 // 加密的元数据
  daemonState?: string             // 加密的 daemon 状态
  dataEncryptionKey?: string       // base64-encoded DEK bundle
}

// Response
interface CreateMachineResponse {
  machine: MachineItem
}
```

### Artifact

#### GET /v1/artifacts — 获取 Artifact 列表

```typescript
// Response
interface ArtifactsResponse {
  artifacts: ArtifactHeader[]
}

interface ArtifactHeader {
  id: string
  header: string                  // base64-encoded encrypted header
  headerVersion: number
  dataEncryptionKey: string       // base64-encoded DEK bundle
  seq: number
  createdAt: number
  updatedAt: number
}
```

#### GET /v1/artifacts/:id — 获取 Artifact 详情

```typescript
// Response
interface ArtifactResponse {
  id: string
  header: string                  // base64-encoded encrypted header
  headerVersion: number
  body: string                    // base64-encoded encrypted body
  bodyVersion: number
  dataEncryptionKey: string       // base64-encoded DEK bundle
  seq: number
  createdAt: number
  updatedAt: number
}
```

#### POST /v1/artifacts — 创建 Artifact

```typescript
// Request
interface CreateArtifactRequest {
  id: string                      // UUID
  header: string                  // base64-encoded encrypted header
  body: string                    // base64-encoded encrypted body
  dataEncryptionKey: string       // base64-encoded DEK bundle
}

// Response
interface CreateArtifactResponse {
  id: string
  header: string
  headerVersion: number
  body: string
  bodyVersion: number
  dataEncryptionKey: string
  seq: number
  createdAt: number
  updatedAt: number
}
```

#### POST /v1/artifacts/:id — 更新 Artifact（版本控制）

```typescript
// Request
interface UpdateArtifactRequest {
  header?: string
  expectedHeaderVersion?: number
  body?: string
  expectedBodyVersion?: number
}

// Response (success)
interface UpdateArtifactSuccess {
  success: true
  headerVersion?: number
  bodyVersion?: number
}

// Response (version mismatch)
interface UpdateArtifactMismatch {
  success: false
  error: 'version-mismatch'
  currentHeaderVersion?: number
  currentBodyVersion?: number
  currentHeader?: string
  currentBody?: string
}
```

#### DELETE /v1/artifacts/:id — 删除 Artifact

```typescript
// Response
interface DeleteArtifactResponse {
  success: true
}
```

## WebSocket 消息类型清单

### 服务端推送事件

| 事件名称 | 方向 | 说明 |
|---------|------|------|
| `update` | S→C | 持久化更新（13 种类型） |
| `ephemeral` | S→C | 瞬时事件（4 种类型） |
| `error` | S→C | 错误通知 |
| `message` | C→S | 发送消息（Push） |
| `ping` | C→S | 心跳请求 |
| `ping:ack` | S→C | 心跳响应 |
| `rpc-call` | C→S | RPC 调用请求 |
| `rpc-call:ack` | S→C | RPC 调用响应 |
| `update-metadata` | C→S | 更新会话元数据 |
| `update-metadata:ack` | S→C | 更新元数据响应 |
| `update-state` | C→S | 更新 Agent 状态 |
| `update-state:ack` | S→C | 更新状态响应 |
| `access-key-get` | C→S | 获取访问密钥 |
| `access-key-get:ack` | S→C | 获取密钥响应 |
| `usage-report` | C→S | 上报使用量 |
| `usage-report:ack` | S→C | 上报使用量响应 |

## 数据模型定义

### SessionEnvelope（会话事件）

```typescript
interface SessionEnvelope {
  id: string                // cuid2
  time: number              // 毫秒时间戳
  role: 'user' | 'agent'
  turn?: string
  subagent?: string         // cuid2
  ev: SessionEvent
}

type SessionEvent =
  | TextEvent
  | ServiceEvent
  | ToolCallStartEvent
  | ToolCallEndEvent
  | FileEvent
  | TurnStartEvent
  | StartEvent
  | TurnEndEvent
  | StopEvent

interface TextEvent {
  t: 'text'
  text: string
  thinking?: boolean
}

interface ServiceEvent {
  t: 'service'
  text: string
}

interface ToolCallStartEvent {
  t: 'tool-call-start'
  call: string
  name: string
  title: string
  description: string
  args: Record<string, unknown>
}

interface ToolCallEndEvent {
  t: 'tool-call-end'
  call: string
}

interface FileEvent {
  t: 'file'
  ref: string
  name: string
  size: number
  image?: {
    width: number
    height: number
    thumbhash: string
  }
}

interface TurnStartEvent {
  t: 'turn-start'
}

interface StartEvent {
  t: 'start'
  title?: string
}

interface TurnEndEvent {
  t: 'turn-end'
  status: 'completed' | 'failed' | 'cancelled'
}

interface StopEvent {
  t: 'stop'
}
```

### UpdatePayload（持久化更新）

```typescript
interface UpdatePayload {
  id: string
  seq: number
  body: {
    t: UpdateType
    [key: string]: any
  }
  createdAt: number
}

type UpdateType =
  | 'new-message'
  | 'new-session'
  | 'update-session'
  | 'update-account'
  | 'new-machine'
  | 'update-machine'
  | 'new-artifact'
  | 'update-artifact'
  | 'delete-artifact'
  | 'delete-session'
  | 'relationship-updated'
  | 'new-feed-post'
  | 'kv-batch-update'
```

### EphemeralPayload（瞬时事件）

```typescript
interface EphemeralPayload {
  type: EphemeralType
  [key: string]: any
}

type EphemeralType =
  | 'activity'
  | 'machine-activity'
  | 'usage'
  | 'machine-status'
```

## 各 Phase 开发者需要实现的接口定义

### Phase 2: 鸿蒙 App 骨架 + 认证

| 优先级 | 接口 | 说明 |
|--------|------|------|
| P0 | POST /v1/auth | 创建账户/登录 |
| P0 | POST /v1/auth/account/request | 账户恢复请求 |
| P0 | POST /v1/auth/response | 批准 CLI 认证 |

### Phase 3: 核心功能闭环

| 优先级 | 接口 | 说明 |
|--------|------|------|
| P0 | GET /v1/sessions | 会话列表 |
| P0 | GET /v3/sessions/:id/messages | 分页消息 |
| P0 | POST /v3/sessions/:id/messages | 批量发送消息 |
| P0 | GET /v1/machines | 机器列表 |
| P0 | WebSocket 连接 | 实时更新 |
| P0 | RPC 方法 | 会话级 + 机器级 |

### Phase 4: 功能补全

| 优先级 | 接口 | 说明 |
|--------|------|------|
| P1 | DELETE /v1/sessions/:id | 删除会话 |
| P1 | GET/POST/DELETE /v1/artifacts | Artifact 管理 |
| P1 | GET/POST /v1/friends | 好友系统 |
| P1 | POST /v1/usage/query | 使用量统计 |
| P2 | GET/POST /v1/feed | Feed 动态 |
