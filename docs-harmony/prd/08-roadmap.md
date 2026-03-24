# 开发路线图

> 分阶段实施，优先跑通核心流程

## Phase 概览

```
Phase 0  加密 PoC                 3 天   ← 唯一阻塞项
Phase 1  Server WebSocket         2 天   ← 纯新增
Phase 2  鸿蒙 App 骨架            5 天   ← 项目初始化 + 认证
Phase 3  核心功能闭环             10 天   ← 会话 + 聊天 + RPC
Phase 4  功能补全                 10 天   ← 逐个对齐
Phase 5  优化打磨                 5 天   ← 性能 + 体验
─────────────────────────────────────
合计                           ~35 天
```

## Phase 0: 加密 PoC

> **阻塞项**：Phase 2-5 全部依赖此 Phase 完成

### 任务清单

- [ ] CMake 适配鸿蒙 NDK，编译 libsodium
- [ ] ArkTS FFI 加载 .so，调用 `sodium_init()`
- [ ] 实现 `SodiumCrypto` 类（签名、Box、SecretBox、随机数）
- [ ] PoC-2: Ed25519 签名与 CLI 输出一致
- [ ] PoC-3: crypto_box 加解密与 CLI 兼容
- [ ] PoC-4: crypto_secretbox 加解密与 CLI 兼容
- [ ] PoC-5: 完整认证流程（生成 secret → 签名 → POST /v1/auth → 获取 JWT）
- [ ] PoC-6: 解密真实会话数据（用现有账户的 secret）

### 产出

```
packages/happy-harmony/
├── libs/arm64-v8a/libsodium.so
└── common/src/main/ets/crypto/
    ├── SodiumFFI.ets
    ├── SodiumCrypto.ets
    ├── BufferUtils.ets
    └── SodiumPath.ets
```

### 里程碑

- **M0**: libsodium 编译成功，FFI 调用正常
- **M1**: Ed25519 签名与 CLI 输出完全一致
- **M2**: 能用真实账户登录并拉取会话列表

### 备选方案触发条件

如果 M0 或 M1 无法在 3 天内完成，切换到备选方案 A（服务端协议升级 + CryptoFramework 原生 API）。

---

## Phase 1: Server WebSocket

> **阻塞项**：Phase 3 依赖此 Phase

### 任务清单

- [ ] 新增 `wsTransport.ts`：WebSocket 连接 + JWT 认证 + 消息分发 + 心跳
- [ ] 新增 `wsHandlers.ts`：从现有 socket handlers 复制核心逻辑
- [ ] 修改 `main.ts`：挂载 WebSocket（+5 行）
- [ ] 新增 `ws` 依赖
- [ ] 验证：现有 Web 客户端不受影响
- [ ] 验证：原生 WebSocket 客户端能连接、收发消息、RPC 调用

### 产出

```
packages/happy-server/sources/app/api/
├── wsTransport.ts    (新增)
└── wsHandlers.ts     (新增)
```

### 里程碑

- **M3**: WebSocket 端点可用，鸿蒙客户端能成功连接

---

## Phase 2: 鸿蒙 App 骨架 + 认证

> **依赖**：Phase 0 (M2) + Phase 1 (M3) 完成

### 任务清单

- [ ] DevEco Studio 创建项目（API 12+，空模板）
- [ ] 配置 oh-package.json5 + 模块化目录结构
- [ ] 集成 libsodium .so + SodiumCrypto
- [ ] 实现 `SecureStore`（凭据持久化）
- [ ] 实现 `ApiClient`（HTTP 客户端封装）
- [ ] 实现 `AuthService`（创建账户 / 恢复账户）
- [ ] 实现 `TokenStore`（JWT 存储 + 自动刷新）
- [ ] 实现 `IndexPage`（启动页：检查凭据 → 登录/主页）
- [ ] 实现 `LoginPage`（创建账户 + 登录）
- [ ] 实现 `RestorePage`（QR 码恢复 + 手动恢复）
- [ ] 实现 `KeyManager`（密钥生成/存储/推导）
- [ ] 实现 `KeyDerivation`（deriveKey + contentKeyPair）
- [ ] 实现 QR 码生成组件

### 产出

可运行的 App：能创建账户、登录、看到空白的主页骨架。

### 里程碑

- **M4**: 能创建账户并登录
- **M5**: 能恢复已有账户（QR 码 + 手动输入）
- **M6**: 启动后能自动登录（凭据持久化）

---

## Phase 3: 核心功能闭环（最小可用版本）

> **依赖**：Phase 2 (M6) 完成

### Step 3.1: WebSocket + 数据同步

- [ ] 实现 `WsTransport`（连接 + 认证 + 心跳 + 重连）
- [ ] 实现 `WsSender` / `WsReceiver`
- [ ] 实现 `AckManager`（Request/Response correlation）
- [ ] 实现 `SyncEngine`（初始拉取 + 实时同步）
- [ ] 实现 `SessionSync` + `MessageSync` + `MachineSync`
- [ ] 实现 `EncryptionService`（统一加密入口）
- [ ] 实现 `DataKeyManager`（DEK 解密 + 缓存）
- [ ] 实现 `SessionEncryption`（消息加解密）

### Step 3.2: 会话列表

- [ ] 实现 `AppViewModel`（全局状态管理）
- [ ] 实现 `SessionsPage`（会话列表页）
- [ ] 实现 `SessionItem` 组件（会话列表项）
- [ ] 实现 `ThinkingIndicator`（思考状态）
- [ ] 实现 `MachineList` + `MachineCard`

### Step 3.3: 聊天界面

- [ ] 实现 `ChatPage`（聊天页）
- [ ] 实现 `ChatViewModel`（聊天状态）
- [ ] 实现 `MessageList`（消息列表，LazyForEach）
- [ ] 实现 `MessageBubble`（消息气泡）
- [ ] 实现 `AgentInput`（消息输入框）
- [ ] 实现 `CodeBlock`（代码高亮，WebView + highlight.js）
- [ ] 实现 `DiffView`（Diff 渲染，diff_match_patch）

### Step 3.4: RPC 控制

- [ ] 实现 `RpcClient`（RPC 调用框架）
- [ ] 实现 `SessionRpc`（abort / allow / deny / switch / kill）
- [ ] 实现 `MachineRpc`（spawn / stop）
- [ ] 实现 `PermissionDialog`（权限审批对话框）

### Step 3.5: 新建会话

- [ ] 实现 `NewSessionPage`
- [ ] 实现 `PickMachinePage`（选择在线机器）
- [ ] 实现 `PickPathPage`（RPC listDirectory 浏览路径）

### 产出

最小可用版本：用户能登录、看到会话列表、进入聊天收发消息、审批权限、新建会话。

### 里程碑

- **M7**: WebSocket 连接正常，能接收实时更新
- **M8**: 会话列表 + 机器列表正常显示
- **M9**: 能发送消息并看到 agent 回复（解密正确）
- **M10**: 权限审批、模式切换正常工作
- **M11**: 能新建会话（选机器 + 路径）

---

## Phase 4: 功能补全

> **依赖**：Phase 3 (M11) 完成

### P1 功能（核心体验完整）

| 任务 | 预估 | 说明 |
|------|------|------|
| 删除会话 | 0.5 天 | REST API + 本地清理 |
| 会话文件浏览 | 1 天 | RPC listDirectory + getDirectoryTree |
| 文件查看 | 1 天 | RPC readFile + WebView 渲染 |
| 远程 Bash | 1 天 | RPC bash + WebView 终端 |
| 启动/停止 daemon | 0.5 天 | RPC |
| Kill 会话 | 0.5 天 | RPC |
| 批准 CLI 认证 | 0.5 天 | POST /v1/auth/response |
| 密钥备份（QR 码） | 0.5 天 | QR 码生成 |
| Claude API Key 管理 | 0.5 天 | REST API |
| AI Profile 管理 | 1 天 | CRUD + 加密 |
| 账户设置 | 0.5 天 | 登出 + 密钥显示 |

### P2 功能（增强体验）

| 任务 | 预估 | 说明 |
|------|------|------|
| Artifact 管理 | 1.5 天 | 列表 + 查看 + 编辑 + 删除 |
| 好友系统 | 1.5 天 | 列表 + 搜索 + 添加/移除 |
| 使用量统计 | 0.5 天 | POST /v1/usage/query |
| 华为推送 | 1 天 | @ohos.notificationManager |
| 外观主题 | 0.5 天 | 深色/浅色切换 |
| 语言切换 | 0.5 天 | i18n |
| GitHub OAuth | 0.5 天 | WebView OAuth 流程 |
| 设置页完善 | 0.5 天 | 版本检查 + 功能开关 |

### 里程碑

- **M12**: P1 功能全部完成
- **M13**: P2 功能全部完成

---

## Phase 5: 优化打磨

> **依赖**：Phase 4 (M13) 完成

### 待优化项（备注，当前不实施）

| 优化项 | 说明 | 备注 |
|--------|------|------|
| happy-wire 收敛 | 将协议定义统一到 happy-wire | 等鸿蒙 App 稳定后 |
| Server SharedHandlers | Socket.IO + WebSocket 统一抽象 | 等需要同时维护时 |
| v2 加密协议 | 去掉 libsodium 依赖，全量 CryptoFramework | 长期目标 |
| LiveKit 语音 | WebRTC 鸿蒙适配 | 等生态成熟 |
| 华为 IAP | RevenueCat → 华为应用内支付 | 需自建支付流程 |
| 无障碍 | 屏幕阅读器 + 键盘导航 | |
| 动画优化 | 页面转场 + 列表动画 | |
| 性能优化 | 启动速度 + 列表滚动 + 内存 | |
| OTA 更新 | 华为应用市场分发 | |
| CI/CD | 自动化构建 + 测试 | |

### 任务清单

| 任务 | 预估 |
|------|------|
| 性能优化（启动速度、列表滚动） | 1 天 |
| 动画（页面转场、消息动画） | 1 天 |
| 错误处理完善 | 0.5 天 |
| 边界情况处理 | 1 天 |
| UI 细节打磨 | 1 天 |
| 测试（真机测试、异常场景） | 0.5 天 |

### 里程碑

- **M14**: 性能指标达标
- **M15**: 发布 v1.0

---

## 依赖关系图

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

Phase 0 和 Phase 1 **可并行**。Phase 2 依赖 Phase 0 完成。Phase 3 依赖 Phase 1 + Phase 2 完成。

## 工作量汇总

| Phase | 工作量 | 累计 | 里程碑 |
|-------|--------|------|--------|
| Phase 0 | 3 天 | 3 天 | M0-M2: 加密可用 |
| Phase 1 | 2 天 | 5 天 | M3: WebSocket 可用 |
| Phase 2 | 5 天 | 10 天 | M4-M6: 能登录 |
| Phase 3 | 10 天 | 20 天 | M7-M11: 最小可用 |
| Phase 4 | 10 天 | 30 天 | M12-M13: 功能完整 |
| Phase 5 | 5 天 | 35 天 | M14-M15: 发布 v1.0 |
