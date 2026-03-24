# HarmonyOS 开发计划修订实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修订 `docs-harmony/develop/2026-03-23-harmony-phased-development-plan.md`，新增 Phase -1、调整依赖链、标记 Phase 1 状态、更新里程碑，使其反映设计文档 `docs/superpowers/specs/2026-03-24-harmony-plan-revision-design.md` 中的决策。

**Architecture:** 直接编辑原计划文件，逐段应用修订。保留原文结构和风格，仅修改需要变更的部分。所有编辑操作使用包含足够上下文的 `old_string` 确保唯一匹配。

**Tech Stack:** Markdown 文档编辑。

**Spec:** `docs/superpowers/specs/2026-03-24-harmony-plan-revision-design.md`

---

## 文件清单

| 文件 | 操作 |
|------|------|
| `docs-harmony/develop/2026-03-23-harmony-phased-development-plan.md` | 修改（全部变更集中于此） |

---

### Task 1: 更新计划头部（Goal + SDK 决策）

- [ ] **Step 1: 更新 Goal 行**

old_string:
```
**Goal:** 为 `packages/happy-harmony` 建立可落地的鸿蒙原生客户端，并按依赖关系逐阶段完成加密、服务端 WebSocket、认证、核心闭环、功能补全与优化。
```

new_string:
```
**Goal:** 为 `packages/happy-harmony` 建立可落地的鸿蒙原生客户端，并按依赖关系逐阶段完成环境准备、加密、认证、核心闭环、功能补全与优化。

**Target SDK:** HarmonyOS NEXT（纯血鸿蒙），API 12+。目标上架华为应用市场（AppGallery）。DevEco Studio 5.0+。不考虑跨平台复用。
```

- [ ] **Step 2: 验证**

确认文件头部包含 Goal、Target SDK、Architecture、Tech Stack 四个段落。

---

### Task 2: 更新计划总览表

- [ ] **Step 1: 替换整个总览表**

old_string:
```
| Phase | 名称 | 目标 | 依赖 | 交付物 |
|------|------|------|------|------|
| 0 | 加密 PoC | 让鸿蒙端能完成与现有 CLI/App 一致的加密/解密与认证 | 无 | libsodium FFI、SodiumCrypto、认证 PoC |
| 1 | Server WebSocket | 给鸿蒙客户端提供独立 WebSocket 端点 | Phase 0 的加密验证结果 | `wsTransport.ts`、`wsHandlers.ts`、`main.ts` 挂载 |
| 2 | 客户端骨架 + 认证 | 搭起鸿蒙项目、登录、恢复、密钥持久化 | Phase 0 + Phase 1 | 可启动、可登录、可恢复账户的 App |
| 3 | 核心功能闭环 | 打通会话列表、消息同步、聊天、RPC、新建会话 | Phase 2 | 最小可用版本（MVP） |
| 4 | 功能补全 | 对齐 RN 客户端的 P1 / P2 功能 | Phase 3 | 功能完整的鸿蒙客户端 |
| 5 | 优化打磨 | 做性能、体验、可维护性收口 | Phase 4 | 稳定版优化清单与修复 |
```

new_string:
```
| Phase | 名称 | 目标 | 依赖 | 交付物 |
|------|------|------|------|------|
| -1 | 环境准备 | 搭建鸿蒙工程骨架，验证构建链路 | 无 | 可构建的鸿蒙工程、模块骨架 |
| 0 | 加密 PoC | 让鸿蒙端能完成与现有 CLI/App 一致的加密/解密与认证 | Phase -1 | libsodium FFI、SodiumCrypto、认证 PoC |
| 1 | Server WebSocket | ~~给鸿蒙客户端提供独立 WebSocket 端点~~ (已完成) | 已完成 (463523f6) | `wsTransport.ts`、`wsHandlers.ts`、`api.ts` 挂载 |
| 2 | 客户端骨架 + 认证 | 搭起鸿蒙项目、登录、恢复、密钥持久化 | Phase 0 | 可启动、可登录、可恢复账户的 App |
| 3 | 核心功能闭环 | 打通会话列表、消息同步、聊天、RPC、新建会话 | Phase 2 | 最小可用版本（MVP） |
| 4 | 功能补全 | 对齐 RN 客户端的 P1 / P2 功能 | Phase 3 | 功能完整的鸿蒙客户端 |
| 5 | 优化打磨 | 做性能、体验、可维护性收口 | Phase 4 | 稳定版优化清单与修复 |
```

- [ ] **Step 2: 验证总览表**

确认 7 行（Phase -1 到 5），Phase 1 标记已完成，Phase 2 依赖仅为 Phase 0。

---

### Task 3: 新增 Phase -1 完整章节

- [ ] **Step 1: 在 Phase 0 标题前插入 Phase -1 章节**

old_string:
```
## Phase 0: 加密 PoC
```

new_string:
```
## Phase -1: 环境准备

**目标**

搭建可构建、可运行的鸿蒙项目骨架，为后续所有开发提供基础。

**进入条件**

- 无（起点）

**完成标准**

- DevEco Studio ≥ 5.0，HarmonyOS NEXT SDK API 12+ 已安装。
- `packages/happy-harmony/` 可在 DevEco Studio 中打开并构建成功。
- 模块结构对齐 `docs-harmony/prd/04-app-architecture.md` 分层设计。
- ohpm 依赖声明完成。

### 任务拆分

1. 确认 DevEco Studio 版本和 HarmonyOS NEXT SDK API 版本。
2. 在 DevEco Studio 中创建 HarmonyOS 工程（Stage 模型，ArkTS 语言）。
3. 按目录规范创建模块结构（entry、common、network、auth、sync、encryption、rpc、ui、services）。
4. 配置 `build-profile.json5`（编译参数、签名配置）。
5. 配置 `oh-package.json5`（ohpm 依赖声明）。
6. 配置 `module.json5`（应用权限：网络、数据存储）。
7. 创建各模块入口文件（空占位，确保构建通过）。
8. 验证工程在 DevEco Studio 中可构建、可预览。

### 产出文件

- `packages/happy-harmony/` 完整工程目录。
- `build-profile.json5`、`oh-package.json5`、`module.json5`。
- 各模块入口占位文件。

### 验收方式

- `hvigorw assembleHap` 构建成功。
- DevEco Studio Previewer 可预览空页面。

---

## Phase 0: 加密 PoC
```

- [ ] **Step 2: 验证章节结构**

确认 Phase -1 章节格式与其它 Phase 一致，`---` 分隔线正确。

---

### Task 4: 更新 Phase 0 进入条件和任务 1

- [ ] **Step 1: 替换 Phase 0 进入条件**

old_string:
```
**进入条件**

- 已确认鸿蒙 NDK / ArkTS FFI 的构建方式。
- 已能定位到 libsodium 的编译产物路径和加载路径。
```

new_string:
```
**进入条件**

- Phase -1 完成（工程可构建，NDK 编译链已验证可用）。
```

- [ ] **Step 2: 更新 Phase 0 任务 1**

old_string:
```
1. 搭建鸿蒙 NDK / CMake 编译链，产出 `libsodium.so`。
```

new_string:
```
1. 在已有鸿蒙工程中配置 CMakeLists.txt，将 libsodium 编译为 `libsodium.so`。
```

- [ ] **Step 3: 验证**

确认 Phase 0 进入条件引用 Phase -1，任务 1 描述已更新。

---

### Task 5: 更新 Phase 1 为已完成状态

- [ ] **Step 1: 更新 Phase 1 标题**

old_string:
```
## Phase 1: Server WebSocket
```

new_string:
```
## Phase 1: Server WebSocket（已完成）
```

- [ ] **Step 2: 替换 Phase 1 进入条件**

old_string:
```
**进入条件**

- Phase 0 已证明认证与加密基础可用。
- 已确认协议帧格式与 `docs-harmony/prd/05-protocol-spec.md` 一致。
```

new_string:
```
**进入条件**

~~- Phase 0 已证明认证与加密基础可用。~~
~~- 已确认协议帧格式与 `docs-harmony/prd/05-protocol-spec.md` 一致。~~

> 此阶段已通过 commit `463523f6` 完成。进入条件不再适用。
```

- [ ] **Step 3: 替换 Phase 1 完成标准**

old_string:
```
**完成标准**

- WebSocket 可以建立连接并通过 JWT 认证。
- 支持 ping、push、request/response、RPC 调用。
- 现有 Web 客户端不受影响。
- 鸿蒙客户端能完成基本连接、收发消息和 RPC 互通。
```

new_string:
```
**完成标准对照**

| 完成标准 | 状态 |
|---------|------|
| WebSocket 可以建立连接并通过 JWT 认证 | ✓ 服务端已实现 |
| 支持 ping、push、request/response、RPC 调用 | ✓ 服务端已实现 |
| 现有 Web 客户端不受影响 | 待 Phase 3 前验证 |
| 鸿蒙客户端能完成基本连接、收发消息和 RPC 互通 | 延后至 Phase 3 任务 11 |
```

- [ ] **Step 4: 替换 Phase 1 任务拆分为已完成清单**

old_string:
```
### 任务拆分

1. 新增 WebSocket 传输层，复用现有认证与鉴权思路。
2. 新增消息分发与 ACK 处理。
3. 从现有 socket 处理逻辑中提取核心业务 handler。
4. 在 `main.ts` 挂载 WebSocket 路由。
5. 增加 `ws` 依赖并验证启动流程。
6. 用最小客户端脚本验证连接、心跳、消息、RPC。
```

new_string:
```
### 已完成清单

- [x] 新增 WebSocket 传输层（`wsTransport.ts`）。
- [x] 新增消息分发与 ACK 处理（`wsAdapters.ts`，原计划未提及）。
- [x] 从现有 socket 处理逻辑中提取核心业务 handler（`wsHandlers.ts`）。
- [x] 在 `api.ts` 挂载 WebSocket 路由。
- [x] 增加 `ws` 依赖（`ws@^8.18.0`、`@types/ws@^8.5.13`）。
- [ ] 用最小客户端脚本验证连接、心跳、消息、RPC → 延后至 Phase 3 任务 11。
```

- [ ] **Step 5: 替换 Phase 1 产出文件**

old_string:
```
### 产出文件

- `packages/happy-server/sources/app/api/wsTransport.ts`
- `packages/happy-server/sources/app/api/wsHandlers.ts`
- `packages/happy-server/sources/main.ts`
- `packages/happy-server/package.json`
```

new_string:
```
### 产出文件

- `packages/happy-server/sources/app/api/wsTransport.ts` ✓
- `packages/happy-server/sources/app/api/wsHandlers.ts` ✓
- `packages/happy-server/sources/app/api/wsAdapters.ts` ✓（额外交付）
- `packages/happy-server/sources/app/api/api.ts` ✓（挂载点）
- `packages/happy-server/package.json` ✓
```

- [ ] **Step 6: 替换 Phase 1 验收方式并添加风险提示**

old_string:
```
### 验收方式

- 启动后能在鸿蒙端连上 `/v1/ws`。
- 消息推送与 RPC 响应都能返回正确 ACK。
- 回归现有 Socket.IO 路径无异常。
```

new_string:
```
### 验收方式

- ~~启动后能在鸿蒙端连上 `/v1/ws`。~~ → 延后至 Phase 3 任务 11
- 消息推送与 RPC 响应都能返回正确 ACK（服务端已实现，待客户端联调验证）。
- 回归现有 Socket.IO 路径无异常 → 待 Phase 3 前验证。

**风险提示**

服务端 WebSocket 的 bug 可能要到 Phase 3 集成联调时才会暴露。建议在 Phase 3 开始前用简单脚本快速验证 WebSocket 端点可达性。
```

- [ ] **Step 7: 验证**

确认 Phase 1 整体标记为已完成，产出文件与实际文件匹配，验收方式明确标注延后项。

---

### Task 6: 更新 Phase 2 进入条件和任务

- [ ] **Step 1: 替换 Phase 2 进入条件**

old_string:
```
**进入条件**

- Phase 0 完成并可稳定复现。
- Phase 1 提供可用的 WebSocket 服务端入口。
```

new_string:
```
**进入条件**

- Phase 0 完成并可稳定复现。
```

- [ ] **Step 2: 标记 Phase 2 已在 Phase -1 完成的任务**

old_string:
```
1. 初始化 `packages/happy-harmony` 工程与模块结构。
2. 对齐 `docs-harmony/prd/04-app-architecture.md` 的目录分层。
```

new_string:
```
1. ~~初始化 `packages/happy-harmony` 工程与模块结构。~~ → 已在 Phase -1 完成。
2. ~~对齐 `docs-harmony/prd/04-app-architecture.md` 的目录分层。~~ → 已在 Phase -1 完成。
```

- [ ] **Step 3: 验证**

确认 Phase 2 仅依赖 Phase 0，任务 1-2 标记为已完成。

---

### Task 7: 更新 Phase 3 任务拆分

- [ ] **Step 1: 在 Phase 3 任务列表末尾新增任务 11**

old_string:
```
10. 实现 `NewSessionPage`、`PickMachinePage`、`PickPathPage`。
```

new_string:
```
10. 实现 `NewSessionPage`、`PickMachinePage`、`PickPathPage`。
11. WebSocket 集成验证：用真实鸿蒙客户端验证连接、心跳、消息、RPC 互通（原 Phase 1 任务 6）。
```

- [ ] **Step 2: 验证**

确认 Phase 3 任务列表包含 11 项。

---

### Task 8: 更新里程碑表

- [ ] **Step 1: 在 M0 行前插入新里程碑并更新 M1、M3**

old_string:
```
| M0 | libsodium 构建成功，FFI 可调用 |
| M1 | Ed25519 签名与现有实现一致 |
| M2 | 真实账户可登录并拉取会话列表 |
| M3 | WebSocket 端点可连接并收发消息 |
```

new_string:
```
| M-new-1 | DevEco Studio 构建成功，空 Hap 可预览 |
| M-new-2 | libsodium.so 加载成功，sodium_init() 通过 |
| M0 | libsodium 构建成功，FFI 可调用 |
| M1 | 在已有鸿蒙工程中完成，Ed25519 签名一致 |
| M2 | 真实账户可登录并拉取会话列表 |
| M3 | ~~WebSocket 端点可连接并收发消息~~ (已完成) |
```

- [ ] **Step 2: 验证**

确认里程碑表包含 M-new-1、M-new-2，M1 和 M3 已更新。

---

### Task 9: 更新推荐实施顺序和备注

- [ ] **Step 1: 替换推荐实施顺序**

old_string:
```
1. 先做 Phase 0，直到加密 PoC 稳定。
2. 立刻做 Phase 1，给鸿蒙端准备独立传输通道。
3. 再做 Phase 2，把"能登录"变成产品起点。
4. 然后做 Phase 3，优先完成真实可用闭环。
5. 最后按 P1 -> P2 补齐功能，再做体验优化。
```

new_string:
```
1. 先做 Phase -1，搭建鸿蒙工程骨架并验证构建链路。
2. 再做 Phase 0，直到加密 PoC 稳定。
3. Phase 1 已完成，跳过。
4. 再做 Phase 2，把"能登录"变成产品起点。
5. 然后做 Phase 3，优先完成真实可用闭环（含 WebSocket 集成验证）。
6. 最后按 P1 -> P2 补齐功能，再做体验优化。
```

- [ ] **Step 2: 在备注末尾追加 SDK 决策和 Phase 1 状态**

old_string:
```
- 若后续需要进一步拆成周计划或任务卡，可以在 `docs-harmony/develop/` 下继续追加更细的执行文档。
```

new_string:
```
- 若后续需要进一步拆成周计划或任务卡，可以在 `docs-harmony/develop/` 下继续追加更细的执行文档。
- Phase 1 (Server WebSocket) 已通过 commit `463523f6` 完成服务端实现，客户端验证延后至 Phase 3。
- SDK 选型确定为 HarmonyOS NEXT API 12+（纯血鸿蒙），不使用 OpenHarmony。
```

- [ ] **Step 3: 验证**

确认实施顺序包含 6 步，备注包含 SDK 决策和 Phase 1 状态。

---

### Task 10: 提交

- [ ] **Step 1: 检查完整修改**

Review 最终文件，逐 Phase 确认所有变更与设计文档一致。

- [ ] **Step 2: 提交**

```bash
git add docs-harmony/develop/2026-03-23-harmony-phased-development-plan.md
git commit -m "docs(harmony): revise phased development plan

- Add Phase -1 for environment preparation
- Confirm HarmonyOS NEXT SDK API 12+
- Mark Phase 1 (Server WebSocket) as completed
- Update Phase 0 entering conditions to reference Phase -1
- Remove Phase 1 dependency from Phase 2
- Add WebSocket integration verification task to Phase 3
- Update milestones and recommended execution order"
```
