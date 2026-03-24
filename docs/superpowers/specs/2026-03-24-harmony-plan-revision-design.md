# HarmonyOS 开发计划修订设计

## 背景

原计划 `docs-harmony/develop/2026-03-23-harmony-phased-development-plan.md` 存在执行顺序问题：缺少鸿蒙项目初始化步骤，导致加密 PoC 无工程载体；SDK 选型未明确；Phase 1 Server WebSocket 已完成但未标记。

## 决策

### SDK 选型

**HarmonyOS NEXT（纯血鸿蒙），SDK API 12+。**

- 目标上架华为应用市场（AppGallery）
- 使用原生 ArkTS / ArkUI
- DevEco Studio 5.0+
- 可使用华为专有 API（`@ohos.security.cryptoFramework` 等）
- 不考虑跨平台复用

### 修订方案

保留原有 6 阶段框架，前置插入 Phase -1，调整依赖关系。

## 修订后的阶段依赖链

```
Phase -1 (环境准备)
    ↓
Phase 0 (加密 PoC)
    ↓
Phase 2 (骨架 + 认证)      Phase 1 (已完成 ✓)
    ↓
Phase 3 (核心功能闭环)
    ↓
Phase 4 (功能补全)
    ↓
Phase 5 (优化打磨)
```

## Phase -1：环境准备（新增）

**目标**：搭建可构建、可运行的鸿蒙项目骨架。

**进入条件**：无（起点）

**完成标准**：

- DevEco Studio ≥ 5.0，HarmonyOS NEXT SDK API 12+ 已安装
- `packages/happy-harmony/` 可在 DevEco Studio 中打开并构建成功
- 模块结构对齐 `04-app-architecture.md` 分层设计
- ohpm 依赖声明完成

**任务拆分**：

1. 确认 DevEco Studio 版本和 HarmonyOS NEXT SDK API 版本
2. 在 DevEco Studio 中创建 HarmonyOS 工程（Stage 模型，ArkTS 语言）
3. 按目录规范创建模块结构（entry、common、network、auth、sync、encryption、rpc、ui、services）
4. 配置 `build-profile.json5`（编译参数、签名配置）
5. 配置 `oh-package.json5`（ohpm 依赖声明）
6. 配置 `module.json5`（应用权限、网络、数据存储权限声明）
7. 创建各模块入口文件（空占位，确保构建通过）
8. 验证工程在 DevEco Studio 中可构建、可预览

**产出文件**：

- `packages/happy-harmony/` 完整工程目录
- `build-profile.json5`、`oh-package.json5`、`module.json5`
- 各模块入口占位文件

**验收方式**：

- `hvigorw assembleHap` 构建成功
- DevEco Studio Previewer 可预览空页面

## Phase 0：加密 PoC（修订）

**目标**：在已有鸿蒙工程中验证密码学操作的可行性。

**进入条件**：Phase -1 完成（工程可构建）

**完成标准**（无变化）：

- libsodium NDK 构建成功，`.so` 可被鸿蒙应用加载
- Ed25519 签名结果与现有 CLI/App 一致
- `crypto_box` / `crypto_secretbox` 加解密兼容
- 能完成 challenge-response 认证 PoC

**任务拆分调整**：

- ~~任务 1：搭建鸿蒙 NDK / CMake 编译链~~ → 在已有工程中配置 CMakeLists.txt
- 任务 2-7：与原计划一致

**关键变化**：原计划任务 1（搭建编译链）简化为在已有工程中配置 CMake。

## Phase 1：Server WebSocket（标记已完成）

**状态**：已完成，跳过。

commit `463523f6` 已交付全部计划产出物：

| 计划产出 | 实际文件 |
|---------|---------|
| `wsTransport.ts` | `packages/happy-server/sources/app/api/wsTransport.ts` (275 行) |
| `wsHandlers.ts` | `packages/happy-server/sources/app/api/wsHandlers.ts` (384 行) |
| `main.ts` 挂载 | `packages/happy-server/sources/app/api/api.ts` (+3 行) |
| `package.json` 依赖 | `ws@^8.18.0`, `@types/ws@^8.5.13` |

**补充**：

- 额外交付 `wsAdapters.ts`（201 行），原计划未提及
- 客户端验证脚本移至 Phase 3 WebSocket 集成测试

## Phase 2：客户端骨架 + 认证（修订）

**进入条件调整**：仅依赖 Phase 0（移除 Phase 1 依赖）。

**任务拆分调整**：

- ~~任务 1：初始化工程与模块结构~~ → 已在 Phase -1 完成
- ~~任务 2：对齐目录分层~~ → 已在 Phase -1 完成
- 任务 3-9：与原计划一致

**完成标准、产出文件**：与原计划一致。

## Phase 3：核心功能闭环（修订）

**进入条件**：Phase 2 完成（无变化）。

**完成标准**：与原计划一致。

**任务拆分调整**：

- 任务 1-10：与原计划一致
- 新增任务 11：WebSocket 集成验证（原 Phase 1 的客户端验证脚本，在此与真实鸿蒙客户端联调完成）

**产出文件**：与原计划一致。

## Phase 4 & Phase 5：无调整

与原计划完全一致。

## 里程碑调整

| 新增/调整 | 判定条件 |
|-----------|---------|
| M-new-1 | DevEco Studio 构建成功，空 Hap 可预览 |
| M-new-2 | libsodium.so 加载成功，sodium_init() 通过 |
| M1 (调整) | 在已有鸿蒙工程中完成，Ed25519 签名一致 |
| M3 | 已完成（WebSocket 端点已实现） |

## 变更清单总览

| 变更 | 类型 | 影响 |
|------|------|------|
| 新增 Phase -1 环境准备 | 新增 | 新阶段 |
| SDK 确定为 HarmonyOS NEXT API 12+ | 决策 | 全局 |
| Phase 0 任务 1 简化 | 调整 | Phase 0 |
| Phase 1 标记已完成 | 状态 | Phase 1 |
| Phase 2 移除 Phase 1 依赖 | 调整 | Phase 2 |
| Phase 3 新增集成验证任务 | 补充 | Phase 3 |
| Phase 4、5 无变化 | - | - |
