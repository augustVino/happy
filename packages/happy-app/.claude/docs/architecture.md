# App 架构

## 技术栈

- **React Native** + **Expo** SDK 54
- **TypeScript** strict 模式
- **Unistyles** 跨平台样式（主题 + 断点）
- **Expo Router v6** 基于文件的路由
- **Socket.io** WebSocket 实时通信
- **libsodium** 端到端加密
- **LiveKit** 实时语音

## 项目结构

```
sources/
├── app/              # Expo Router 页面
├── auth/             # 认证逻辑（QR 码）
├── components/       # 可复用 UI 组件
├── sync/             # 实时同步引擎（加密）
└── utils/            # 工具函数
```

## 核心架构模式

1. **认证流程**: QR 码 + challenge-response（expo-camera）
2. **数据同步**: WebSocket 实时同步，自动重连，状态管理
3. **加密**: libsodium 端到端加密
4. **状态管理**: React Context（auth）、自定义 reducer（sync）
5. **实时语音**: LiveKit 集成
6. **平台适配**: web vs native 的独立实现

## 关键文件

- `sources/sync/types.ts` — 同步协议核心类型
- `sources/sync/reducer.ts` — 同步操作状态管理
- `sources/auth/AuthContext.tsx` — 认证状态
- `sources/app/_layout.tsx` — 根导航结构

## Custom Header

```tsx
import { NavigationHeader } from '@/components/Header';

// Stack 全局默认
<Stack screenOptions={{ header: NavigationHeader }}>

// 单个页面
<Stack.Screen name="settings" options={{
    header: NavigationHeader,
    headerTitle: 'Settings',
    headerSubtitle: 'Subtitle',  // 自定义扩展
}}/>
```

支持所有 React Navigation header 选项，额外支持 `headerSubtitle` 和 `headerSubtitleStyle`。
