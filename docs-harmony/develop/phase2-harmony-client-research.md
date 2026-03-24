# 鸿蒙客户端研究文档

> 为 Phase 2-5 鸿蒙客户端开发提供技术方案与参考

## 目录

1. [鸿蒙开发技术方案](#1-鸿蒙开发技术方案)
2. [现有 RN 客户端功能清单与 UI 参考](#2-现有-rn-客户端功能清单与-ui-参考)
3. [鸿蒙项目初始化方案](#3-鸿蒙项目初始化方案)
4. [模块划分设计](#4-模块划分设计)
5. [关键技术点与风险](#5-关键技术点与风险)

---

## 1. 鸿蒙开发技术方案

### 1.1 核心技术栈

| 能力 | ArkTS 方案 | 对应 RN 依赖 | 优先级 |
|------|-----------|-------------|--------|
| **路由导航** | `Navigation` + `NavPathStack` | expo-router | P0 |
| **状态管理** | `AppStorage` + `@StorageLink` + `@Watch` | zustand | P0 |
| **网络请求** | `@ohos.net.http` | axios | P0 |
| **WebSocket** | `@ohos.webSocket` | socket.io-client | P0 |
| **加密** | libsodium NDK + `@ohos.ffi` | libsodium | P0 |
| **安全存储** | `@ohos.data.relationalStore` (加密模式) | expo-secure-store | P0 |
| **KV 存储** | `@ohos.data.preferences` | react-native-mmkv | P1 |
| **高性能列表** | `LazyForEach` + `@Reusable` | @shopify/flash-list | P0 |
| **WebView** | `Web` 组件 | react-native-webview | P1 |
| **图片缓存** | `ImageKnife` (ohpm) | expo-image | P1 |
| **二维码** | `@kit.ScanKit` + ohpm qrcode | qrcode | P0 |
| **动画** | `animateTo` + 属性动画 | react-native-reanimated | P2 |
| **代码高亮** | WebView 嵌入 highlight.js | react-syntax-highlighter | P1 |
| **Diff 渲染** | `diff_match_patch` (ohpm) | react-native-diff-view | P1 |
| **Lottie** | `lottie-ohos` (ohpm) | lottie-react-native | P2 |
| **模糊效果** | `ForegroundBlurStyle` | expo-blur | P2 |
| **渐变** | `linearGradient` 属性 | expo-linear-gradient | P2 |
| **国际化** | `$r('app.string.xxx')` | expo-localization | P1 |
| **推送** | `@ohos.notificationManager` | expo-notifications | P2 |
| **生物认证** | `@ohos.userIAM.userAuth` | expo-local-authentication | P1 |
| **分享** | `@kit.ShareKit` | expo-sharing | P1 |
| **文件选择** | `@ohos.file.picker` | expo-document-picker | P1 |
| **触觉反馈** | `@ohos.vibrator` | expo-haptics | P2 |
| **屏幕常亮** | `window.setWindowKeepScreenOn()` | expo-keep-awake | P2 |

### 1.2 Navigation 路由方案

鸿蒙 Navigation 组件提供页面栈管理：

```typescript
// 路由配置
export class Router {
  static push(path: string, params?: Record<string, Object>): void {
    const navPathStack = AppStorage.get('navPathStack') as NavPathStack;
    navPathStack.pushPathByName(path, params);
  }

  static replace(path: string, params?: Record<string, Object>): void {
    const navPathStack = AppStorage.get('navPathStack') as NavPathStack;
    navPathStack.replacePathByName(path, params);
  }

  static pop(): void {
    const navPathStack = AppStorage.get('navPathStack') as NavPathStack;
    navPathStack.pop();
  }

  static popToRoot(): void {
    const navPathStack = AppStorage.get('navPathStack') as NavPathStack;
    navPathStack.clear();
  }
}
```

### 1.3 LazyForEach 长列表优化

鸿蒙的 LazyForEach 提供按需渲染能力：

```typescript
// BasicDataSource 实现
class SessionDataSource implements IDataSource {
  private sessions: Session[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.sessions.length;
  }

  getData(index: number): Session {
    return this.sessions[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    this.listeners.push(listener);
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index = this.listeners.indexOf(listener);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }

  updateSessions(sessions: Session[]): void {
    this.sessions = sessions;
    this.listeners.forEach(listener => listener.onDataReloaded());
  }
}

// 使用 LazyForEach
@Builder
SessionList() {
  List({ space: 8 }) {
    LazyForEach(this.dataSource, (session: Session) => {
      ListItem() {
        SessionItem({ session })
      }
    }, (session: Session) => session.id)
  }
}
```

### 1.4 数据存储方案

#### 1.4.1 SecureStore（凭据存储）

使用 `@ohos.data.relationalStore` 加密模式：

```typescript
// SecureStore.ets
import { relationalStore } from '@kit.ArkData';

export class SecureStore {
  private static storeName = 'HappySecureStore';
  private static db: relationalStore.RdbStore | null = null;

  static async init(context: Context): Promise<void> {
    const config: relationalStore.StoreConfig = {
      name: this.storeName,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    this.db = await relationalStore.getRdbStore(context, config);
  }

  static async setItem(key: string, value: string): Promise<void> {
    if (!this.db) throw new Error('Store not initialized');
    const predicates = new relationalStore.RdbPredicates(this.storeName);
    await this.db.insert(this.storeName, { key, value });
  }

  static async getItem(key: string): Promise<string | null> {
    if (!this.db) throw new Error('Store not initialized');
    const predicates = new relationalStore.RdbPredicates(this.storeName);
    predicates.equalTo('key', key);
    const resultSet = await this.db.query(predicates);
    if (resultSet.goToFirstRow()) {
      return resultSet.getString(1);
    }
    return null;
  }
}
```

#### 1.4.2 Preferences（KV 存储）

使用 `@ohos.data.preferences`：

```typescript
// PreferencesStore.ets
import { preferences } from '@kit.ArkData';

export class PreferencesStore {
  private static storeName = 'HappyPreferences';
  private static store: preferences.Preferences | null = null;

  static async init(context: Context): Promise<void> {
    this.store = await preferences.getPreferences(context, this.storeName);
  }

  static async put(key: string, value: preferences.ValueType): Promise<void> {
    if (!this.store) throw new Error('Store not initialized');
    await this.store.put(key, value);
    await this.store.flush();
  }

  static async get(key: string, defaultValue: preferences.ValueType): Promise<preferences.ValueType> {
    if (!this.store) throw new Error('Store not initialized');
    return await this.store.get(key, defaultValue);
  }
}
```

### 1.5 网络请求封装

使用 `@ohos.net.http`：

```typescript
// ApiClient.ets
import { http } from '@kit.NetworkKit';

export class ApiClient {
  private baseUrl: string;
  private token: string | null = null;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
  }

  setToken(token: string): void {
    this.token = token;
  }

  async request<T>(
    method: http.RequestMethod,
    path: string,
    data?: Record<string, Object>
  ): Promise<T> {
    const url = `${this.baseUrl}${path}`;
    const request = http.createHttp();

    const options: http.HttpRequestOptions = {
      method,
      header: {
        'Content-Type': 'application/json',
        ...(this.token ? { 'Authorization': `Bearer ${this.token}` } : {})
      },
      extraData: data ? JSON.stringify(data) : undefined,
      connectTimeout: 10000,
      readTimeout: 30000
    };

    const response = await request.request(url, options);
    if (response.responseCode !== 200) {
      throw new Error(`HTTP ${response.responseCode}: ${response.result as string}`);
    }

    return JSON.parse(response.result as string) as T;
  }

  async get<T>(path: string): Promise<T> {
    return this.request<T>(http.RequestMethod.GET, path);
  }

  async post<T>(path: string, data: Record<string, Object>): Promise<T> {
    return this.request<T>(http.RequestMethod.POST, path, data);
  }
}
```

### 1.6 WebSocket 客户端

使用 `@ohos.webSocket`：

```typescript
// WsTransport.ets
import { webSocket } from '@kit.NetworkKit';

export interface WsMessageHandler {
  (message: string): void;
}

export class WsTransport {
  private ws: webSocket.WebSocket | null = null;
  private url: string;
  private messageHandlers: WsMessageHandler[] = [];
  private reconnectAttempts = 0;
  private reconnectTimer: number | null = null;

  constructor(url: string) {
    this.url = url;
  }

  connect(): void {
    this.ws = webSocket.createWebSocket();
    this.ws.on('open', () => {
      console.log('WebSocket connected');
      this.reconnectAttempts = 0;
    });
    this.ws.on('message', (error, data) => {
      if (!error) {
        this.messageHandlers.forEach(handler => handler(data as string));
      }
    });
    this.ws.on('close', () => {
      console.log('WebSocket closed');
      this.scheduleReconnect();
    });
    this.ws.on('error', (error) => {
      console.error('WebSocket error:', error);
    });

    this.ws.connect(this.url, 'HarmonyOS');
  }

  send(data: Record<string, Object>): void {
    if (this.ws) {
      this.ws.send(JSON.stringify(data));
    }
  }

  onMessage(handler: WsMessageHandler): void {
    this.messageHandlers.push(handler);
  }

  private scheduleReconnect(): void {
    const delays = [1000, 2000, 4000, 8000, 30000];
    const delay = delays[Math.min(this.reconnectAttempts, delays.length - 1)];
    this.reconnectTimer = setTimeout(() => {
      this.reconnectAttempts++;
      this.connect();
    }, delay);
  }

  disconnect(): void {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
    }
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }
}
```

---

## 2. 现有 RN 客户端功能清单与 UI 参考

### 2.1 核心页面映射

| RN 路由 | 鸿蒙页面 | 说明 |
|---------|---------|------|
| `/` | IndexPage | 启动页（闪屏 + 认证检查） |
| `/restore` | RestorePage | 恢复账户页（QR 扫描 + 手动输入） |
| `/inbox` | SessionsPage | 会话列表页（主页） |
| `/session/[id]` | ChatPage | 聊天页（核心页面） |
| `/new` | NewSessionPage | 新建会话页 |
| `/new/pick/machine` | PickMachinePage | 选择机器页 |
| `/new/pick/path` | PickPathPage | 选择路径页 |
| `/machine/[id]` | MachinePage | 机器管理页 |
| `/settings` | SettingsPage | 设置主页 |
| `/settings/account` | AccountPage | 账户设置页 |
| `/settings/appearance` | AppearancePage | 外观设置页 |
| `/user/[id]` | ProfilePage | 用户资料页 |
| `/artifacts` | ArtifactsPage | Artifact 列表页 |
| `/artifacts/[id]` | ArtifactDetailPage | Artifact 详情页 |
| `/artifacts/edit/[id]` | ArtifactEditPage | Artifact 编辑页 |
| `/terminal` | TerminalPage | 终端页 |

### 2.2 核心组件映射

| RN 组件 | 鸿蒙实现 | 说明 |
|---------|---------|------|
| `ChatList` | `MessageList` | 消息列表（倒置 FlatList） |
| `MessageView` | `MessageBubble` | 消息气泡 |
| `AgentInput` | `AgentInput` | 消息输入框 |
| `Avatar` | `Avatar` | 头像组件 |
| `CodeView` | `CodeBlock` | 代码块（语法高亮） |
| `ToolView` | `ToolView` | 工具调用展示 |
| `CommandPalette` | `CommandPalette` | 命令面板 |
| `FileIcon` | `FileIcon` | 文件图标 |

### 2.3 认证流程 UI

**创建账户**：
1. 显示欢迎信息
2. 点击"创建账户"
3. 后台生成密钥对 + challenge
4. 调用 `POST /v1/auth`
5. 跳转会话列表

**恢复账户（QR）**：
1. 显示"恢复账户"选项
2. 选择 QR 扫描或手动输入
3. QR 扫描：生成临时 X25519 keypair，显示 QR，轮询服务端
4. 手动输入：Base32 解码密钥字符串

### 2.4 聊天界面 UI

**布局**：
- 顶部：会话标题 + 机器状态
- 中间：消息列表（倒置，最新消息在底部）
- 底部：输入框 + 发送按钮

**消息类型**：
- `user-text`：用户文本消息（右对齐气泡）
- `agent-text`：Agent 文本消息（左对齐）
- `tool-call`：工具调用（可展开详情）
- `agent-event`：Agent 事件（居中提示）

---

## 3. 鸿蒙项目初始化方案

### 3.1 创建项目

使用 DevEco Studio 创建 HarmonyOS 工程：

1. 选择 "Empty Activity"
2. 项目名：`happy-harmony`
3. 包名：`com.happy.harmony`
4. 语言：ArkTS
5. API 版本：API 11+

### 3.2 目录结构

按照 `docs-harmony/prd/04-app-architecture.md` 创建模块：

```
packages/happy-harmony/
├── entry/                          # 主模块
│   └── src/main/
│       ├── ets/
│       │   ├── entryability/
│       │   │   └── MainAbility.ets
│       │   └── pages/
│       │       └── Index.ets
│       └── resources/
│           ├── base/
│           ├── en/
│           └── zh/
│
├── common/                         # 公共工具模块
│   └── src/main/ets/
│       ├── constants/
│       ├── utils/
│       ├── crypto/
│       └── types/
│
├── network/                        # 网络通信模块
├── auth/                           # 认证模块
├── sync/                           # 数据同步模块
├── encryption/                     # 端到端加密模块
├── rpc/                            # RPC 调用模块
├── ui/                             # UI 模块
├── services/                       # 平台服务
└── libs/
    └── arm64-v8a/
        └── libsodium.so
```

### 3.3 模块依赖配置

在 `oh-package.json5` 中配置模块依赖：

```json5
{
  "name": "happy-harmony",
  "version": "1.0.0",
  "dependencies": {
    "@hms.core.media": "^1.0.0"
  },
  "dynamicDependencies": {}
}
```

### 3.4 构建配置

`build-profile.json5`：

```json5
{
  "apiType": "stageMode",
  "buildOption": {},
  "buildOptionSet": [
    {
      "name": "release",
      "arkOptions": {
        "obfuscation": {
          "ruleOptions": {
            "enable": true,
            "files": [
              "./obfuscation-rules.txt"
            ]
          }
        }
      }
    }
  ],
  "targets": [
    {
      "name": "default"
    }
  ]
}
```

---

## 4. 模块划分设计

### 4.1 common 模块（公共工具）

**职责**：提供全局常量、工具函数、类型定义

**核心文件**：
- `ServerConfig.ets` - 服务端地址、API 路径
- `AppConstants.ets` - 应用级常量
- `Logger.ets` - 日志工具
- `Base64Utils.ets` - Base64 编解码
- `HexUtils.ets` - Hex 编解码
- `TimeUtils.ets` - 时间格式化
- `WireTypes.ets` - 协议类型定义
- `WsFrames.ets` - WebSocket 帧类型
- `AppState.ets` - 应用状态类型
- `SessionTypes.ets` - 会话相关类型

### 4.2 network 模块（网络通信）

**职责**：HTTP API 和 WebSocket 通信

**核心文件**：
- `ApiClient.ets` - HTTP 客户端封装
- `AuthApi.ets` - 认证 API
- `SessionApi.ets` - 会话 API
- `MachineApi.ets` - 机器 API
- `ArtifactApi.ets` - Artifact API
- `AccountApi.ets` - 账户 API
- `FriendApi.ets` - 社交 API
- `KvApi.ets` - KV 存储 API
- `WsTransport.ets` - WebSocket 传输层
- `WsSender.ets` - 消息发送
- `WsReceiver.ets` - 消息接收与分发
- `WsHeartbeat.ets` - 心跳管理
- `AckManager.ets` - ACK 等待与超时管理

### 4.3 auth 模块（认证）

**职责**：密钥管理和认证流程

**核心文件**：
- `KeyManager.ets` - 密钥管理（生成/存储/恢复）
- `AuthService.ets` - 认证服务（challenge-response）
- `AuthApproveService.ets` - 批准 CLI 认证
- `TokenStore.ets` - JWT Token 存储
- `SecretKeyBackup.ets` - 密钥备份（QR 码生成）

### 4.4 sync 模块（数据同步）

**职责**：数据同步引擎和业务 API

**核心文件**：
- `SyncEngine.ets` - 同步引擎（核心）
- `SessionSync.ets` - 会话同步
- `MachineSync.ets` - 机器同步
- `MessageSync.ets` - 消息同步
- `ArtifactSync.ets` - Artifact 同步
- `FriendSync.ets` - 好友同步
- `KvSync.ets` - KV 同步

### 4.5 encryption 模块（端到端加密）

**职责**：加密/解密服务

**核心文件**：
- `EncryptionService.ets` - 加密服务（统一入口）
- `KeyDerivation.ets` - 密钥推导
- `DataKeyManager.ets` - Data Encryption Key 管理
- `SessionEncryption.ets` - 会话级加密/解密
- `MachineEncryption.ets` - 机器级加密/解密
- `SecureStore.ets` - 安全存储

### 4.6 rpc 模块（RPC 调用）

**职责**：远程过程调用

**核心文件**：
- `RpcClient.ets` - RPC 调用客户端
- `SessionRpc.ets` - 会话级 RPC
- `MachineRpc.ets` - 机器级 RPC

### 4.7 ui 模块（UI）

**职责**：页面和组件

**核心文件**：
- `components/` - 通用组件
- `pages/` - 页面
- `viewmodel/` - ViewModel
- `theme/` - 主题配置

### 4.8 services 模块（平台服务）

**职责**：平台能力封装

**核心文件**：
- `NotificationService.ets` - 华为推送通知
- `ClipboardService.ets` - 剪贴板
- `BiometricService.ets` - 生物认证

---

## 5. 关键技术点与风险

### 5.1 加密 PoC（Phase 0）

**目标**：验证 libsodium NDK + FFI 可行性

**风险**：
- libsodium 在鸿蒙 NDK 上的编译可能遇到问题
- `@ohos.ffi` API 可能与预期不符
- FFI 调用性能可能不如预期

**备选方案**：
- 使用 `@ohos.security.cryptoFramework` + 协议升级
- 考虑使用 WebAssembly 版本的 libsodium

### 5.2 WebSocket 连接稳定性

**挑战**：
- 鸿蒙 WebSocket API 的行为可能与 RN 不同
- 心跳机制需要适配
- 重连策略需要调优

**方案**：
- 实现指数退避重连
- 使用 `@ohos.backgroundTasks` 保持后台连接
- 监听网络状态变化

### 5.3 长列表性能

**挑战**：
- 消息列表可能有数千条
- 滚动性能可能成为瓶颈

**方案**：
- 使用 `LazyForEach` 实现按需渲染
- 使用 `@Reusable` 复用组件
- 实现虚拟滚动（只渲染可见区域）

### 5.4 加密/解密性能

**挑战**：
- 消息加解密可能阻塞 UI
- 批量解密需要优化

**方案**：
- 使用 TaskPool 进行后台加解密
- 实现加密缓存（类似 RN 的 `EncryptionCache`）
- 批量处理消息

### 5.5 内存管理

**挑战**：
- 大量消息可能导致内存压力
- 图片加载需要优化

**方案**：
- 实现消息分页加载
- 图片使用缩略图 + 按需加载原图
- 及时释放不再使用的资源

### 5.6 代码复用策略

**原则**：
- 鸿蒙客户端自维护协议与类型定义
- 参考但**不直接复制** RN 客户端代码
- 使用函数式风格，避免类

**可复用的部分**：
- 加密算法逻辑（移植为 ArkTS）
- 协议帧格式（参考 PRD）
- UI/UX 设计（参考 RN 实现）

### 5.7 测试策略

**单元测试**：
- 加密/解密函数
- 类型验证函数
- 工具函数

**集成测试**：
- API 调用
- WebSocket 连接
- 数据同步流程

**UI 测试**：
- 关键用户流程
- 认证流程
- 消息发送/接收

---

## 6. 待确认问题

1. **libsodium NDK 编译**：是否有现成的鸿蒙版本或成功案例？
2. **@ohos.ffi 可用性**：API 是否稳定，文档是否完整？
3. **WebSocket 行为**：与标准 WebSocket 实现是否有差异？
4. **后台运行限制**：如何保持 WebSocket 长连接？
5. **代码高亮方案**：WebView 方案性能是否可接受？
6. **Diff 渲染**：是否有现成的鸿蒙组件可用？

---

## 7. 下一步行动

等待 Phase 0（加密 PoC）和 Phase 1（Server WebSocket）完成后：

1. **确认加密方案可行性**
2. **确认 WebSocket 端点可用**
3. **开始 Phase 2：鸿蒙客户端骨架 + 认证**

---

*文档创建时间：2026-03-23*
