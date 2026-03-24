# 依赖映射

> Phase 间依赖关系、跨 Phase 共享数据结构与并行开发注意事项

## Phase 依赖关系图

```
Phase 0 (加密 PoC)
    │
    ├──────────────────────────┐
    │                          │
    ▼                          ▼
Phase 1 (Server WS)    Phase 2 (App 骨架)
    │                          │
    └──────────┬───────────────┘
               │
               ▼
         Phase 3 (核心功能)
               │
               ▼
         Phase 4 (功能补全)
               │
               ▼
         Phase 5 (优化打磨)
```

**可并行开发的 Phase**：
- Phase 0 和 Phase 1 完全独立，可同时开发
- Phase 2 依赖 Phase 0 完成
- Phase 3 依赖 Phase 1 + Phase 2 完成

## 各 Phase 依赖明细

### Phase 0: 加密 PoC

**阻塞项**：是（Phase 2-5 全部依赖此 Phase 完成）

**依赖**：无

**输入**：
- happy-cli 的加密实现参考（`packages/happy-cli/encryption.ts`）
- libsodium 源码

**输出**：
- `libsodium.so` — NDK 编译产物
- `SodiumFFI.ets` — FFI 函数定义
- `SodiumCrypto.ets` — 高级加密 API
- `BufferUtils.ets` — Buffer 工具

**验证标准**：
- M0: libsodium 编译成功，FFI 调用正常
- M1: Ed25519 签名与 CLI 输出完全一致
- M2: 能用真实账户登录并拉取会话列表

### Phase 1: Server WebSocket

**阻塞项**：是（Phase 3 依赖此 Phase）

**依赖**：无

**输入**：
- 现有 Socket.IO handler 实现（`packages/happy-server/sources/app/api/socket/`）
- eventRouter 接口（`packages/happy-server/sources/app/events/eventRouter.ts`）

**输出**：
- `wsTransport.ts` — WebSocket 连接 + JWT 认证 + 消息分发 + 心跳
- `wsHandlers.ts` — 业务 handler（从 socket handlers 复制核心逻辑）
- `main.ts` 修改 — +5 行挂载 WebSocket
- `package.json` 修改 — +1 行添加 `ws` 依赖

**验证标准**：
- M3: WebSocket 端点可用，鸿蒙客户端能成功连接

### Phase 2: 鸿蒙 App 骨架 + 认证

**阻塞项**：否

**依赖**：
- Phase 0 完成加密 PoC（M2）
- Phase 1 完成 WebSocket 端点（M3）

**输入**：
- Phase 0 的 `SodiumCrypto.ets`
- happy-app 的认证流程参考
- REST API 端点定义

**输出**：
- `ApiClient.ets` — HTTP 客户端封装
- `AuthService.ets` — 认证服务
- `KeyManager.ets` — 密钥管理
- `SecureStore.ets` — 凭据持久化
- `TokenStore.ets` — JWT 存储
- `IndexPage.ets` — 启动页
- `LoginPage.ets` — 登录/注册页
- `RestorePage.ets` — 恢复账户页

**验证标准**：
- M4: 能创建账户并登录
- M5: 能恢复已有账户（QR 码 + 手动）
- M6: 启动后能自动登录（凭据持久化）

### Phase 3: 核心功能闭环

**阻塞项**：否

**依赖**：
- Phase 1 完成 WebSocket 端点
- Phase 2 完成认证模块

**输入**：
- Phase 1 的 WebSocket 端点
- Phase 2 的认证服务
- happy-wire 的协议类型定义（参考，不直接引用）

**输出**：
- `WsTransport.ets` — WebSocket 传输层
- `WsSender.ets` / `WsReceiver.ets` — 消息收发
- `AckManager.ets` — ACK 管理
- `SyncEngine.ets` — 同步引擎
- `SessionSync.ets` / `MessageSync.ets` / `MachineSync.ets`
- `EncryptionService.ets` — 加密服务
- `SessionEncryption.ets` — 会话加密
- `RpcClient.ets` — RPC 客户端
- `SessionsPage.ets` — 会话列表页
- `ChatPage.ets` — 聊天页
- `NewSessionPage.ets` — 新建会话页

**验证标准**：
- M7: WebSocket 连接正常，能接收实时更新
- M8: 会话列表 + 机器列表正常显示
- M9: 能发送消息并看到 agent 回复（解密正确）
- M10: 权限审批、模式切换正常工作
- M11: 能新建会话（选机器 + 路径）

### Phase 4: 功能补全

**阻塞项**：否

**依赖**：Phase 3 完成 MVP

**输入**：
- Phase 3 的基础架构
- 现有 RN 客户端的功能列表

**输出**：
- P1 功能（核心体验完整）
- P2 功能（增强体验）

**验证标准**：
- M12: P1 功能全部完成
- M13: P2 功能全部完成

### Phase 5: 优化打磨

**阻塞项**：否

**依赖**：Phase 4 完成

**输入**：
- Phase 4 的完整功能集

**输出**：
- 性能优化
- 动画优化
- UI 细节打磨
- 真机测试

**验证标准**：
- M14: 性能指标达标
- M15: 发布 v1.0

## 跨 Phase 共享的数据结构

### 认证相关

```typescript
// Phase 0 生成，Phase 2 使用
interface KeyPair {
  publicKey: Uint8Array    // 32 bytes
  secretKey: Uint8Array    // 32 or 64 bytes (Ed25519 or X25519)
}

// Phase 2 存储持久化
interface Credentials {
  token: string            // JWT
  secretKeyB64: string     // base64url-encoded secret key
}
```

### 加密相关

```typescript
// Phase 0 实现，Phase 2-5 使用
interface DataEncryptionKey {
  version: 1               // 固定为 1
  ephemeralPublicKey: Uint8Array  // 32 bytes
  nonce: Uint8Array        // 24 bytes
  ciphertext: Uint8Array   // encrypted DEK
}

// Phase 3 使用
interface SessionEncryptionContext {
  dek: Uint8Array          // 32 bytes Data Encryption Key
  version: number          // 1 for AES-256-GCM, 0 for SecretBox
}
```

### 协议相关

```typescript
// 所有 Phase 共享（自维护）
interface WsPush<T = unknown> {
  event: string
  data: T
}

interface WsRequest<T = unknown> {
  event: string
  id: string              // cuid2
  data: T
}

interface WsResponse<T = unknown> {
  event: string           // `${originalEvent}:ack`
  id: string
  data: T
  error?: string
}
```

### 状态相关

```typescript
// Phase 3 开始使用
interface SessionState {
  id: string
  seq: number
  metadata: string | null
  metadataVersion: number
  agentState: string | null
  agentStateVersion: number
  active: boolean
  lastActiveAt: number
}

// Phase 3 开始使用
interface MessageState {
  id: string
  seq: number
  content: SessionMessageContent
  localId: string | null
  createdAt: number
  updatedAt: number
}
```

## 并行开发注意事项

### Phase 0 和 Phase 1 可并行

- 两者完全独立，无数据共享
- 可同时由不同开发者开发
- 接口契约在 PRD 中已明确

### Phase 2 必须等待 Phase 0

- 认证模块依赖 Ed25519 签名
- 密钥推导依赖 crypto_box

**对齐点**：
- Phase 0 的 M2 完成后，Phase 2 才能开始
- `SodiumCrypto.ets` 的 API 必须稳定

### Phase 3 必须等待 Phase 1 + Phase 2

- WebSocket 连接需要 Server 端点可用
- 认证成功后才能初始化同步

**对齐点**：
- Phase 1 的 M3 完成后，WebSocket 连接才能建立
- Phase 2 的 M6 完成后，才能有有效的 JWT token

### 接口对齐检查点

| 检查点 | Phase 0 | Phase 1 | Phase 2 | Phase 3 |
|--------|---------|---------|---------|---------|
| M0 | ✅ | - | - | - |
| M1 | ✅ | - | - | - |
| M2 | ✅ | - | ✅ | - |
| M3 | - | ✅ | ✅ | ✅ |
| M4 | - | - | ✅ | - |
| M5 | - | - | ✅ | - |
| M6 | - | - | ✅ | - |
| M7 | - | ✅ | - | ✅ |
| M8 | - | - | - | ✅ |
| M9 | - | - | ✅ | ✅ |
| M10 | - | - | - | ✅ |
| M11 | - | ✅ | ✅ | ✅ |

## 数据流向图

```
┌─────────────────────────────────────────────────────────────┐
│                    Phase 2: 认证                            │
│  生成密钥 → 签名 challenge → 获取 JWT → 存储凭据             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼ (JWT token)
┌─────────────────────────────────────────────────────────────┐
│              Phase 1: WebSocket + Phase 3: 同步              │
│  建立 WebSocket → 初始数据拉取 → 实时更新同步                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼ (加密数据)
┌─────────────────────────────────────────────────────────────┐
│                    Phase 0: 加密                            │
│  解密 DEK → 解密消息/状态 → UI 渲染                          │
└─────────────────────────────────────────────────────────────┘
```

## 工作量估算与时间线

| Phase | 工作量 | 累计 | 可并行 |
|-------|--------|------|--------|
| Phase 0 | 3 天 | 3 天 | 与 Phase 1 |
| Phase 1 | 2 天 | 2 天 | 与 Phase 0 |
| Phase 2 | 5 天 | 10 天 | 等待 Phase 0 |
| Phase 3 | 10 天 | 20 天 | 等待 Phase 1 + Phase 2 |
| Phase 4 | 10 天 | 30 天 | 等待 Phase 3 |
| Phase 5 | 5 天 | 35 天 | 等待 Phase 4 |

**最短时间线**（Phase 0 + Phase 1 并行）：
- 第 1-2 天：Phase 0 + Phase 1 并行
- 第 3-5 天：Phase 2
- 第 6-15 天：Phase 3
- 第 16-25 天：Phase 4
- 第 26-30 天：Phase 5

**总计**：~30 个工作日（约 6 周）
