# RN/Expo 依赖到 ArkTS 完整映射表

> 快速查阅：找到 happy-app 中的每个依赖在 ArkTS 中的等价方案

## 图例

- ✅ 原生内置 — 无需三方库
- 📦 ohpm 可用 — 从 ohpm.openharmony.cn 安装
- 🔧 需适配 — 有方案但需额外工作
- ❌ 不可用 — 无鸿蒙方案
- 🔁 纯 Dart/JS — ArkTS 可直接使用

---

## 核心框架

| RN/Expo 依赖 | ArkTS 方案 | 来源 | 状态 |
|-------------|-----------|------|------|
| expo-router ~6.0.7 | `Navigation` + `NavPathStack` | 原生 | ✅ |
| react-navigation ^7.1.8 | `Navigation` + `NavPathStack` | 原生 | ✅ |
| react-native-screens ~4.16.0 | `Navigation` 内置页面管理 | 原生 | ✅ |
| expo-constants ~18.0.9 | `AppStorage` + 配置文件 | 原生 | ✅ |
| expo-linking ~8.0.8 | `@ohos.app.ability.UIAbility` onNewWant | 原生 | ✅ |
| expo-updates ~29.0.11 | 华为应用市场 OTA | 原生 | 🔧 |
| expo-dev-client ~6.0.12 | DevEco Studio 热重载 | 原生 | ✅ |
| expo-splash-screen ~31.0.10 | Splash Screen Ability | 原生 | ✅ |
| expo-status-bar ~3.0.8 | `window.setSystemProperties()` | 原生 | ✅ |

## 状态管理

| RN/Expo 依赖 | ArkTS 方案 | 来源 | 状态 |
|-------------|-----------|------|------|
| zustand ^5.0.6 | `AppStorage` + `LocalStorage` + `@StorageLink` | 原生 | ✅ |

## 网络通信

| RN/Expo 依赖 | ArkTS 方案 | 来源 | 状态 |
|-------------|-----------|------|------|
| axios ^1.10.0 | `@ohos.net.http` | 原生 | ✅ |
| socket.io-client ^4.8.1 | `@ohos.webSocket` + 自定义协议 | 原生 | 🔧 |
| @livekit/react-native ^2.9.0 | 无 | — | ❌ |
| @livekit/react-native-webrtc | 无 | — | ❌ |
| livekit-client ^2.15.4 | 无 | — | ❌ |

## 加密与安全

| RN/Expo 依赖 | ArkTS 方案 | 来源 | 状态 |
|-------------|-----------|------|------|
| @more-tech/react-native-libsodium | `@ohos.security.cryptoFramework` | 原生 | ✅ |
| libsodium-wrappers 0.8.2 | `@ohos.security.cryptoFramework` | 原生 | ✅ |
| rn-encryption ^2.5.0 | `@ohos.security.cryptoFramework` | 原生 | ✅ |
| expo-secure-store ~15.0.7 | `@ohos.data.relationalStore` (加密模式) | 原生 | ✅ |
| expo-crypto ~15.0.7 | `@ohos.security.cryptoFramework` | 原生 | ✅ |
| react-native-quick-base64 ^2.2.1 | `@ohos.util.Base64Helper` | 原生 | ✅ |
| expo-local-authentication ~17.0.7 | `@ohos.userIAM.userAuth` | 原生 | ✅ |

## 数据存储

| RN/Expo 依赖 | ArkTS 方案 | 来源 | 状态 |
|-------------|-----------|------|------|
| react-native-mmkv ^3.3.3 | `@ohos.data.preferences` / MMKV (ohpm) | 原生/📦 | ✅ |
| @react-native-async-storage/async-storage | `@ohos.data.preferences` | 原生 | ✅ |

## 样式与动画

| RN/Expo 依赖 | ArkTS 方案 | 来源 | 状态 |
|-------------|-----------|------|------|
| react-native-unistyles ^3.0.21 | ArkUI 声明式样式系统 | 原生 | ✅ |
| react-native-reanimated ^4.2.1 | `animateTo` + 属性动画 + `spring` | 原生 | ✅ |
| react-native-skia 2.2.12 | `Canvas` + ArkGraphics 2D (底层即 Skia) | 原生 | ✅ |
| lottie-react-native ~7.3.1 | `lottie-ohos` | 📦 ohpm | ✅ |
| react-native-screen-transitions ^1.2.0 | `pageTransitionEnter` / `pageTransitionExit` | 原生 | ✅ |
| react-native-worklets ^0.7.1 | ArkTS Worker (TaskPool) | 原生 | 🔧 |

## UI 组件

| RN/Expo 依赖 | ArkTS 方案 | 来源 | 状态 |
|-------------|-----------|------|------|
| @shopify/flash-list 2.0.2 | `LazyForEach` + `@Reusable` | 原生 | ✅ |
| @legendapp/list 2.0.0-beta.3 | `LazyForEach` | 原生 | ✅ |
| react-native-webview 13.15.0 | `Web` 组件 | 原生 | ✅ |
| react-native-svg 15.12.1 | ArkUI 矢量图 (6.0+ 增强) | 原生 | 🔧 |
| expo-image ~3.0.8 | `Image` + `ImageKnife` (ohpm) | 原生/📦 | ✅ |
| expo-blur ~15.0.7 | `ForegroundBlurStyle` / `BackgroundBlurStyle` | 原生 | ✅ |
| expo-linear-gradient ~15.0.7 | `linearGradient` 属性 | 原生 | ✅ |
| expo-mesh-gradient ~0.4.7 | 自定义 Canvas 绘制 | 原生 | 🔧 |
| expo-glass-effect ~0.1.4 | `BackgroundBlurStyle` + 透明度 | 原生 | 🔧 |
| expo-checkbox ~5.0.7 | `Checkbox` / `Toggle` | 原生 | ✅ |
| @react-native-community/slider | `Slider` | 原生 | ✅ |
| @react-native-picker/picker | `@ohos.arkui.UIPicker` | 原生 | ✅ |
| @react-native-community/datetimepicker | `@ohos.arkui.DateTimePicker` | 原生 | ✅ |
| @react-native-masked-view | `clip` 属性 | 原生 | ✅ |
| @expo/ui ~0.2.0-beta.3 | ArkUI 原生组件 | 原生 | ✅ |
| @expo/vector-icons ^15.0.2 | `@ohos.arkui.SymbolGlyph` / 自定义图标 | 原生/🔧 | 🔧 |
| expo-navigation-bar ~5.0.8 | `window.setWindowSystemBarProperties()` | 原生 | ✅ |
| expo-screen-orientation ~9.0.7 | `module.json5` + `window` API | 原生 | ✅ |

## 媒体

| RN/Expo 依赖 | ArkTS 方案 | 来源 | 状态 |
|-------------|-----------|------|------|
| react-native-vision-camera ^4.7.3 | `CameraPicker` + `@ohos.multimedia.camera` | 原生 | ✅ |
| expo-camera ~17.0.8 | `CameraPicker` | 原生 | ✅ |
| expo-audio ~1.0.13 | `AVPlayer` + `AVRecorder` | 原生 | ✅ |
| react-native-audio-api ^0.8.2 | `AVPlayer` | 原生 | ✅ |
| expo-video | `AVPlayer` / `Video` 组件 | 原生 | ✅ |
| expo-image-picker ~17.0.8 | `PhotoPicker` (无需权限) | 原生 | ✅ |
| expo-image-manipulator ~14.0.7 | `PixelMap` (裁剪/缩放/旋转) | 原生 | ✅ |
| expo-live-photo ~1.0.7 | 无直接等价 | — | 🔧 |
| expo-screen-capture ~8.0.8 | `@ohos.multimedia.media` 截屏 | 原生 | 🔧 |
| expo-gl ~16.0.7 | `XComponent` (OpenGL/Vulkan) | 原生 | 🔧 |

## 设备能力

| RN/Expo 依赖 | ArkTS 方案 | 来源 | 状态 |
|-------------|-----------|------|------|
| expo-application ~7.0.7 | `@ohos.app.ability.UIAbility` context | 原生 | ✅ |
| expo-device ~8.0.8 | `@ohos.deviceInfo` | 原生 | ✅ |
| react-native-device-info ^14.1.1 | `@ohos.deviceInfo` | 原生 | ✅ |
| expo-haptics ~15.0.7 | `@ohos.vibrator` | 原生 | ✅ |
| expo-sensors ~15.0.7 | `@ohos.sensor` | 原生 | ✅ |
| expo-battery ~10.0.7 | `@ohos.batteryInfo` | 原生 | ✅ |
| expo-brightness ~14.0.7 | `@ohos.brightness` | 原生 | ✅ |
| expo-cellular ~8.0.7 | `@ohos.telephony.observer` | 原生 | ✅ |
| expo-keep-awake ~15.0.7 | `window.setWindowKeepScreenOn()` | 原生 | ✅ |

## 系统集成

| RN/Expo 依赖 | ArkTS 方案 | 来源 | 状态 |
|-------------|-----------|------|------|
| expo-notifications ~0.32.11 | `@ohos.notificationManager` | 原生 | ✅ |
| expo-clipboard ^8.0.7 | `@ohos.pasteboard` | 原生 | ✅ |
| expo-file-system ~19.0.14 | `@ohos.file.fs` | 原生 | ✅ |
| expo-document-picker ~14.0.7 | `@ohos.file.picker` | 原生 | ✅ |
| expo-sharing ~14.0.7 | `@kit.ShareKit` | 原生 | ✅ |
| expo-web-browser ~15.0.7 | `openLink` | 原生 | ✅ |
| expo-location ~19.0.7 | `@ohos.geoLocationManager` | 原生 | ✅ |
| expo-intent-launcher ~13.0.7 | `@ohos.app.ability.UIAbility` startAbility | 原生 | ✅ |
| expo-calendar ~15.0.7 | `@ohos.calendarManager` (API 12+) | 原生 | ✅ |
| expo-mail-composer ~15.0.7 | `Want` 跳转邮件应用 | 原生 | 🔧 |
| expo-print ~15.0.7 | `@ohos.print` | 原生 | ✅ |
| expo-store-review ~9.0.7 | 华为应用市场评分 | 原生 | 🔧 |
| expo-system-ui ~6.0.7 | `window.setSystemProperties()` | 原生 | ✅ |
| expo-localization ~17.0.7 | `$r('app.string.xxx')` + 资源文件 | 原生 | ✅ |
| react-native-localize ^3.5.1 | `@ohos.i18n` | 原生 | ✅ |

## 其他

| RN/Expo 依赖 | ArkTS 方案 | 来源 | 状态 |
|-------------|-----------|------|------|
| react-native-safe-area-context | `expandSafeArea` 属性 | 原生 | ✅ |
| react-native-gesture-handler | PanGesture / PinchGesture / TapGesture | 原生 | ✅ |
| react-native-keyboard-controller | `@ohos.window` 键盘避让 | 原生 | ✅ |
| react-native-purchases ^9.4.2 | `@ohos.iap` (华为 IAP) | 原生 | 🔧 |
| react-native-purchases-ui ^9.4.2 | 华为 IAP UI | 原生 | 🔧 |
| react-native-view-shot 4.0.3 | `@ohos.screenshot` | 原生 | ✅ |
| react-native-diff-view ^1.1.2 | 自定义组件 + `diff_match_patch` (ohpm) | 📦 | 🔧 |
| react-native-typography ^1.4.1 | ArkUI 字体系统 | 原生 | ✅ |
| react-native-enriched ^0.1.2 | 自定义实现 | — | 🔧 |
| react-native-nitro-modules 0.33.2 | 无需（原生开发） | — | ✅ |
| qrcode ^1.5.4 | `@kit.ScanKit` (扫描) + ohpm (生成) | 原生/📦 | ✅ |
| diff ^8.0.2 | `diff_match_patch` (ohpm) | 📦 | ✅ |
| fuse.js ^7.1.0 | `fuse.js` (ohpm TPC) | 📦 | ✅ |
| zod 3.25.76 | happy-wire JSON Schema + 自定义验证 | — | 🔧 |
| mermaid ^11.12.1 | WebView 嵌入 mermaid.js | 🔧 | 🔧 |
| react-syntax-highlighter ^15.6.1 | WebView 嵌入 highlight.js | 🔧 | 🔧 |
| posthog-react-native ^4.16.2 | 服务端 API 转发 | — | 🔧 |
| @elevenlabs/react-native ^0.12.3 | `@kit.CoreSpeechKit` 或 REST API | 原生 | 🔧 |
| @elevenlabs/react-native ^0.5.7 | REST API + AVPlayer 播放 | 原生 | 🔧 |
| @revenuecat/purchases-js ^1.11.1 | 华为 IAP + 服务端桥接 | 原生 | 🔧 |

## 统计

| 状态 | 数量 | 占比 |
|------|------|------|
| ✅ 原生内置/ohpm 可用 | 68 | 78% |
| 🔧 需适配（有方案） | 16 | 18% |
| ❌ 不可用 | 3 | 3% |

### 不可用依赖及替代方案

| 依赖 | 替代方案 |
|------|---------|
| @livekit/react-native | 短期：WebView 嵌入 WebRTC 页面；长期：等 LiveKit/Janus 适配鸿蒙 |
| @livekit/react-native-webrtc | 同上 |
| livekit-client | 同上 |
