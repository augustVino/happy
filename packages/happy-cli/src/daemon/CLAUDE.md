# Happy CLI Daemon

持久化后台进程，管理 Happy 会话、远程控制和自动更新。

## 1. Daemon 生命周期

### 启动 (`happy daemon start`)

1. `src/index.ts` 接收命令 → `spawnHappyCLI(['daemon', 'start-sync'], { detached: true })`
2. 新进程调用 `startDaemon()`（`src/daemon/run.ts`）:
   - 注册 shutdown 处理（SIGINT, SIGTERM, uncaughtException）
   - 版本检查: `isDaemonRunningSameVersion()` 对比 `daemon.state.json`
   - 版本不匹配 → `stopDaemon()` 杀旧进程
   - 同版本运行中 → 退出
   - 获取锁: `acquireDaemonLock()` O_EXCL 原子锁
   - 认证: `authAndSetupMachineIfNeeded()`
   - 写入 PID、版本、HTTP 端口到 `daemon.state.json`
   - 启动 HTTP 服务器（随机端口，127.0.0.1）
   - WebSocket 连接后端 (`ApiMachineClient`)
   - 注册 RPC: `spawn-happy-session`, `stop-session`, `requestShutdown`
   - 心跳循环: 每 60s 检查版本更新 + 清理死会话

### 关闭 (`happy daemon stop`)

1. `stopDaemon()` 读 `daemon.state.json`
2. HTTP POST `/stop` 优雅关闭
3. 失败则 `process.kill(pid, 'SIGKILL')`

### 版本不匹配自动更新

1. 心跳读取磁盘 `package.json` 版本
2. 版本不一致 → 生成新 daemon → 等待被杀
3. 新 daemon 发现旧 state 版本不匹配 → `stopDaemon()` → 接管

## 2. Session 管理

### Daemon 创建的会话（远程）
1. 后端转发 RPC `spawn-happy-session` → daemon WebSocket
2. `spawnSession()`: 创建目录 → detached spawn → 加入 `pidToTrackedSession` → 等 10s webhook
3. 新进程创建 session → POST `/session-started`
4. Daemon 更新 tracking → RPC 返回移动端

### 终端创建的会话
1. 用户运行 `happy` → 自动启动 daemon → `notifyDaemonSessionStarted()`
2. Daemon 创建 `TrackedSession`

### Session 终止
- RPC `stop-session` 或健康检查 → SIGTERM → `on('exit')` 移除 tracking

## 3. HTTP 控制服务器（127.0.0.1）

| 端点 | 说明 |
|------|------|
| `/session-started` | 会话自报告 webhook |
| `/list` | 返回追踪的会话列表 |
| `/stop-session` | 终止指定会话 |
| `/spawn-session` | 创建新会话（集成测试用） |
| `/stop` | 优雅关闭 daemon |

## 4. 进程发现与清理

### `happy doctor`
`ps aux | grep` 查找所有 Happy 进程，按命令参数分类：daemon、daemon-spawned、user-session、doctor

### `happy doctor clean`
`findRunawayHappyProcesses()` 过滤孤儿进程 → SIGTERM → 1s → SIGKILL

## 5. 状态持久化

### daemon.state.json
```json
{
  "pid": 12345,
  "httpPort": 50097,
  "startTime": "8/24/2025, 6:46:22 PM",
  "startedWithCliVersion": "0.9.0-6",
  "lastHeartbeat": "8/24/2025, 6:47:22 PM",
  "daemonLogPath": "/path/to/daemon.log"
}
```

### 锁文件
O_EXCL 原子创建，包含 PID，优雅关闭时释放。

## 6. WebSocket 通信

`ApiMachineClient` 双向通信：
- Daemon → Server: machine-alive, machine-update-metadata, machine-update-state
- Server → Daemon: rpc-request (spawn-happy-session, stop-session, requestShutdown)
- 所有数据 TweetNaCl 加密

## 7. 集成测试注意事项

版本不匹配测试模拟 npm upgrade:
- 修改 package.json + 重新构建
- 心跳间隔必须超过构建时间
- pkgroll 不更新编译产物，必须用 `yarn build`

## 详细文档

- [Machine Sync 架构](.claude/docs/machine-sync.md) — 数据结构、REST/WebSocket 协议、RPC 模式
