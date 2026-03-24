# 架构决策文档

> 鸿蒙客户端 `packages/happy-harmony` 的模块分层设计、职责边界与技术选型

## 架构原则

1. **不重构现有代码** — happy-wire、happy-cli、happy-app、happy-server 保持不变
2. **服务端纯新增** — WebSocket 传输层和处理器独立实现
3. **自维护协议** — 鸿蒙客户端内自维护协议定义，避免跨包耦合
4. **函数式风格** — 避免类，偏好函数和声明式模式
5. **小型文件** — 200-400 行典型，800 行上限

## 模块分层设计

```
┌─────────────────────────────────────────────────────────────┐
│                        UI (ui/)                              │
│  — 页面 (pages/)                                             │
│  — 组件 (components/)                                        │
│  — ViewModel (viewmodel/)                                    │
│  — 主题 (theme/)                                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    业务层 (auth/ | sync/ | rpc/)              │
│  — auth/     认证、密钥管理                                   │
│  — sync/     数据同步引擎                                     │
│  — rpc/      RPC 调用客户端                                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  网络层 (network/)                           │
│  — api/           REST API 客户端                             │
│  — websocket/    WebSocket 传输层                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              加密层 (encryption/ + common/crypto/)            │
│  — libsodium FFI 封装                                        │
│  — 端到端加密服务                                             │
└─────────────────────────────────────────────────────────────┘
```

## 包与模块的职责边界

### 1. common/ — 公共工具模块

| 子模块 | 职责 | 边界 |
|--------|------|------|
| constants/ | 服务端地址、API 路径、应用级常量 | 不含业务逻辑 |
| utils/ | 日志、Base64/Hex 编解码、时间格式化 | 无外部依赖 |
| crypto/ | libsodium FFI 函数定义、高级加密封装 | 不含协议逻辑 |
| types/ | 协议类型定义（自维护） | 不引用 happy-wire |

**关键文件**：
- `SodiumFFI.ets` — FFI 函数签名定义
- `SodiumCrypto.ets` — 高级加密 API（签名、Box、SecretBox、随机数）
- `WireTypes.ets` — 协议类型定义（与 happy-wire 对齐，但不直接引用）
- `WsFrames.ets` — WebSocket 帧类型定义

### 2. network/ — 网络通信模块

| 子模块 | 职责 | 边界 |
|--------|------|------|
| api/ | REST API 客户端封装 | 不含加密逻辑 |
| websocket/ | WebSocket 连接、心跳、重连、ACK 管理 | 不含业务逻辑 |

**关键文件**：
- `ApiClient.ets` — HTTP 客户端封装（@ohos.net.http）
- `WsTransport.ets` — WebSocket 连接管理
- `WsSender.ets` — 消息发送
- `WsReceiver.ets` — 消息接收与分发
- `WsHeartbeat.ets` — 心跳管理
- `AckManager.ets` — ACK 等待与超时管理

### 3. auth/ — 认证模块

| 文件 | 职责 | 依赖 |
|------|------|------|
| `KeyManager.ets` | 密钥生成/存储/恢复 | common/crypto/, SecureStore |
| `AuthService.ets` | 认证服务（challenge-response） | network/api/, common/crypto/ |
| `AuthApproveService.ets` | 批准 CLI 认证 | network/api/ |
| `TokenStore.ets` | JWT Token 存储 | @ohos.data.preferences |
| `SecretKeyBackup.ets` | 密钥备份（QR 码生成） | common/crypto/ |

### 4. sync/ — 数据同步模块

| 文件 | 职责 | 依赖 |
|------|------|------|
| `SyncEngine.ets` | 同步引擎核心 | network/api/, network/websocket/, encryption/ |
| `SessionSync.ets` | 会话同步 | SyncEngine.ets |
| `MachineSync.ets` | 机器同步 | SyncEngine.ets |
| `MessageSync.ets` | 消息同步 | SyncEngine.ets |
| `ArtifactSync.ets` | Artifact 同步 | SyncEngine.ets |
| `FriendSync.ets` | 好友同步 | SyncEngine.ets |
| `KvSync.ets` | KV 同步 | SyncEngine.ets |

### 5. encryption/ — 端到端加密模块

| 文件 | 职责 | 依赖 |
|------|------|------|
| `EncryptionService.ets` | 加密服务统一入口 | common/crypto/ |
| `KeyDerivation.ets` | 密钥推导（deriveKey + box keypair） | common/crypto/ |
| `DataKeyManager.ets` | DEK 管理 | common/crypto/ |
| `SessionEncryption.ets` | 会话级加密/解密 | common/crypto/ |
| `MachineEncryption.ets` | 机器级加密/解密 | common/crypto/ |
| `SecureStore.ets` | 凭据持久化 | @ohos.data.relationalStore |

### 6. rpc/ — RPC 调用模块

| 文件 | 职责 | 依赖 |
|------|------|------|
| `RpcClient.ets` | RPC 调用客户端框架 | network/websocket/, encryption/ |
| `SessionRpc.ets` | 会话级 RPC（abort/allow/deny/bash 等） | RpcClient.ets |
| `MachineRpc.ets` | 机器级 RPC（spawn/stop） | RpcClient.ets |

### 7. ui/ — UI 模块

| 子模块 | 职责 | 技术选型 |
|--------|------|---------|
| components/ | 通用组件 | ArkUI 声明式组件 |
| pages/ | 页面 | Navigation + NavPathStack |
| viewmodel/ | MVVM ViewModel | AppStorage + @Observed |
| theme/ | 主题配置 | 资源文件 + 系统主题 |

## 依赖关系图

```
ui (pages/ + components/)
  │
  ├──> viewmodel (状态)
  │     │
  │     ├──> sync (数据同步)
  │     │     │
  │     │     ├──> network/api (REST)
  │     │     │
  │     │     └──> network/websocket (实时)
  │     │
  │     └──> rpc (远程调用)
  │           │
  │           └──> network/websocket
  │
  ├──> auth (认证)
  │     │
  │     ├──> common/crypto (libsodium FFI)
  │     │
  │     └──> network/api
  │
  └──> encryption (端到端加密)
        │
        ├──> common/crypto (libsodium FFI)
        │
        └──> common/utils
```

## 关键技术选型理由

| 能力 | ArkTS 方案 | 选型理由 |
|------|------------|---------|
| 路由导航 | `Navigation` + `NavPathStack` | 原生支持，无三方依赖 |
| 状态管理 | `AppStorage` + `@StorageLink` + `@Watch` | 原生响应式，避免状态管理库 |
| 网络请求 | `@ohos.net.http` | 原生 HTTP 客户端 |
| WebSocket | `@ohos.webSocket` | 标准 WebSocket API |
| 加密 | libsodium NDK + `@ohos.ffi` | 100% 兼容现有协议 |
| 安全存储 | `@ohos.data.relationalStore` (加密模式) | 原生数据库加密 |
| KV 存储 | `@ohos.data.preferences` | 原生 KV 存储 |
| 高性能列表 | `LazyForEach` + `@Reusable` | 原生懒加载组件 |
| WebView | `Web` 组件 | 原生 WebView 组件 |
| 图片缓存 | `ImageKnife` (ohpm) | ohpm 可用方案 |
| 二维码 | `@kit.ScanKit` + ohpm qrcode | 原生扫描 + ohpm 生成 |
| 动画 | `animateTo` + 属性动画 | 原生动画系统 |
| 代码高亮 | WebView 嵌入 highlight.js | 无需 Canvas 重绘 |
| Diff 渲染 | `diff_match_patch` (ohpm) | ohpm 可用方案 |
| Lottie | `lottie-ohos` (ohpm) | ohpm 可用方案 |
| 模糊效果 | `ForegroundBlurStyle` | 原生模糊效果 |
| 渐变 | `linearGradient` | 原生渐变属性 |
| 国际化 | `$r('app.string.xxx')` | 原生资源国际化 |
| 推送 | `@ohos.notificationManager` | 华为推送通知 |
| 生物认证 | `@ohos.userIAM.userAuth` | 原生生物认证 |

## 架构决策记录

### ADR-001: 不使用 happy-wire 包

**决策**：鸿蒙客户端自维护协议定义，不依赖 happy-wire

**理由**：
1. happy-wire 使用 TypeScript 特性，ArkTS 不完全支持
2. 避免跨包耦合，鸿蒙可独立演进
3. happy-wire 的 Zod 验证在鸿蒙端无需重复（客户端信任服务端）

**后果**：
- 需手动对齐协议变更（通过 PRD 文档）
- 类型定义重复，但隔离了变更风险

### ADR-002: 服务端纯新增 WebSocket 传输层

**决策**：不修改现有 Socket.IO 代码，新增独立 WebSocket 处理器

**理由**：
1. 零回归风险，现有 Web 客户端不受影响
2. WebSocket handler 独立实现，无需抽象共享层
3. 业务逻辑直接调用 eventRouter，代码重复可接受

**后果**：
- 存在代码重复（Socket.IO 和 WebSocket handler）
- 后续如需维护两个传输层，可再抽象

### ADR-003: libsodium NDK 替代 CryptoFramework

**决策**：使用 libsodium NDK + FFI 调用，而非 CryptoFramework 原生 API

**理由**：
1. 100% 兼容现有协议，零服务端改动
2. 现有用户数据无需迁移
3. 鸿蒙 NDK 基于 clang/llvm，适配工作量小

**备选方案**：如 NDK 编译失败，切换到服务端协议升级（v2 加密）

### ADR-004: 函数式风格，避免类

**决策**：采用函数式和声明式编程，避免类

**理由**：
1. 与现有 happy-cli 风格一致
2. ArkTS 对类的支持有限（装饰器限制）
3. 函数式更容易测试和维护

### ADR-005: MVVM + 响应式数据流

**决策**：使用 MVVM 架构，ViewModel 通过 @Observed + @Track 实现响应式

**理由**：
1. ArkUI 原生响应式机制，无需三方库
2. 与 React Native 的 zustand 概念类似
3. 支持细粒度更新，性能更优

## 并行开发注意事项

### Phase 0 和 Phase 1 可并行

- Phase 0: libsodium NDK 编译 + FFI 封装（客户端独立）
- Phase 1: Server WebSocket 传输层（服务端独立）
- 两者无依赖，可同时开发

### Phase 2 依赖 Phase 0

- 认证模块需要 Ed25519 签名功能
- 密钥推导需要 libsodium crypto_box

### Phase 3 依赖 Phase 1 + Phase 2

- WebSocket 连接需要 Server WebSocket 端点可用
- 认证成功后才能初始化数据同步

### 接口对齐检查点

| 里程碑 | 检查项 |
|--------|--------|
| M0 | libsodium 编译成功，FFI 调用正常 |
| M1 | Ed25519 签名与 CLI 输出一致 |
| M2 | 能用真实账户登录并拉取会话列表 |
| M3 | WebSocket 端点可用，鸿蒙客户端能连接 |
| M4 | 能创建账户并登录 |
| M5 | 能恢复已有账户（QR 码 + 手动） |
| M6 | 启动后能自动登录（凭据持久化） |
