# 鸿蒙客户端架构

> 鸿蒙原生客户端 `packages/happy-harmony` 的模块划分、技术选型和目录结构

## 目录结构

```
packages/happy-harmony/
├── entry/                          # 主模块（自动生成）
│   └── src/main/
│       ├── ets/
│       │   ├── entryability/
│       │   │   └── MainAbility.ets    # UIAbility 入口
│       │   └── pages/
│       │       └── Index.ets          # 启动页（闪屏 + 认证检查）
│       └── resources/
│           ├── base/                   # 默认资源
│           ├── en/                     # 英文
│           └── zh/                     # 中文
│
├── common/                         # 公共工具模块
│   └── src/main/ets/
│       ├── constants/
│       │   ├── ServerConfig.ets       # 服务端地址、API 路径
│       │   └── AppConstants.ets       # 应用级常量
│       ├── utils/
│       │   ├── Logger.ets             # 日志工具
│       │   ├── Base64Utils.ets        # Base64 编解码
│       │   ├── HexUtils.ets           # Hex 编解码
│       │   └── TimeUtils.ets          # 时间格式化
│       ├── crypto/
│       │   ├── SodiumFFI.ets          # libsodium FFI 函数定义
│       │   ├── SodiumCrypto.ets       # 高级加密封装
│       │   ├── BufferUtils.ets        # FFI Buffer 工具
│       │   ├── AESGCMUtils.ets        # AES-256-GCM（CryptoFramework）
│       │   └── SodiumPath.ets         # .so 路径配置
│       └── types/
│           ├── WireTypes.ets          # 协议类型定义（自维护）
│           ├── WsFrames.ets           # WebSocket 帧类型
│           ├── AppState.ets           # 应用状态类型
│           └── SessionTypes.ets       # 会话相关类型
│
├── network/                        # 网络通信模块
│   └── src/main/ets/
│       ├── api/
│       │   ├── ApiClient.ets          # HTTP 客户端封装（@ohos.net.http）
│       │   ├── AuthApi.ets            # 认证 API
│       │   ├── SessionApi.ets         # 会话 API
│       │   ├── MachineApi.ets         # 机器 API
│       │   ├── ArtifactApi.ets        # Artifact API
│       │   ├── AccountApi.ets         # 账户 API
│       │   ├── FriendApi.ets          # 社交 API
│       │   └── KvApi.ets              # KV 存储 API
│       └── websocket/
│           ├── WsTransport.ets        # WebSocket 传输层
│           ├── WsSender.ets           # 消息发送
│           ├── WsReceiver.ets         # 消息接收与分发
│           ├── WsHeartbeat.ets        # 心跳管理
│           └── AckManager.ets         # ACK 等待与超时管理
│
├── auth/                           # 认证模块
│   └── src/main/ets/
│       ├── KeyManager.ets            # 密钥管理（生成/存储/恢复）
│       ├── AuthService.ets           # 认证服务（challenge-response）
│       ├── AuthApproveService.ets    # 批准 CLI 认证
│       ├── TokenStore.ets            # JWT Token 存储
│       └── SecretKeyBackup.ets       # 密钥备份（QR 码生成）
│
├── sync/                           # 数据同步模块
│   └── src/main/ets/
│       ├── SyncEngine.ets            # 同步引擎（核心）
│       ├── SessionSync.ets           # 会话同步
│       ├── MachineSync.ets           # 机器同步
│       ├── MessageSync.ets           # 消息同步
│       ├── ArtifactSync.ets          # Artifact 同步
│       ├── FriendSync.ets            # 好友同步
│       └── KvSync.ets                # KV 同步
│
├── encryption/                     # 端到端加密模块
│   └── src/main/ets/
│       ├── EncryptionService.ets     # 加密服务（统一入口）
│       ├── KeyDerivation.ets         # 密钥推导（deriveKey + box keypair）
│       ├── DataKeyManager.ets        # Data Encryption Key 管理
│       ├── SessionEncryption.ets     # 会话级加密/解密
│       ├── MachineEncryption.ets     # 机器级加密/解密
│       └── SecureStore.ets           # 安全存储（凭据持久化）
│
├── rpc/                            # RPC 调用模块
│   └── src/main/ets/
│       ├── RpcClient.ets             # RPC 调用客户端
│       ├── SessionRpc.ets            # 会话级 RPC（abort/allow/deny/bash 等）
│       └── MachineRpc.ets            # 机器级 RPC（spawn/stop/bash 等）
│
├── ui/                             # UI 模块
│   └── src/main/ets/
│       ├── components/               # 通用组件
│       │   ├── SessionList.ets       # 会话列表
│       │   ├── SessionItem.ets       # 会话列表项
│       │   ├── MessageBubble.ets     # 消息气泡
│       │   ├── MessageList.ets       # 消息列表
│       │   ├── CodeBlock.ets         # 代码块（语法高亮）
│       │   ├── DiffView.ets          # Diff 视图
│       │   ├── MachineCard.ets       # 机器卡片
│       │   ├── MachineList.ets       # 机器列表
│       │   ├── Avatar.ets            # 头像组件
│       │   ├── AgentInput.ets        # 消息输入框
│       │   ├── PermissionDialog.ets  # 权限审批对话框
│       │   ├── ThinkingIndicator.ets # 思考状态指示器
│       │   ├── QrCodeView.ets        # QR 码组件
│       │   └── LoadingView.ets       # 加载状态
│       ├── pages/
│       │   ├── IndexPage.ets         # 启动页
│       │   ├── LoginPage.ets         # 登录/注册页
│       │   ├── RestorePage.ets       # 恢复账户页
│       │   ├── SessionsPage.ets      # 会话列表页（主页）
│       │   ├── ChatPage.ets          # 聊天页（核心页面）
│       │   ├── NewSessionPage.ets    # 新建会话页
│       │   ├── PickMachinePage.ets   # 选择机器页
│       │   ├── PickPathPage.ets      # 选择路径页
│       │   ├── MachinePage.ets       # 机器管理页
│       │   ├── SettingsPage.ets      # 设置主页
│       │   ├── AccountPage.ets       # 账户设置页
│       │   ├── AppearancePage.ets    # 外观设置页
│       │   └── ProfilePage.ets       # 用户资料页
│       ├── viewmodel/
│       │   ├── AppViewModel.ets      # 应用全局状态
│       │   ├── SessionViewModel.ets  # 会话状态
│       │   ├── ChatViewModel.ets     # 聊天状态
│       │   └── MachineViewModel.ets  # 机器状态
│       └── theme/
│           ├── Colors.ets            # 颜色定义
│           ├── Typography.ets        # 字体排版
│           └── AppTheme.ets          # 主题配置
│
├── services/                       # 平台服务
│   └── src/main/ets/
│       ├── NotificationService.ets  # 华为推送通知
│       ├── ClipboardService.ets     # 剪贴板
│       └── BiometricService.ets     # 生物认证
│
├── libs/
│   └── arm64-v8a/
│       └── libsodium.so             # libsodium NDK 编译产物
│
├── oh-package.json5                 # 包配置
├── ohpm-relock.json5                # 依赖锁定
└── build-profile.json5             # 构建配置
```

## 技术选型

| 能力 | ArkTS 方案 | 对应 RN 依赖 |
|------|-----------|-------------|
| 路由导航 | `Navigation` + `NavPathStack` | Expo Router |
| 状态管理 | `AppStorage` + `@StorageLink` + `@Watch` | zustand |
| 网络请求 | `@ohos.net.http` | axios |
| WebSocket | `@ohos.webSocket` | socket.io-client |
| 加密 | libsodium NDK + `@ohos.ffi` | libsodium (原生) |
| 安全存储 | `@ohos.data.relationalStore` (加密) | expo-secure-store |
| KV 存储 | `@ohos.data.preferences` | react-native-mmkv |
| 高性能列表 | `LazyForEach` + `@Reusable` | @shopify/flash-list |
| WebView | `Web` 组件 | react-native-webview |
| 图片缓存 | `ImageKnife` (ohpm) | expo-image |
| 二维码 | `@kit.ScanKit` + ohpm qrcode | qrcode |
| 动画 | `animateTo` + 属性动画 | react-native-reanimated |
| 代码高亮 | WebView 嵌入 highlight.js | react-syntax-highlighter |
| Diff 渲染 | `diff_match_patch` (ohpm) | react-native-diff-view |
| Lottie | `lottie-ohos` (ohpm) | lottie-react-native |
| 模糊效果 | `ForegroundBlurStyle` | expo-blur |
| 渐变 | `linearGradient` | expo-linear-gradient |
| 国际化 | `$r('app.string.xxx')` | expo-localization |
| 推送 | `@ohos.notificationManager` | expo-notifications |
| 生物认证 | `@ohos.userIAM.userAuth` | expo-local-authentication |
| 分享 | `@kit.ShareKit` | expo-sharing |
| 文件选择 | `@ohos.file.picker` | expo-document-picker |
| 触觉反馈 | `@ohos.vibrator` | expo-haptics |
| 屏幕常亮 | `window.setWindowKeepScreenOn()` | expo-keep-awake |
| 搜索 | `fuse.js` (ohpm TPC) | fuse.js |

## 模块间依赖关系

```
ui (页面/组件)
  │
  ├──> viewmodel (状态)
  │     │
  │     ├──> sync (数据同步)
  │     │     │
  │     │     ├──> network/api (REST)
  │     │     └──> network/websocket (实时)
  │     │
  │     └──> rpc (远程调用)
  │           │
  │           └──> network/websocket
  │
  ├──> auth (认证)
  │     │
  │     ├──> crypto (libsodium FFI)
  │     └──> network/api
  │
  └──> encryption (端到端加密)
        │
        ├──> crypto (libsodium FFI)
        └──> common/utils
```

## 核心设计模式

### MVVM + 响应式

```
View (@Component)
  │ @State / @Prop / @Link
  ▼
ViewModel (@Observed)
  │ @Track 装饰器
  ▼
Model / Service (纯逻辑)
```

### 数据流

```
Server Push (WebSocket)
    │
    ▼
WsReceiver → 解析帧 → SyncEngine.handleUpdate()
    │
    ▼
AppStorage (全局响应式状态)
    │
    ▼
@StorageLink / @Watch → UI 自动刷新
```

### 错误处理策略

```
网络错误 → 自动重连（指数退避）
加密错误 → 降级显示（原文提示，不解密）
认证过期 → 跳转登录页
RPC 超时 → 提示用户，不阻塞 UI
```

## 启动流程

```
MainAbility.onCreate()
    │
    ├─ sodiumInit()                    ← 加密库初始化
    │
    ├─ SecureStore.getCredentials()     ← 读取本地凭据
    │
    ├─ 有凭据?
    │   ├─ 是 → SyncEngine.init()      ← 连接 WebSocket + 拉取数据
    │   │       └─> SessionsPage
    │   └─ 否 → LoginPage
    │
    └─ AppStorage.set('isReady', true)
```

## 页面路由映射

| RN 路由 | 鸿蒙页面 | NavPathStack 路径 |
|---------|---------|-------------------|
| `/` | IndexPage | `index` |
| 登录流程 | LoginPage | `login` |
| 恢复账户 | RestorePage | `restore` |
| 会话列表 | SessionsPage | `sessions` |
| 聊天 | ChatPage | `chat/{sessionId}` |
| 新建会话 | NewSessionPage | `new-session` |
| 选机器 | PickMachinePage | `pick-machine` |
| 选路径 | PickPathPage | `pick-path` |
| 机器管理 | MachinePage | `machine/{machineId}` |
| 设置 | SettingsPage | `settings` |
| 账户 | AccountPage | `account` |
| 外观 | AppearancePage | `appearance` |
| 用户资料 | ProfilePage | `profile/{userId}` |
