# Phase 3 真机验证计划

> Phase 3 完成标准：会话列表、消息同步、聊天、RPC、新建会话全部打通。

---

## 一、验证前检查（阻塞项，必须先修复）

在部署真机之前，以下问题会直接导致功能不可用，需要优先修复。

### BUG-1: `AppViewModel.initialize(token)` 从未被调用

**严重度**: BLOCKER

**现象**: `SessionsPage.aboutToAppear()` 只调用了 `syncSessionsToDataSource()`，读取的是 `AppViewModel.sessions`（空数组）。`SyncEngine.init()` 和 WebSocket 连接从未触发，页面永远显示 Loading 或 No Sessions。

**代码位置**:
- `entry/.../pages/Index.ets:41` — 认证成功后 `router.replaceUrl` 但未传 token
- `ui/.../pages/SessionsPage.ets:33` — `aboutToAppear()` 缺少 `AppViewModel.initialize()` 调用

**修复方向**:
1. `Index.ets` 认证成功后将 token 存入 `AppStorage`（或从 `AuthService` 获取）
2. `SessionsPage.aboutToAppear()` 读取 token 并调用 `await AppViewModel.initialize(token)`

### BUG-2: WebSocket 实时更新不驱动 UI 刷新

**严重度**: HIGH

**现象**: 即使 WebSocket 连接成功，`SyncEngine` 处理 `update` 事件后，`AppViewModel` 的 `@Track sessions/machines` 不会自动更新。原因是 `SyncEngine` 内部的 `SessionSync`/`MessageSync` 修改了自己的数据，但没有回调通知 `AppViewModel`。

**修复方向**: `SyncEngine` 在处理完 update 后回调 `AppViewModel.onSessionsChanged()` / `AppViewModel.onMachinesChanged()`。这两个方法已存在（`AppViewModel.ets:86-97`），只是没被调用。

### BUG-3: ChatPage 不订阅实时消息

**严重度**: HIGH

**现象**: 用户停留在 ChatPage 时，agent 回复通过 WebSocket 推送但不会出现在 UI 中。`SessionViewModel.loadMessages()` 只在 `aboutToAppear()` 调用一次。

**修复方向**: `SessionViewModel` 监听 `SyncEngine` 的新消息事件，或 `ChatPage` 注册 WebSocket 回调后刷新 `this.messages`。

### BUG-4: 退出登录不清理 WebSocket 和 SyncEngine

**严重度**: MEDIUM

**现象**: `Index.ets:113` 的 logout 按钮只调用 `authService.logout()`，未调用 `AppViewModel.dispose()`，导致 WebSocket 连接和 DEK 缓存残留。

**修复方向**: 在 logout 回调中加入 `AppViewModel.getInstance().dispose()`。

---

## 二、环境准备

### 2.1 服务端

| 步骤 | 操作 | 验证方式 |
|------|------|----------|
| 1 | 启动 happy-server（确保 WebSocket 端点 `/v1/ws` 可用） | `curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" https://your-server/v1/ws` 返回 101 |
| 2 | 确认数据库有至少一个测试账户 | 查询 `accounts` 表 |
| 3 | 确认测试账户下有历史会话和消息 | 查询 `sessions` + `messages` 表 |
| 4 | 确认至少一台 machine daemon 在线 | 查询 `machines` 表 `active = true` |

### 2.2 鸿蒙设备/模拟器

| 步骤 | 操作 | 验证方式 |
|------|------|----------|
| 1 | 开启开发者模式和 USB 调试 | 设置 → 关于手机 → 连续点击版本号 → 开发者选项 → USB 调试 |
| 2 | 配置签名（自动签名或手动） | DevEco Studio → File → Project Structure → Signing Configs |
| 3 | 确认网络权限 | `module.json5` 中 `requestPermissions` 包含 `ohos.permission.INTERNET` |
| 4 | 确认服务端地址配置 | 检查 network 模块中的 `BASE_URL` 指向正确的服务端 |
| 5 | 连接设备到 DevEco Studio | 设备列表中显示设备名称 |

### 2.3 依赖服务检查清单

- [ ] libsodium NDK 编译成功（`libs/arm64-v8a/libsodium.so` 存在）
- [ ] `sodium_init()` 调用成功（Phase 0 已验证）
- [ ] `EncryptionService` 能从 SecureStore 读取 master secret
- [ ] AES-GCM 加解密兼容（`AesGcmCrypto` 可正常工作）
- [ ] REST API 端点可达（`GET /v1/sessions`、`GET /v1/machines`）

---

## 三、分步验证流程

### Step 1: 应用启动与认证 (M4-M6)

**目标**: 验证 Phase 2 的认证链路在 Phase 3 代码下仍然正常。

| # | 操作 | 预期结果 | 日志关键字 |
|---|------|----------|-----------|
| 1.1 | 冷启动 App | libsodium 初始化成功，检查凭据 | `IndexPage`, `libsodium initialized` |
| 1.2 | 有凭据时 | 自动跳转到 SessionsPage（显示 Loading → 数据加载完成） | `User authenticated`, `navigating to sessions` |
| 1.3 | 无凭据时 | 显示 Create Account / Restore Account | `No stored credentials` |
| 1.4 | 创建新账户 | 生成密钥对、调用 `POST /v1/auth`、存储凭据、跳转 SessionsPage | `Account created` |
| 1.5 | 恢复账户 | 扫码或手动输入 secret，验证签名，登录成功 | `Account restored` |
| 1.6 | 杀进程后重启 | 自动登录，直达 SessionsPage | `restoreSession` success |

**检查点**:
- [ ] 日志中能看到 `AppViewModel initialized successfully`
- [ ] 日志中能看到 `Sync complete: N sessions, M machines`
- [ ] 日志中能看到 `WebSocket connected`

### Step 2: WebSocket 连接与心跳 (M7)

**目标**: 验证 WebSocket 稳定连接和心跳机制。

| # | 操作 | 预期结果 | 日志关键字 |
|---|------|----------|-----------|
| 2.1 | 进入 SessionsPage 后 | WebSocket 连接建立 | `WsTransport connected`, `WebSocket connected` |
| 2.2 | 等待 25 秒 | 收到心跳 ping，服务端返回 pong | `heartbeat ping`, `pong received` |
| 2.3 | 切到后台再回来 | 连接保持或自动重连 | `reconnecting`, `reconnected` |
| 2.4 | 断开网络再恢复 | 3 次心跳超时后标记断开，网络恢复后重连 | `connection lost`, `reconnected` |

**检查点**:
- [ ] `AppStorage.IS_CONNECTED` 为 `true`
- [ ] 心跳间隔约 25 秒，超时 10 秒
- [ ] 连接断开后 UI 有相应提示（至少日志可见）

### Step 3: 会话列表加载 (M8)

**目标**: 验证 REST 初始拉取 + 解密 + 列表渲染。

| # | 操作 | 预期结果 | 日志关键字 |
|---|------|----------|-----------|
| 3.1 | 进入 SessionsPage | 会话列表显示，标题已解密 | `Sync complete` |
| 3.2 | 检查每个 SessionItem | 标题、最后消息预览、相对时间正确显示 | — |
| 3.3 | 点击 Machines 按钮 | 机器面板展开，在线机器显示绿色状态 | — |
| 3.4 | 空账户 | 显示 EmptyStateView "No Sessions" | — |
| 3.5 | 下拉刷新（如已实现） | 重新拉取并刷新列表 | `refreshFromSyncEngine` |

**检查点**:
- [ ] 会话标题是明文（非加密密文）
- [ ] 机器列表中在线/离线状态正确
- [ ] `LazyForEach` 滚动流畅，无明显卡顿
- [ ] 长列表（> 50 条）滚动无 OOM

### Step 4: 进入聊天页 (M9)

**目标**: 验证消息加载、解密和渲染。

| # | 操作 | 预期结果 | 日志关键字 |
|---|------|----------|-----------|
| 4.1 | 点击一个有消息的会话 | 跳转 ChatPage，标题栏显示会话名称 | `Session loaded: N messages` |
| 4.2 | 检查消息列表 | 消息按时间排序，用户消息靠右，agent 消息靠左 | — |
| 4.3 | 检查消息内容 | 文本消息正确解密显示 | — |
| 4.4 | 检查特殊消息 | `tool-call-start/end` 显示工具名称，`turn-start/end` 显示分隔线 | — |
| 4.5 | 检查 ThinkingIndicator | 如果 agent 正在思考，显示 "Thinking..." 动画 | — |
| 4.6 | 检查 CodeBlock | 代码块有语法高亮/背景色区分 | — |
| 4.7 | 检查 DiffView | diff 块有增/删行颜色区分 | — |
| 4.8 | 点击返回 | 回到 SessionsPage，列表状态保持 | — |

**检查点**:
- [ ] 消息内容完全解密（无乱码、无 Base64 密文）
- [ ] 空会话显示 "No messages yet" 空态
- [ ] 加载中显示 LoadingIndicator
- [ ] 加载失败显示错误信息

### Step 5: 发送消息与实时接收

**目标**: 验证消息发送链路和 WebSocket 实时推送。

**前提**: 需要一台在线的 machine daemon 运行 Claude Code agent。

| # | 操作 | 预期结果 | 日志关键字 |
|---|------|----------|-----------|
| 5.1 | 在输入框输入文本 | 键盘弹出，输入正常 | — |
| 5.2 | 点击发送 | 消息立即出现在列表中（乐观更新），状态变为 "Thinking..." | `Message sent` |
| 5.3 | 等待 agent 回复 | agent 消息通过 WebSocket 推送并自动出现在列表中 | `handleNewMessage` |
| 5.4 | ThinkingIndicator | agent 处理期间显示动画，回复完成后消失 | — |
| 5.5 | 发送多条消息 | 消息顺序正确，无重复或丢失 | — |
| 5.6 | 切到后台再回来 | 新消息仍然能收到 | — |

**检查点**:
- [ ] 发送后消息立即出现在列表底部（乐观更新）
- [ ] agent 回复后消息自动追加，无需手动刷新
- [ ] 消息列表自动滚动到底部
- [ ] Thinking 状态正确显示/消失

### Step 6: 权限审批 (M10)

**目标**: 验证 agent 工具调用的权限审批流程。

**前提**: 需要一个会话中 agent 会触发需要权限的工具（如文件写入、bash 命令）。

| # | 操作 | 预期结果 | 日志关键字 |
|---|------|----------|-----------|
| 6.1 | 发送触发工具调用的消息 | PermissionDialog 弹出，显示工具名称和参数 | — |
| 6.2 | 点击 Approve | 调用 `SessionRpc.allow()`，agent 继续执行 | `rpc-call`, `allow` |
| 6.3 | 发送另一个触发消息 | 新的 PermissionDialog 弹出（FIFO 队列） | — |
| 6.4 | 点击 Deny | 调用 `SessionRpc.deny()`，agent 收到拒绝 | `deny` |
| 6.5 | 多个权限请求排队 | 依次弹出，每次只显示一个 | — |
| 6.6 | 检查切换审批模式 | 如果支持 always-allow 模式切换 | `switchMode` |

**检查点**:
- [ ] PermissionDialog 正确显示工具名称、描述
- [ ] 参数可折叠/展开查看
- [ ] Approve/Deny 后 dialog 消失，agent 行为符合预期
- [ ] 多个请求排队不丢失

### Step 7: 新建会话 (M11)

**目标**: 验证完整的新建会话流程。

| # | 操作 | 预期结果 | 日志关键字 |
|---|------|----------|-----------|
| 7.1 | 点击 SessionsPage 的 "+" 按钮 | 跳转 NewSessionPage | — |
| 7.2 | 选择 AI Profile | Default / Coding / Analysis 选项可选 | — |
| 7.3 | 输入工作目录 | 目录路径输入正常 | — |
| 7.4 | 点击 Next → PickMachinePage | 显示在线机器列表 | — |
| 7.5 | 选择一台在线机器 | 机器高亮选中 | — |
| 7.6 | 点击 Next → PickPathPage | 显示确认的目录路径 | — |
| 7.7 | 点击 Create | 调用 `MachineRpc.spawnHappySession()`，RPC 成功后跳转 ChatPage | `rpc-call`, `spawnHappySession` |
| 7.8 | 新会话出现在列表 | 返回 SessionsPage 能看到新创建的会话 | — |

**检查点**:
- [ ] RPC 调用成功（加密参数发送、解密响应）
- [ ] 新会话在列表中正确显示
- [ ] 能在新会话中发送消息
- [ ] 无在线机器时给出提示

### Step 8: RPC 操作验证

**目标**: 验证各种 RPC 操作的端到端可用性。

| # | 操作 | 预期结果 | RPC 方法 |
|---|------|----------|----------|
| 8.1 | 在 ChatPage 菜单中执行 abort | 会话终止 | `sessionId:abort` |
| 8.2 | 在 ChatPage 菜单中执行 kill | 会话被杀死 | `sessionId:killSession` |
| 8.3 | 在 SessionsPage 选中机器执行 stop daemon | daemon 停止 | `machineId:stopDaemon` |

**检查点**:
- [ ] RPC 请求发送成功（加密帧格式正确）
- [ ] RPC 响应解密成功
- [ ] 操作结果符合预期

### Step 9: 多设备同步验证

**目标**: 验证多端实时同步。

| # | 操作 | 预期结果 |
|---|------|----------|
| 9.1 | 在 Web/RN 客户端发送消息 | 鸿蒙端实时收到新消息 |
| 9.2 | 在鸿蒙端发送消息 | Web/RN 端实时收到 |
| 9.3 | 在 Web/RN 端新建会话 | 鸿蒙端会话列表更新 |
| 9.4 | 在 Web/RN 端删除会话 | 鸿蒙端会话列表更新 |

**检查点**:
- [ ] 双端数据最终一致
- [ ] WebSocket `update` 事件正确触发 UI 刷新

### Step 10: 异常场景与边界测试

| # | 操作 | 预期结果 |
|---|------|----------|
| 10.1 | 无网络时启动 App | 显示错误提示，不崩溃 |
| 10.2 | WebSocket 连接中断后恢复 | 自动重连，数据恢复 |
| 10.3 | DEK 解密失败（新设备首次看到会话） | 会话显示但标题为空，不崩溃 |
| 10.4 | 快速连续点击发送 | 消息不重复 |
| 10.5 | 超长消息（> 4000 字符） | 正常发送和显示 |
| 10.6 | 特殊字符消息（emoji、换行、代码片段） | 正常显示 |
| 10.7 | 大量会话（> 100） | 列表滚动流畅 |
| 10.8 | 大量消息（> 500） | 消息列表滚动流畅 |

---

## 四、验证工具与调试方法

### 4.1 日志查看

```bash
# 通过 hdc 查看实时日志
hdc shell hilog | grep -E "IndexPage|SessionsPage|ChatPage|SyncEngine|WsTransport|AppViewModel|SessionRpc|MachineRpc|EncryptionService|DataKeyManager"
```

### 4.2 关键日志标记

| 标记 | 含义 |
|------|------|
| `libsodium initialized` | FFI 加载成功 |
| `User authenticated` | 认证恢复成功 |
| `AppViewModel initialized successfully` | 初始化完成（含 SyncEngine + WebSocket） |
| `Sync complete: N sessions, M machines` | REST 拉取完成 |
| `WebSocket connected` | WebSocket 连接建立 |
| `heartbeat ping` / `pong received` | 心跳正常 |
| `connection lost` | 连接断开 |
| `handleNewMessage` | 收到新消息推送 |
| `handleNewSession` | 收到新会话推送 |
| `rpc-call` | RPC 请求发出 |
| `DEK decrypted` | 数据密钥解密成功 |
| `Failed to decrypt` | 解密失败（需关注） |

### 4.3 网络抓包（可选）

如需验证 WebSocket 帧格式，可通过 Charles/mitmproxy 代理抓包：
- 过滤 `v1/ws` 路径
- 检查 JWT token 认证
- 检查 ping/pong 心跳帧
- 检查 `update` / `ephemeral` 事件帧

---

## 五、通过标准总表

| 里程碑 | 验证项 | 通过条件 |
|--------|--------|----------|
| M4 | 创建账户并登录 | 注册、登录、凭据持久化均成功 |
| M5 | 恢复已有账户 | 扫码/手动恢复后数据一致 |
| M6 | 自动登录 | 杀进程重启后直达 SessionsPage |
| M7 | WebSocket 连接稳定 | 心跳正常，断线重连 |
| M8 | 会话列表正常显示 | 标题解密、机器状态正确 |
| M9 | 发送消息并看到 agent 回复 | 乐观更新 + 实时推送 |
| M10 | 权限审批可用 | Dialog 弹出、Approve/Deny 生效 |
| M11 | 能新建会话 | RPC spawn 成功、列表更新 |
| M12 | 多端同步 | 双端数据一致 |
| M13 | 异常场景不崩溃 | 断网、快速操作、边界数据均正常 |

---

## 六、优先级排序

**P0（必须通过，否则 Phase 3 不算完成）**:
1. BUG-1 修复 → Step 1-2 通过
2. BUG-2 修复 → Step 3 实时更新通过
3. Step 3: 会话列表加载
4. Step 4: 聊天页消息显示
5. Step 5: 发送与接收消息

**P1（核心功能）**:
6. BUG-3 修复 → 实时消息接收
7. Step 6: 权限审批
8. Step 7: 新建会话
9. Step 8: RPC 操作

**P2（体验和稳定性）**:
10. BUG-4 修复 → 退出登录清理
11. Step 9: 多设备同步
12. Step 10: 异常场景
