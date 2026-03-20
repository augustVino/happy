# Phase 3: happy-harmony 客户端架构

> 优先级：**P1（依赖 Phase 1 和 Phase 2 完成）**
> 预估：全新开发，工作量最大

## 目录结构

```
packages/happy-harmony/
├── entry/                          # 主模块（自动生成）
│   └── src/main/
│       ├── ets/
│       │   ├── entryability/       # UIAbility 入口
│       │   │   └── MainAbility.ets
│       │   └── pages/              # 页面
│       │       └── Index.ets       # 启动页
│       └── resources/              # 资源文件
│           ├── base/               # 基础资源
│           ├── en/                 # 英文
│           └── zh/                 # 中文
├── oh-package.json5                # 包配置
├── ohpm-relock.json5               # 依赖锁定
└── build-profile.json5             # 构建配置
```

### 推荐模块化结构

```
packages/happy-harmony/
├── entry/                          # 主模块
├── common/                         # 公共工具模块
│   └── src/main/ets/
│       ├── constants/              # 常量定义
│       │   ├── ServerConfig.ets    # 服务端地址、API 路径
│       │   └── AppConstants.ets    # 应用级常量
│       ├── utils/                  # 工具函数
│       │   ├── Logger.ets          # 日志工具
│       │   ├── CryptoUtils.ets     # 加密工具（TweetNaCl 对等）
│       │   └── Base64Utils.ets     # Base64 编解码
│       └── types/                  # 类型定义
│           ├── WireTypes.ets       # 从 happy-wire JSON Schema 生成
│           └── AppState.ets        # 应用状态类型
├── network/                        # 网络通信模块
│   └── src/main/ets/
│       ├── api/                    # REST API
│       │   ├── ApiClient.ets       # HTTP 客户端封装
│       │   ├── AuthApi.ets         # 认证 API
│       │   ├── SessionApi.ets      # 会话 API
│       │   ├── MachineApi.ets      # 机器 API
│       │   └── AccountApi.ets      # 账户 API
│       ├── websocket/              # WebSocket 通信
│       │   ├── WsTransport.ets     # WebSocket 传输层
│       │   ├── WsSender.ets        # 消息发送
│       │   └── WsReceiver.ets      # 消息接收与分发
│       └── protocol/               # 协议层
│           ├── MessageCodec.ets    # 消息编解码
│           └── Heartbeat.ets       # 心跳管理
├── auth/                           # 认证模块
│   └── src/main/ets/
│       ├── KeyManager.ets          # 密钥对管理（TweetNaCl 签名密钥）
│       ├── AuthService.ets         # 认证服务（challenge-response）
│       └── TokenStore.ets          # JWT Token 存储
├── sync/                           # 数据同步模块
│   └── src/main/ets/
│       ├── SyncEngine.ets          # 同步引擎（核心）
│       ├── SessionSync.ets         # 会话同步
│       ├── MachineSync.ets         # 机器同步
│       └── MessageSync.ets         # 消息同步
├── crypto/                         # 端到端加密模块
│   └── src/main/ets/
│       ├── EncryptionService.ets   # 加密服务
│       ├── DataKeyManager.ets      # 数据密钥管理
│       └── SecureStore.ets         # 安全存储（等价 expo-secure-store）
├── ui/                             # UI 模块
│   └── src/main/ets/
│       ├── components/             # 通用组件
│       │   ├── SessionList.ets     # 会话列表
│       │   ├── MessageBubble.ets   # 消息气泡
│       │   ├── MachineCard.ets     # 机器卡片
│       │   ├── Avatar.ets          # 头像组件
│       │   └── CodeBlock.ets       # 代码块（语法高亮）
│       ├── pages/                  # 页面
│       │   ├── SessionsPage.ets    # 会话列表页
│       │   ├── ChatPage.ets        # 聊天页（核心页面）
│       │   ├── MachinePage.ets     # 机器管理页
│       │   ├── SettingsPage.ets    # 设置页
│       │   └── AuthPage.ets        # 认证页
│       ├── viewmodel/              # MVVM ViewModel
│       │   ├── SessionViewModel.ets
│       │   ├── ChatViewModel.ets
│       │   └── MachineViewModel.ets
│       └── theme/                  # 主题
│           ├── Colors.ets          # 颜色定义
│           ├── Typography.ets      # 字体排版
│           └── AppTheme.ets        # 主题配置
└── services/                       # 平台服务
    └── src/main/ets/
        ├── NotificationService.ets # 通知服务
        └── ClipboardService.ets    # 剪贴板服务
```

## 技术选型

| 能力 | ArkTS 方案 | 对应 RN 依赖 |
|------|-----------|-------------|
| 路由导航 | `Navigation` + `NavPathStack` | Expo Router |
| 状态管理 | `AppStorage` + `@StorageLink` | zustand |
| 网络请求 | `@ohos.net.http` | axios |
| WebSocket | `@ohos.webSocket` | socket.io-client |
| 加密 | `@ohos.security.cryptoFramework` | libsodium |
| 安全存储 | `@ohos.data.relationalStore` (加密) | expo-secure-store |
| KV 存储 | `@ohos.data.preferences` / MMKV | react-native-mmkv |
| 高性能列表 | `LazyForEach` + `@Reusable` | @shopify/flash-list |
| WebView | `Web` 组件 | react-native-webview |
| 图片缓存 | `ImageKnife` (ohpm) | expo-image |
| 二维码 | `@kit.ScanKit` | qrcode |
| 动画 | `animateTo` + 属性动画 | react-native-reanimated |
| 2D 绘图 | `Canvas` + ArkGraphics 2D | react-native-skia |
| Lottie | `lottie-ohos` (ohpm) | lottie-react-native |
| 模糊效果 | `ForegroundBlurStyle` | expo-blur |
| 渐变 | `linearGradient` | expo-linear-gradient |
| 表单组件 | `Checkbox` / `Toggle` / `Slider` (内置) | expo-checkbox / slider |
| 相机 | `CameraPicker` | react-native-vision-camera |
| 音频 | `AVPlayer` | just_audio |
| 视频 | `AVPlayer` / `Video` | video_player |
| 国际化 | `$r('app.string.xxx')` | expo-localization |
| 通知 | `@ohos.notificationManager` | expo-notifications |
| 定位 | `@ohos.geoLocationManager` | expo-location |
| 生物认证 | `@ohos.userIAM.userAuth` | expo-local-authentication |
| 分享 | `@kit.ShareKit` | expo-sharing |
| 文件选择 | `@ohos.file.picker` | expo-document-picker |
| 触觉反馈 | `@ohos.vibrator` | expo-haptics |
| 屏幕常亮 | `window.setWindowKeepScreenOn()` | expo-keep-awake |

## 核心模块设计

### 1. 认证流程 (auth/)

```
┌─────────────┐     challenge      ┌─────────────┐
│  鸿蒙客户端  │ ────────────────>  │   服务端     │
│             │ <────────────────  │             │
│             │   challenge + sig  │             │
│             │ ────────────────>  │             │
│             │   JWT token        │             │
└─────────────┘ <────────────────  └─────────────┘
```

```typescript
// AuthService.ets
// 使用 @ohos.security.cryptoFramework 实现 TweetNaCl 等价的签名
// 1. 生成 Ed25519 密钥对
// 2. 签名 challenge
// 3. 发送认证请求
// 4. 存储 JWT token
```

### 2. WebSocket 通信 (network/websocket/)

```typescript
// WsTransport.ets
// 连接: ws://server/v1/ws?token=JWT&clientType=user-scoped
// 消息帧格式: { event: string, data: unknown }
// 心跳: 25s 间隔 ping/pong
// 重连: 指数退避（1s, 2s, 4s, 8s, 最大 30s）
```

### 3. 数据同步 (sync/)

```
启动 ──> REST 拉取初始数据 ──> WebSocket 实时同步
              │                      │
              │                      ├── update (new-message)
              │                      ├── update (update-session)
              │                      ├── update (update-machine)
              │                      └── ephemeral (活动状态)
              │
              ├── GET /v1/sessions
              ├── GET /v1/machines
              └── GET /v1/account/profile
```

### 4. 端到端加密 (crypto/)

```typescript
// EncryptionService.ets
// 对等实现 happy-app 的加密方案:
// - legacy: NaCl secretbox → 用 @ohos.security.cryptoFramework (AES-256-GCM)
// - dataKey: AES-256-GCM → 直接使用 CryptoFramework
// - key exchange: libsodium box → 用 ECDH (CryptoFramework)
```

## 开发步骤（建议顺序）

### Step 1: 项目初始化
- [ ] DevEco Studio 创建项目（API 12+，空模板）
- [ ] 配置 oh-package.json5
- [ ] 创建模块化目录结构

### Step 2: 基础设施
- [ ] Logger 日志工具
- [ ] ServerConfig 服务端配置
- [ ] ApiClient HTTP 客户端
- [ ] CryptoUtils 加密工具

### Step 3: 认证模块
- [ ] KeyManager 密钥对生成
- [ ] AuthService challenge-response 认证
- [ ] TokenStore JWT 存储

### Step 4: 网络通信
- [ ] WsTransport WebSocket 连接
- [ ] Heartbeat 心跳管理
- [ ] MessageCodec 消息编解码

### Step 5: 数据同步
- [ ] REST API 数据拉取
- [ ] WebSocket 实时同步
- [ ] SyncEngine 同步引擎

### Step 6: 端到端加密
- [ ] EncryptionService 加密/解密
- [ ] DataKeyManager 密钥管理
- [ ] SecureStore 安全存储

### Step 7: UI 界面
- [ ] AppTheme 主题系统
- [ ] SessionsPage 会话列表
- [ ] ChatPage 聊天页面（核心）
- [ ] MachinePage 机器管理
- [ ] SettingsPage 设置页面

### Step 8: 优化与完善
- [ ] 华为推送通知
- [ ] 二维码扫码连接
- [ ] 国际化
- [ ] 无障碍
