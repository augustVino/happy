# 功能对齐全景

现有 RN 客户端的所有功能，鸿蒙版本必须完全覆盖。按优先级分为 P0（阻塞启动/核心体验）到 P3（锦上添花）。

## P0 — 阻塞项（不实现则 App 不可用）

### F01: 创建账户

| 项目 | 说明 |
|------|------|
| 现有实现 | `app/sources/auth/authChallenge.ts` (7 行) + `authGetToken.ts` |
| 依赖 | Ed25519 签名（libsodium FFI）、`expo-crypto.getRandomBytes` |
| 鸿蒙方案 | `@ohos.security.cryptoFramework` Ed25519 + `cryptoFramework.generateRandom` |
| 卡点 | **Phase 0 加密 PoC** — Ed25519 签名必须与现有 CLI/App 输出一致 |

流程：生成 32 字节随机密钥 → Ed25519 签名 challenge → `POST /v1/auth` → 获取 JWT

### F02: 恢复账户（QR 码）

| 项目 | 说明 |
|------|------|
| 现有实现 | `app/sources/auth/authQRStart.ts` + `authQRWait.ts` + `authApprove.ts` |
| 依赖 | NaCl box 加密/解密（Curve25519 + XSalsa20-Poly1305） |
| 鸿蒙方案 | libsodium FFI `crypto_box_seed_keypair` + `crypto_box_easy` |
| 卡点 | **Phase 0 加密 PoC** — NaCl box 必须能解密现有设备产生的密文 |

流程：生成临时 X25519 keypair → 显示 QR 码 → 已登录设备扫码批准 → 轮询获取加密的 secret → 解密 → 用 secret 获取新 token

### F03: 恢复账户（手动输入密钥）

| 项目 | 说明 |
|------|------|
| 现有实现 | `app/sources/auth/secretKeyBackup.ts` |
| 依赖 | Base32 解码、Ed25519 签名 |
| 鸿蒙方案 | 纯算法，无外部依赖 |
| 卡点 | 无 |

流程：用户输入格式化密钥（`XXXXX-XXXXX-...`）→ Base32 解码 → Ed25519 签名认证

### F04: 会话列表

| 项目 | 说明 |
|------|------|
| 现有实现 | `GET /v1/sessions` + WebSocket `update` 事件 |
| 依赖 | REST API、WebSocket 连接 |
| 鸿蒙方案 | `@ohos.net.http` + `@ohos.webSocket` |
| 卡点 | **Phase 1 Server WebSocket** — 鸿蒙需要 WebSocket 端点 |

展示：会话名、最后消息预览、时间、thinking 状态、在线/离线

### F05: 聊天界面（消息收发）

| 项目 | 说明 |
|------|------|
| 现有实现 | `app/sources/sync/apiSocket.ts` + `sync/ops.ts` + `ChatList` + `MessageView` 组件 |
| 依赖 | WebSocket、端到端解密、代码高亮 |
| 鸿蒙方案 | WebSocket 接收 → 解密 → 渲染；发送 → 加密 → WebSocket/REST |
| 卡点 | Phase 0 + Phase 1 |

核心功能：
- 消息列表（`LazyForEach` + `@Reusable`）
- 消息气泡（区分 user/agent）
- 代码块渲染（语法高亮 — WebView 嵌入 highlight.js 或 Canvas 绘制）
- Diff 渲染（`diff_match_patch` ohpm 包）
- 思考状态指示器（WebSocket `ephemeral { type: "activity" }`）
- 消息发送（加密 → `POST /v3/sessions/:id/messages` 或 WebSocket `message`）

### F06: 远程/本地模式切换

| 项目 | 说明 |
|------|------|
| 现有实现 | RPC `sessionSwitch(sessionId, mode)` |
| 依赖 | WebSocket RPC |
| 鸿蒙方案 | WebSocket `rpc-call { method: "{sessionId}:switch", params }` |
| 卡点 | Phase 1 |

### F07: 权限审批（accept/deny）

| 项目 | 说明 |
|------|------|
| 现有实现 | RPC `sessionAllow/Deny(sessionId, id, mode)` |
| 依赖 | WebSocket RPC |
| 鸿蒙方案 | WebSocket `rpc-call` + 加密 params |
| 卡点 | Phase 0 + Phase 1 |

Claude Code 执行工具时需要用户审批，这是核心交互。

### F08: 新建会话

| 项目 | 说明 |
|------|------|
| 现有实现 | `NewSessionWizard`（88KB 组件）+ RPC `machineSpawnNewSession` |
| 依赖 | WebSocket RPC、加密 |
| 鸿蒙方案 | 选机器 → 选路径 → 选 Profile → RPC 调用 |
| 卡点 | Phase 0 + Phase 1 |

流程：获取在线机器列表 → RPC `listDirectory` 浏览路径 → 选择 AI Profile → RPC `spawn-happy-session`

### F09: 机器列表 + 在线状态

| 项目 | 说明 |
|------|------|
| 现有实现 | `GET /v1/machines` + WebSocket `ephemeral { type: "machine-activity" }` |
| 依赖 | REST API、WebSocket |
| 鸿蒙方案 | REST 拉取 + WebSocket 实时更新 |
| 卡点 | Phase 1 |

### F10: 中止当前操作

| 项目 | 说明 |
|------|------|
| 现有实现 | RPC `sessionAbort(sessionId)` |
| 依赖 | WebSocket RPC |
| 鸿蒙方案 | WebSocket `rpc-call` |
| 卡点 | Phase 1 |

## P1 — 重要功能（核心体验完整）

### F11: 删除会话

- REST `DELETE /v1/sessions/:sessionId` + 本地清理
- 无外部依赖阻塞

### F12: 会话文件浏览

- RPC `sessionListDirectory` + `sessionGetDirectoryTree`
- 文件图标（`@peoplesgrocers/seti-ui-file-icons` → 自定义图标映射表）

### F13: 文件查看/编辑

- RPC `sessionReadFile` / `sessionWriteFile`
- WebView 嵌入代码编辑器（Monaco/CodeMirror）

### F14: 远程 Bash 执行

- RPC `sessionBash(sessionId, { command, cwd })`
- 终端 UI 组件（WebView 嵌入 xterm.js 或 Canvas 绘制）

### F15: 启动/停止 daemon

- RPC `machineSpawnNewSession` / `machineStopDaemon`

### F16: Kill 会话

- RPC `sessionKill(sessionId)`

### F17: 批准 CLI 认证请求

- `POST /v1/auth/response`（移动端批准 CLI 登录）
- WebSocket 接收 CLI 认证通知

### F18: 账户设置（密钥备份、登出）

- `GET/POST /v1/account/settings`（加密设置）
- Secret Key 显示/备份（QR 码生成 + 手动复制）
- 登出：清除本地凭据 + 持久化数据

### F19: AI Profile 管理

- 云端同步的 Profile 列表
- 创建/编辑/删除 Profile
- 新建会话时选择 Profile

### F20: 密钥备份（QR 码生成）

- 生成 QR 码显示公钥
- 扫码设备用 `POST /v1/auth/account/response` 批准

### F21: Claude API Key 管理

- `POST /v1/connect/claude/register` — 注册 token
- `GET /v1/connect/claude/token` — 获取 token
- `DELETE /v1/connect/claude` — 删除 token

## P2 — 增强功能（体验优化）

### F22: Artifact 管理

- 列表、查看、编辑、删除
- `GET/POST/PUT/DELETE /v1/artifacts`
- 端到端加密（需 DEK 解密）

### F23: 好友系统

- 好友列表、搜索添加、移除
- `GET/POST /v1/friends`、`GET /v1/user/search`
- 用户资料页

### F24: 使用量统计

- `POST /v1/usage/query`
- 按 session/时间/分组聚合

### F25: 华为推送通知

- `@ohos.notificationManager` 注册推送
- `POST /v1/push-tokens`
- 后台消息 30s watchdog 超时提醒

### F26: 外观主题

- 深色/浅色主题切换
- 跟随系统主题
- `AppStorage` 持久化主题偏好

### F27: 语言切换

- i18n 国际化
- `$r('app.string.xxx')` 资源文件
- 翻译文件可直接复用现有 JSON

### F28: GitHub OAuth

- `GET /v1/connect/github/params` → WebView 打开 OAuth URL
- `GET /v1/connect/github/callback` → 回调处理

### F29: 设置页完整功能

- 版本检查 `POST /v1/version`
- 功能开关
- 语音设置

## P3 — 锦上添花（可后续迭代）

### F30: Feed 动态

- `GET /v1/feed`
- 社交动态流

### F31: ElevenLabs 语音对话

- 依赖 LiveKit WebRTC — 鸿蒙暂无方案
- 短期：WebView 嵌入
- 长期：等生态成熟

### F32: RevenueCat → 华为 IAP

- 付费功能需重建支付流程
- 华为应用内支付 + 服务端桥接

### F33: 无障碍

- 屏幕阅读器支持
- 键盘导航

### F34: 动画优化

- 页面转场动画
- 列表动画
- Lottie 动画

## 功能依赖图

```
Phase 0 (加密 PoC)
    │
    ├─→ F01 创建账户 ─→ F04 会话列表
    ├─→ F02 QR 恢复 ──→ F04 会话列表
    └─→ F03 手动恢复 ──→ F04 会话列表
                           │
Phase 1 (Server WebSocket)  │
    │                       │
    ├─→ F05 聊天界面 ←──────┘
    ├─→ F06 模式切换
    ├─→ F07 权限审批
    ├─→ F08 新建会话
    ├─→ F09 机器列表
    └─→ F10 中止操作
            │
            ▼
Phase 3 完成（最小可用版本）
```

## MVP 范围定义

**最小可用版本 = Phase 0 + Phase 1 + Phase 2 + Phase 3 中 F01-F10**

用户可以：
1. 创建账户 / 恢复账户
2. 看到会话列表和在线机器
3. 进入聊天界面收发消息
4. 审批权限请求
5. 新建会话（选机器 + 路径）
6. 远程/本地模式切换
7. 中止当前操作
