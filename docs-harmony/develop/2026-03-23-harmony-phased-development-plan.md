# HarmonyOS 分阶段开发计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 `packages/happy-harmony` 建立可落地的鸿蒙原生客户端，并按依赖关系逐阶段完成加密、服务端 WebSocket、认证、核心闭环、功能补全与优化。

**Architecture:** 采用“先打通阻塞依赖，再交付最小闭环，最后逐步补齐功能”的顺序。原则上不重构现有 `happy-app`、`happy-wire`、`happy-cli` 的既有实现；服务端只做纯新增 WebSocket 通道与处理器，鸿蒙客户端自维护协议与类型定义，避免跨包耦合。

**Tech Stack:** ArkTS / ArkUI、`@ohos.net.http`、`@ohos.webSocket`、`@ohos.ffi`、libsodium NDK、`@ohos.security.cryptoFramework`、`@ohos.data.preferences`、`@ohos.data.relationalStore`、`LazyForEach`、`Navigation`、`Web` 组件、ohpm 第三方包。

---

## 计划总览

| Phase | 名称 | 目标 | 依赖 | 交付物 |
|------|------|------|------|------|
| 0 | 加密 PoC | 让鸿蒙端能完成与现有 CLI/App 一致的加密/解密与认证 | 无 | libsodium FFI、SodiumCrypto、认证 PoC |
| 1 | Server WebSocket | 给鸿蒙客户端提供独立 WebSocket 端点 | Phase 0 的加密验证结果 | `wsTransport.ts`、`wsHandlers.ts`、`main.ts` 挂载 |
| 2 | 客户端骨架 + 认证 | 搭起鸿蒙项目、登录、恢复、密钥持久化 | Phase 0 + Phase 1 | 可启动、可登录、可恢复账户的 App |
| 3 | 核心功能闭环 | 打通会话列表、消息同步、聊天、RPC、新建会话 | Phase 2 | 最小可用版本（MVP） |
| 4 | 功能补全 | 对齐 RN 客户端的 P1 / P2 功能 | Phase 3 | 功能完整的鸿蒙客户端 |
| 5 | 优化打磨 | 做性能、体验、可维护性收口 | Phase 4 | 稳定版优化清单与修复 |

## 执行原则

- 先完成阻塞项，不提前扩张 UI 和功能面。
- 每个 Phase 结束时必须有可验证的产物，不允许“只做一半”进入下一阶段。
- 新增能力优先通过服务端或鸿蒙端独立实现，避免修改现有 RN/Web 逻辑。
- 协议、消息帧、加密格式以 `docs-harmony/prd/05-protocol-spec.md` 和 `docs-harmony/prd/07-core-flows.md` 为准。
- 每一步都保留回退方案，尤其是 Phase 0 的 libsodium NDK 风险。

---

## Phase 0: 加密 PoC

**目标**

验证鸿蒙端能完成与现有实现一致的基础密码学操作，这是后续所有能力的前提。

**进入条件**

- 已确认鸿蒙 NDK / ArkTS FFI 的构建方式。
- 已能定位到 libsodium 的编译产物路径和加载路径。

**完成标准**

- Ed25519 签名结果与现有 CLI / App 一致。
- `crypto_box` 和 `crypto_secretbox` 的加解密与现有客户端兼容。
- 能走通创建账户的 challenge-response 认证。
- 能解密真实账户的会话密文样本。

### 任务拆分

1. 搭建鸿蒙 NDK / CMake 编译链，产出 `libsodium.so`。
2. 在 ArkTS 中完成 `.so` 动态加载与 `sodium_init()` 调用。
3. 封装 `SodiumFFI`、`BufferUtils`、`SodiumPath`。
4. 实现 `SodiumCrypto` 的最小集合：
   - 随机数生成
   - Ed25519 keypair / 签名 / 验签
   - `crypto_box` / `crypto_box_open`
   - `crypto_secretbox` / `crypto_secretbox_open`
5. 对照现有 CLI 结果做一致性校验。
6. 跑通认证请求：生成 secret、签名 challenge、调用 `POST /v1/auth`。
7. 用真实账户 secret 解密一条会话样本，确认格式兼容。

### 产出文件

- `packages/happy-harmony/libs/arm64-v8a/libsodium.so`
- `packages/happy-harmony/common/src/main/ets/crypto/SodiumFFI.ets`
- `packages/happy-harmony/common/src/main/ets/crypto/SodiumCrypto.ets`
- `packages/happy-harmony/common/src/main/ets/crypto/BufferUtils.ets`
- `packages/happy-harmony/common/src/main/ets/crypto/SodiumPath.ets`

### 验收方式

- 通过一组固定输入比对签名、加密、解密输出。
- 用真实账户完成一次登录链路。
- 记录是否需要切换备选方案 A。

### 风险与降级

- 如果 libsodium NDK 在目标时间内无法稳定构建，立即评估 `CryptoFramework` + 协议升级方案，不继续向后推进依赖该能力的任务。

---

## Phase 1: Server WebSocket

**目标**

为鸿蒙客户端提供独立的 WebSocket 通道，保持现有 Socket.IO 端不受影响。

**进入条件**

- Phase 0 已证明认证与加密基础可用。
- 已确认协议帧格式与 `docs-harmony/prd/05-protocol-spec.md` 一致。

**完成标准**

- WebSocket 可以建立连接并通过 JWT 认证。
- 支持 ping、push、request/response、RPC 调用。
- 现有 Web 客户端不受影响。
- 鸿蒙客户端能完成基本连接、收发消息和 RPC 互通。

### 任务拆分

1. 新增 WebSocket 传输层，复用现有认证与鉴权思路。
2. 新增消息分发与 ACK 处理。
3. 从现有 socket 处理逻辑中提取核心业务 handler。
4. 在 `main.ts` 挂载 WebSocket 路由。
5. 增加 `ws` 依赖并验证启动流程。
6. 用最小客户端脚本验证连接、心跳、消息、RPC。

### 产出文件

- `packages/happy-server/sources/app/api/wsTransport.ts`
- `packages/happy-server/sources/app/api/wsHandlers.ts`
- `packages/happy-server/sources/main.ts`
- `packages/happy-server/package.json`

### 验收方式

- 启动后能在鸿蒙端连上 `/v1/ws`。
- 消息推送与 RPC 响应都能返回正确 ACK。
- 回归现有 Socket.IO 路径无异常。

---

## Phase 2: 鸿蒙客户端骨架 + 认证

**目标**

完成鸿蒙项目初始化、目录结构、认证链路、凭据存储和启动页跳转。

**进入条件**

- Phase 0 完成并可稳定复现。
- Phase 1 提供可用的 WebSocket 服务端入口。

**完成标准**

- App 可启动。
- 能创建账户、恢复账户、保存凭据、自动登录。
- 首屏可根据状态跳转到登录、恢复或主页骨架。

### 任务拆分

1. 初始化 `packages/happy-harmony` 工程与模块结构。
2. 对齐 `docs-harmony/prd/04-app-architecture.md` 的目录分层。
3. 接入 `SecureStore`、`TokenStore`、`KeyManager`。
4. 封装 `ApiClient`、`AuthService`。
5. 实现 `IndexPage` 启动逻辑。
6. 实现 `LoginPage` 创建账户流程。
7. 实现 `RestorePage` 的 QR 恢复与手动恢复。
8. 完成 QR 码生成与展示。
9. 验证持久化、自动登录、退出登录。

### 产出文件

- `packages/happy-harmony/entry/...`
- `packages/happy-harmony/common/...`
- `packages/happy-harmony/network/...`
- `packages/happy-harmony/auth/...`
- `packages/happy-harmony/ui/pages/IndexPage.ets`
- `packages/happy-harmony/ui/pages/LoginPage.ets`
- `packages/happy-harmony/ui/pages/RestorePage.ets`

### 验收方式

- 新装 App 可完成注册与登录。
- 已登录设备可恢复账户。
- 重启后能从本地凭据恢复会话。

---

## Phase 3: 核心功能闭环

**目标**

把“登录后能用”落到最小可用版本：会话列表、消息流、权限审批、新建会话、RPC 操作全部打通。

**进入条件**

- Phase 2 已完成自动登录与凭据管理。
- WebSocket 端点和协议帧可用。

**完成标准**

- 能看到会话列表和机器列表。
- 能进入聊天页收发消息并正确解密。
- 能处理权限审批和会话模式切换。
- 能新建会话并选择机器、路径和 Profile。

### 任务拆分

1. 实现 `WsTransport`、`WsSender`、`WsReceiver`、`AckManager`。
2. 实现 `SyncEngine` 初始拉取与实时同步。
3. 实现 `SessionSync`、`MessageSync`、`MachineSync`。
4. 实现 `AppViewModel` 全局状态。
5. 实现 `SessionsPage`、`SessionItem`、`MachineList`、`MachineCard`。
6. 实现 `ChatPage`、`ChatViewModel`、`MessageList`、`MessageBubble`、`AgentInput`。
7. 实现 `ThinkingIndicator`、`CodeBlock`、`DiffView`。
8. 实现 `RpcClient`、`SessionRpc`、`MachineRpc`。
9. 实现 `PermissionDialog`。
10. 实现 `NewSessionPage`、`PickMachinePage`、`PickPathPage`。

### 产出文件

- `packages/happy-harmony/sync/...`
- `packages/happy-harmony/rpc/...`
- `packages/happy-harmony/ui/components/...`
- `packages/happy-harmony/ui/pages/SessionsPage.ets`
- `packages/happy-harmony/ui/pages/ChatPage.ets`
- `packages/happy-harmony/ui/pages/NewSessionPage.ets`
- `packages/happy-harmony/ui/pages/PickMachinePage.ets`
- `packages/happy-harmony/ui/pages/PickPathPage.ets`

### 验收方式

- 刷新后会话列表保持一致。
- 消息发送/接收链路完整。
- 审批、拒绝、切换模式、终止等 RPC 操作可用。
- 新建会话流程可独立完成。

---

## Phase 4: 功能补全

**目标**

把 RN 客户端的核心功能逐项补齐，先 P1，再 P2。

**进入条件**

- Phase 3 的最小闭环已经稳定。

**完成标准**

- P1 功能全部可用。
- 主要 P2 功能可用且不会破坏核心链路。

### P1 优先补齐

1. 删除会话。
2. 会话文件浏览。
3. 文件查看与编辑。
4. 远程 Bash。
5. 启动 / 停止 daemon。
6. Kill 会话。
7. 批准 CLI 认证请求。
8. 账户设置与密钥备份。
9. Claude API Key 管理。
10. AI Profile 管理。

### P2 增强功能

1. Artifact 管理。
2. 好友系统。
3. 使用量统计。
4. 华为推送通知。
5. 外观主题切换。
6. 语言切换。
7. GitHub OAuth。
8. 设置页完善。

### 产出建议

- 每个功能单独开小任务，完成后立刻回归核心闭环。
- 文件查看、终端、代码编辑优先使用 WebView 或平台原生能力包装，避免引入过重自研实现。

### 验收方式

- 按功能清单逐项勾验。
- 任一 P1 功能上线前都要跑一遍 Phase 3 的回归检查。

---

## Phase 5: 优化打磨

**目标**

在功能完整前提下，处理性能、体验、可维护性问题。

**进入条件**

- Phase 4 核心功能已完成。

**完成标准**

- 列表滚动、消息渲染、图片/代码块加载无明显卡顿。
- 错误提示、加载态、空态和重试逻辑统一。
- 主题、语言、无障碍和交互反馈基本达标。

### 优化方向

1. 减少同步请求与重复解密。
2. 优化长列表渲染与缓存策略。
3. 统一加载态、空态、错误态组件。
4. 完善日志、埋点和故障排查信息。
5. 补齐动效、视觉一致性和可访问性。
6. 清理临时代码、调试开关和冗余实现。

### 验收方式

- 在真实机型上验证滚动、切页、聊天输入、消息刷新的体验。
- 确认崩溃恢复与异常提示可用。

---

## 里程碑建议

| 里程碑 | 判定条件 |
|------|------|
| M0 | libsodium 构建成功，FFI 可调用 |
| M1 | Ed25519 签名与现有实现一致 |
| M2 | 真实账户可登录并拉取会话列表 |
| M3 | WebSocket 端点可连接并收发消息 |
| M4 | 可创建账户并登录 |
| M5 | 可恢复已有账户 |
| M6 | 启动后可自动登录 |
| M7 | WebSocket 连接稳定，能接收实时更新 |
| M8 | 会话列表与机器列表正常显示 |
| M9 | 能发送消息并看到 agent 回复 |
| M10 | 权限审批与模式切换可用 |
| M11 | 能新建会话 |
| M12 | P1 功能全部完成 |
| M13 | P2 功能全部完成 |

## 推荐实施顺序

1. 先做 Phase 0，直到加密 PoC 稳定。
2. 立刻做 Phase 1，给鸿蒙端准备独立传输通道。
3. 再做 Phase 2，把“能登录”变成产品起点。
4. 然后做 Phase 3，优先完成真实可用闭环。
5. 最后按 P1 -> P2 补齐功能，再做体验优化。

## 备注

- 这个计划默认鸿蒙客户端是新的独立工程，不复用 RN 客户端运行时。
- 如果 Phase 0 选择了备选方案，Phase 1 之后的客户端实现可能需要相应调整加密入口与协议字段。
- 若后续需要进一步拆成周计划或任务卡，可以在 `docs-harmony/develop/` 下继续追加更细的执行文档。
