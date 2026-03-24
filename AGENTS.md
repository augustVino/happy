# Happy Coder

为 Codex 和 Codex 提供移动端和 Web 客户端，支持端到端加密。用户可在手机上远程控制本地运行的 AI 编码代理。

## Monorepo 结构

```
packages/
├── happy-app/      # React Native (Expo) + Web 客户端，含 Tauri macOS 桌面版
├── happy-cli/      # Node.js CLI 工具，包装 Codex/Codex
├── happy-agent/    # 远程代理控制 CLI
├── happy-server/   # Fastify 后端，加密同步 + Socket.IO 实时通信
└── happy-wire/     # 共享消息类型和 Zod schema（所有包的公共依赖）
```

## 常用命令

| 命令 | 说明 |
|------|------|
| `yarn install` | 安装所有依赖 |
| `yarn cli` | 从源码运行 CLI |
| `yarn web` | 启动 Web 客户端 |

## 全局约定

- **包管理器**: Yarn 1.22.22
- **缩进**: 4 空格
- **验证**: 统一使用 Zod
- **函数式风格**: 避免类，偏好函数和声明式模式
- **测试**: Vitest，`.spec.ts` 或 `.test.ts`，与源文件同目录

### Import 别名

| 包 | 别名 | 映射 |
|----|------|------|
| CLI | `@/` | `./src/` |
| App | `@/` | `./sources/` |
| Server | `@/` | `./sources/` |

## 子包详细指引

各子包有独立的 AGENTS.md，包含完整的开发指南：

- [happy-app](packages/happy-app/AGENTS.md) — Expo Router、Unistyles、i18n、组件规范
- [happy-cli](packages/happy-cli/AGENTS.md) — CLI 架构、Codex SDK 集成、daemon 生命周期
- [happy-server](packages/happy-server/AGENTS.md) — Fastify 路由、Prisma ORM、event bus、调试命令

## Patches

`patches/fix-pglite-prisma-bytes.cjs` — 修复 pglite-prisma-adapter 的 Bytes 列序列化问题，`postinstall` 时自动应用。
