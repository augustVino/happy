# HarmonyOS 独立开发方案

为 Happy Coder 项目独立开发鸿蒙原生客户端 (`packages/happy-harmony`)，功能与现有 RN 客户端完全对齐。

## 背景

当前移动端基于 React Native (Expo)，不支持鸿蒙系统。经调研，ArkTS 原生开发是鸿蒙适配的最优选择：
- 77% 的能力有原生 API 支持，无需三方库
- 华为官方维护，生态最确定
- 性能最优，无跨平台桥接开销

**关键决策**：不再维护 Android/iOS 版本，鸿蒙成为唯一的移动客户端。因此：
- **不重构**现有 happy-wire、happy-cli、happy-app、happy-server 代码
- Server 改动**纯新增**，零现有代码修改
- 鸿蒙 App 内自维护协议定义，不走 happy-wire
- 优先跑通核心流程，待优化项仅做备注

## 架构

```
                        happy-server
                       /            \
            Socket.IO (现有，不动)    WebSocket (新增，纯新增)
                  /                      \
          happy-app (RN/Web)        happy-harmony (ArkTS)
          Web 客户端，零改动            鸿蒙 NEXT，独立开发
                        \            /
                    happy-wire (不动)
```

### Server 改动范围

| 改动 | 文件 | 说明 |
|------|------|------|
| 新增 | `wsTransport.ts` | WebSocket 连接 + JWT 认证 + 消息分发 |
| 新增 | `wsHandlers.ts` | 业务 handler（从 socket handlers 复制核心逻辑） |
| 修改 | `main.ts` | 启动时挂载 WebSocket（+5 行） |
| 修改 | `package.json` | 添加 `ws` 依赖（+1 行） |

### 鸿蒙 App 模块结构

```
packages/happy-harmony/
├── entry/                    # 主模块（UIAbility 入口）
├── common/                   # 公共工具
│   └── crypto/               # libsodium NDK FFI 封装
├── network/                  # 网络通信
│   ├── api/                  # REST API 客户端
│   └── websocket/            # WebSocket 传输层
├── auth/                     # 认证模块
├── sync/                     # 数据同步引擎
├── encryption/               # 端到端加密
├── ui/                       # UI 界面
│   ├── components/           # 通用组件
│   ├── pages/                # 页面
│   ├── viewmodel/            # MVVM ViewModel
│   └── theme/                # 主题
└── services/                 # 平台服务
```

## 实施路线

```
Phase 0  加密 PoC (libsodium NDK)  — 唯一阻塞项
Phase 1  Server WebSocket 端点      — ~3 个新文件，1-2 天
Phase 2  鸿蒙 App 骨架 + 认证       — 项目初始化 + 登录
Phase 3  核心功能闭环               — 会话 + 聊天 + RPC 控制
Phase 4  功能补全                   — 逐个对齐现有 App
Phase 5  优化打磨                   — 性能、动画、无障碍
```

## 核心风险

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| libsodium NDK 编译失败 | 阻塞加密模块 | 评估 CryptoFramework + 协议升级备选方案 |
| ArkTS 类型系统限制 | 部分 TS 模式不可用 | 适配时避免 `any`、受限装饰器等 |
| LiveKit/WebRTC 无鸿蒙方案 | 实时语音不可用 | 短期用 WebView 嵌入，长期等生态 |
| 华为 IAP 替代 RevenueCat | 付费功能需重建 | 鸿蒙应用内支付 + 服务端桥接 |

## 文档目录

| 文档 | 说明 |
|------|------|
| [01-feature-parity.md](./01-feature-parity.md) | 功能对齐全景：现有 App 所有功能 + 优先级 + 鸿蒙实现方案 |
| [02-crypto-ndk.md](./02-crypto-ndk.md) | **Phase 0** 加密方案：libsodium NDK 移植 + FFI 集成 + PoC 验证 |
| [03-server-websocket.md](./03-server-websocket.md) | **Phase 1** Server 最小化 WebSocket 改造：纯新增，零重构 |
| [04-app-architecture.md](./04-app-architecture.md) | **Phase 2-3** 鸿蒙客户端架构：模块划分、技术选型、目录结构 |
| [05-protocol-spec.md](./05-protocol-spec.md) | WebSocket 通信协议规范（含完整事件契约） |
| [06-dependency-mapping.md](./06-dependency-mapping.md) | RN/Expo 依赖到 ArkTS 的完整映射表 |
| [07-core-flows.md](./07-core-flows.md) | 核心流程详解：认证、加密、数据同步、RPC |
| [08-roadmap.md](./08-roadmap.md) | 开发路线图：Phase 划分 + 里程碑 + 工作量估算 |
