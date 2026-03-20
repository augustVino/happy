# Machine Sync 架构

## 数据结构

```typescript
// 静态机器信息（极少变更）
interface MachineMetadata {
  host: string;              // hostname
  platform: string;          // darwin, linux, win32
  happyCliVersion: string;
  homeDir: string;
  happyHomeDir: string;
}

// 动态 daemon 状态（频繁更新）
interface DaemonState {
  status: 'running' | 'shutting-down' | 'offline';
  pid?: number;
  httpPort?: number;
  startedAt?: number;
  shutdownRequestedAt?: number;
  shutdownSource?: 'mobile-app' | 'cli' | 'os-signal' | 'unknown';
}
```

## 1. CLI 启动阶段

检查 machine ID 是否存在：
- 不存在 → 仅本地创建 ID（供 session 引用）
- 不在服务端创建 machine — 这是 daemon 的职责
- CLI 不管理 machine 详情，所有 API 和 schema 在 daemon 子包中

## 2. Daemon 启动 — 初始注册

### REST: `POST /v1/machines`

```json
{
  "id": "machine-uuid-123",
  "metadata": "base64(encrypted(MachineMetadata))",
  "daemonState": "base64(encrypted(DaemonState))"
}
```

响应包含 `metadataVersion` 和 `daemonStateVersion`。

## 3. WebSocket 连接与实时更新

```javascript
io(serverUrl, {
  auth: {
    token: "auth-token",
    clientType: "machine-scoped",
    machineId: "machine-uuid-123"
  }
})
```

心跳（每 20s）：`socket.emit('machine-alive', { machineId, time })`

## 4. Daemon 状态更新（WebSocket）

```json
socket.emit('machine-update-state', {
  "machineId": "...",
  "daemonState": "base64(encrypted(DaemonState))",
  "expectedVersion": 1
}, callback)
```

回调结果：`{ result: "success", version: 2 }` 或 `{ result: "version-mismatch", version: 3, daemonState: "..." }`

元数据更新（罕见）：`socket.emit('machine-update-metadata', { machineId, metadata, expectedVersion }, callback)`

## 5. 移动端 RPC 调用

```json
socket.emit('rpc-call', {
  "method": "machine-uuid-123:stop-daemon",
  "params": "base64(encrypted({ reason, force }))"
}, callback)
```

停止流程：daemon 收到 RPC → 更新状态为 `shutting-down` → 确认 → 清理 → 更新为 `offline`

## 6. 服务端广播

```json
socket.emit('update', {
  "id": "update-id",
  "seq": 456,
  "body": {
    "t": "update-machine",
    "id": "machine-uuid-123",
    "daemonState": { "value": "base64(...)", "version": 2 }
  },
  "createdAt": 1703001244567
})
```

## 7. REST: `GET /v1/machines/:id`

返回完整的 machine 信息，包含 metadata、daemonState 及其版本号。

## 设计决策

1. **关注点分离**: metadata（静态）vs daemonState（动态）
2. **独立版本控制**: 允许并发更新无冲突
3. **加密**: metadata 和 daemonState 分别加密
4. **RPC 模式**: machine 级 RPC 方法以 machineId 为前缀
