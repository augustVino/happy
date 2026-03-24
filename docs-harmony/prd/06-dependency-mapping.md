# RN/Expo 依赖到 ArkTS 完整映射表

> 快速查阅：找到 happy-app 中的每个依赖在 ArkTS 中的等价方案

## 图例

- ✅ 原生内置 — 无需三方库
- 📦 ohpm 可用 — 从 ohpm.openharmony.cn 安装
- 🔧 需适配 — 有方案但需额外工作
- ❌ 不可用 — 无鸿蒙方案

## 核心框架

| RN/Expo 依赖 | ArkTS 方案 | 状态 |
|-------------|-----------|------|
| expo-router | `Navigation` + `NavPathStack` | ✅ |
| react-navigation | `Navigation` + `NavPathStack` | ✅ |
| react-native-screens | `Navigation` 内置页面管理 | ✅ |
| expo-constants | `AppStorage` + 配置文件 | ✅ |
| expo-linking | `UIAbility` onNewWant | ✅ |
| expo-updates | 华为应用市场 OTA | 🔧 |
| expo-dev-client | DevEco Studio 热重载 | ✅ |
| expo-splash-screen | Splash Screen Ability | ✅ |
| expo-status-bar | `window.setSystemProperties()` | ✅ |

## 状态管理

| RN/Expo 依赖 | ArkTS 方案 | 状态 |
|-------------|-----------|------|
| zustand | `AppStorage` + `LocalStorage` + `@StorageLink` + `@Watch` | ✅ |

## 网络通信

| RN/Expo 依赖 | ArkTS 方案 | 状态 |
|-------------|-----------|------|
| axios | `@ohos.net.http` | ✅ |
| socket.io-client | `@ohos.webSocket` + 自定义协议 | 🔧 |
| @livekit/react-native | 无 | ❌ |

## 加密与安全

| RN/Expo 依赖 | ArkTS 方案 | 状态 |
|-------------|-----------|------|
| @more-tech/react-native-libsodium | libsodium NDK + `@ohos.ffi` | 🔧 |
| libsodium-wrappers | 同上 | 🔧 |
| rn-encryption | `@ohos.security.cryptoFramework` (AES-256-GCM) | ✅ |
| expo-secure-store | `@ohos.data.relationalStore` (加密模式) | ✅ |
| expo-crypto | `@ohos.security.cryptoFramework` + libsodium FFI | 🔧 |
| react-native-quick-base64 | `@ohos.util.Base64Helper` | ✅ |
| expo-local-authentication | `@ohos.userIAM.userAuth` | ✅ |

## 数据存储

| RN/Expo 依赖 | ArkTS 方案 | 状态 |
|-------------|-----------|------|
| react-native-mmkv | `@ohos.data.preferences` | ✅ |

## 样式与动画

| RN/Expo 依赖 | ArkTS 方案 | 状态 |
|-------------|-----------|------|
| react-native-unistyles | ArkUI 声明式样式系统 | ✅ |
| react-native-reanimated | `animateTo` + 属性动画 + `spring` | ✅ |
| react-native-skia | `Canvas` + ArkGraphics 2D | ✅ |
| lottie-react-native | `lottie-ohos` (ohpm) | 📦 |
| react-native-screen-transitions | `pageTransitionEnter/Exit` | ✅ |

## UI 组件

| RN/Expo 依赖 | ArkTS 方案 | 状态 |
|-------------|-----------|------|
| @shopify/flash-list | `LazyForEach` + `@Reusable` | ✅ |
| @legendapp/list | `LazyForEach` | ✅ |
| react-native-webview | `Web` 组件 | ✅ |
| react-native-svg | ArkUI 矢量图 | 🔧 |
| expo-image | `Image` + `ImageKnife` (ohpm) | 📦 |
| expo-blur | `ForegroundBlurStyle` | ✅ |
| expo-linear-gradient | `linearGradient` 属性 | ✅ |
| expo-checkbox | `Checkbox` / `Toggle` | ✅ |
| @expo/vector-icons | `SymbolGlyph` / 自定义图标 | 🔧 |

## 代码/文本渲染

| RN/Expo 依赖 | ArkTS 方案 | 状态 |
|-------------|-----------|------|
| react-syntax-highlighter | WebView 嵌入 highlight.js | 🔧 |
| react-native-diff-view | `diff_match_patch` (ohpm) + 自定义组件 | 📦 |
| mermaid | WebView 嵌入 mermaid.js | 🔧 |
| @peoplesgrocers/seti-ui-file-icons | 自定义图标映射表 | 🔧 |

## 媒体

| RN/Expo 依赖 | ArkTS 方案 | 状态 |
|-------------|-----------|------|
| expo-camera | `CameraPicker` + `@ohos.multimedia.camera` | ✅ |
| expo-audio | `AVPlayer` + `AVRecorder` | ✅ |
| react-native-audio-api | `AVPlayer` | ✅ |
| expo-video | `AVPlayer` / `Video` | ✅ |
| expo-image-picker | `PhotoPicker` | ✅ |

## 设备能力

| RN/Expo 依赖 | ArkTS 方案 | 状态 |
|-------------|-----------|------|
| expo-application | `UIAbility` context | ✅ |
| expo-device | `@ohos.deviceInfo` | ✅ |
| expo-haptics | `@ohos.vibrator` | ✅ |
| expo-keep-awake | `window.setWindowKeepScreenOn()` | ✅ |

## 系统集成

| RN/Expo 依赖 | ArkTS 方案 | 状态 |
|-------------|-----------|------|
| expo-notifications | `@ohos.notificationManager` | ✅ |
| expo-clipboard | `@ohos.pasteboard` | ✅ |
| expo-file-system | `@ohos.file.fs` | ✅ |
| expo-document-picker | `@ohos.file.picker` | ✅ |
| expo-sharing | `@kit.ShareKit` | ✅ |
| expo-web-browser | `openLink` | ✅ |
| expo-location | `@ohos.geoLocationManager` | ✅ |
| expo-localization | `$r('app.string.xxx')` + 资源文件 | ✅ |
| react-native-safe-area-context | `expandSafeArea` 属性 | ✅ |
| react-native-gesture-handler | PanGesture / PinchGesture / TapGesture | ✅ |
| react-native-keyboard-controller | `@ohos.window` 键盘避让 | ✅ |

## 支付/商业化

| RN/Expo 依赖 | ArkTS 方案 | 状态 |
|-------------|-----------|------|
| react-native-purchases | 华为 IAP (`@ohos.iap`) | 🔧 |
| @revenuecat/purchases-js | 华为 IAP + 服务端桥接 | 🔧 |

## 搜索/工具

| RN/Expo 依赖 | ArkTS 方案 | 状态 |
|-------------|-----------|------|
| qrcode | `@kit.ScanKit` (扫描) + ohpm (生成) | ✅ |
| diff | `diff_match_patch` (ohpm) | 📦 |
| fuse.js | `fuse.js` (ohpm TPC) | 📦 |
| zod | 自定义运行时校验（WireValidators） | 🔧 |

## 不可用依赖及替代方案

| 依赖 | 替代方案 |
|------|---------|
| @livekit/react-native | 短期：WebView 嵌入 WebRTC 页面；长期：等 LiveKit/Janus 适配鸿蒙 |
| @livekit/react-native-webrtc | 同上 |
| livekit-client | 同上 |

## 统计

| 状态 | 数量 | 占比 |
|------|------|------|
| ✅ 原生/ohpm 可用 | 68 | 78% |
| 🔧 需适配 | 16 | 18% |
| ❌ 不可用 | 3 | 3% |
