# HarmonyOS 适配方案

为 Happy Coder 项目新增鸿蒙原生客户端 (`packages/happy-harmony`) 的完整技术方案。

## 背景

当前项目移动端基于 React Native (Expo)，不支持鸿蒙系统。经调研，ArkTS 原生开发是鸿蒙适配的最优选择：
- 77% 的能力有原生 API 支持，无需三方库
- 华为官方维护，生态最确定
- 性能最优，无跨平台桥接开销

## 方案概览

### 架构

```
                          happy-server
                         /            \
              Socket.IO (现有)     WebSocket (新增)
                    /                   \
            happy-app (RN)        happy-harmony (ArkTS)
            Web / iOS / Android        鸿蒙 NEXT
                         \            /
                         happy-wire
                      (共享类型定义)
```

### 各包调整情况

| 包 | 调整类型 | 说明 |
|----|----------|------|
| `happy-wire` | 重构 | 统一类型定义，导出 JSON Schema |
| `happy-server` | 增强 | 添加原生 WebSocket 传输层 + 华为推送 |
| `happy-cli` | 无需调整 | 运行在电脑上，与客户端平台无关 |
| `happy-agent` | 无需调整 | 运行在电脑上，与客户端平台无关 |
| `happy-app` | 无需调整 | 现有 RN 客户端保持独立 |
| `happy-harmony` | 新增 | ArkTS 鸿蒙原生客户端 |

### 调整优先级

```
Phase 1  happy-wire 重构        — 基础层，其他工作依赖此步
Phase 2  happy-server WebSocket  — 通信层，鸿蒙客户端依赖此步
Phase 3  happy-harmony 客户端    — 从零构建 ArkTS 应用
Phase 4  华为推送 + 优化         — 锦上添花，非阻塞
```

## 文档目录

| 文档 | 说明 |
|------|------|
| [01-wire-refactor.md](./01-wire-refactor.md) | happy-wire 重构方案：统一类型、消除重复、导出 JSON Schema |
| [02-server-websocket.md](./02-server-websocket.md) | happy-server WebSocket 适配：双传输层架构设计 |
| [03-harmony-architecture.md](./03-harmony-architecture.md) | happy-harmony 客户端架构：模块划分、技术选型、目录结构 |
| [04-dependency-mapping.md](./04-dependency-mapping.md) | RN/Expo 依赖到 ArkTS 的完整映射表 |
| [05-protocol-spec.md](./05-protocol-spec.md) | WebSocket 通信协议规范（鸿蒙客户端专用） |

## 核心风险

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| Socket.IO 协议无法在鸿蒙原生使用 | 实时通信受阻 | 服务端新增原生 WebSocket 传输层 |
| LiveKit/WebRTC 无鸿蒙方案 | 实时音视频不可用 | 短期用 WebView 嵌入，长期等生态 |
| Zod 无法在 ArkTS 运行 | 数据验证缺失 | happy-wire 导出 JSON Schema 供 ArkTS 验证 |
| ArkTS 类型系统限制 | 部分 TS 模式不可用 | 适配时注意避免 `any`、受限装饰器等 |
