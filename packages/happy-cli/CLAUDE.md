# Happy CLI

命令行工具，包装 Claude Code 实现远程控制和会话共享。

## 三组件系统

1. **happy-cli**（本项目）— CLI wrapper
2. **happy** — React Native 移动客户端
3. **happy-server** — Node.js 服务端（https://api.happy-servers.com/）

## 命令

```bash
./bin/happy.mjs daemon start     # 启动 daemon
./bin/happy.mjs daemon stop      # 停止 daemon
./bin/happy.mjs daemon status    # 检查状态
happy doctor                     # 诊断
happy doctor clean               # 清理僵尸进程
```

本地开发: `HAPPY_SERVER_URL=http://localhost:3005 ./bin/happy.mjs daemon start`

Daemon 日志: `~/.happy-dev/logs/`，文件名格式 `YYYY-MM-DD-HH-MM-SS-daemon.log`

## 代码风格

- **严格类型**: 禁止无类型代码
- **函数式风格**: 尽量少用类
- **Import**: `@/` 别名 → `./src/`，所有 import 在文件顶部
- **导出**: 命名导出优先
- **避免**: 过度 if 分支、细碎的 getter/setter
- **错误处理**: try-catch + 具体日志，AbortController 管理可取消操作
- **日志**: 调试日志写入文件（不干扰 Claude 会话），控制台仅输出用户消息
- **测试**: Vitest，不 mock（真实 API 调用），`.test.ts` 与源文件同目录

## 架构

### API 模块 (`/src/api/`)
服务端通信和加密：
- `api.ts` — 会话管理 API 客户端
- `apiSession.ts` — WebSocket 实时会话 + RPC
- `auth.ts` — TweetNaCl 签名认证
- `encryption.ts` — 端到端加密
- `types.ts` — Zod schema

### Claude 集成 (`/src/claude/`)
- `loop.ts` — 主控制循环（交互/远程模式）
- `claudeSdk.ts` — SDK 直接集成（`@anthropic-ai/claude-code`）
- `interactive.ts` — PTY 交互模式（可能废弃，改用 SDK）
- `watcher.ts` — 文件系统监控
- `mcp/startPermissionServer.ts` — MCP 权限服务器

### UI 模块 (`/src/ui/`)
- `logger.ts` — 集中式文件日志
- `qrcode.ts` — QR 码生成
- `start.ts` — 启动和编排

### 数据流
1. **认证**: 生成密钥 → challenge-response → auth token
2. **Session 创建**: 加密会话 → WebSocket 连接
3. **消息流**:
   - 交互模式: 用户输入 → PTY → Claude → 文件监控 → 服务端
   - 远程模式: 移动端 → 服务端 → Claude SDK → 服务端 → 移动端
4. **权限**: Claude 请求 → MCP 拦截 → 发送到移动端 → 审批 → 放行/拒绝

## 安全

- 私钥存储 `~/.handy/access.key`（受限权限）
- TweetNaCl 加密所有通信
- challenge-response 防重放攻击
- Session 隔离

## 详细文档

- [Session Forking 行为](.claude/docs/session-forking.md) — `--resume` 的 session ID 重写机制
- [Daemon 控制流](src/daemon/CLAUDE.md) — daemon 生命周期、进程管理、RPC 协议
