# 核心流程详解

> 认证、密钥推导、端到端加密、数据同步、RPC 的完整实现参考

## 一、认证流程

### 1.1 创建账户

```
用户                          鸿蒙客户端                         服务端
  │                               │                                 │
  │  点击"创建账户"               │                                 │
  │─────────────────────────────>│                                 │
  │                               │                                 │
  │                               │ 1. randomBytes(32) → secret    │
  │                               │ 2. signKeyPairFromSeed(secret) │
  │                               │    → publicKey, secretKey       │
  │                               │ 3. randomBytes(32) → challenge │
  │                               │ 4. signDetached(challenge, sk) │
  │                               │    → signature                 │
  │                               │                                 │
  │                               │  POST /v1/auth                  │
  │                               │  { publicKey, challenge,       │
  │                               │    signature }                  │
  │                               │───────────────────────────────>│
  │                               │                                 │
  │                               │  ← JWT token                   │
  │                               │                                 │
  │                               │ 5. SecureStore.save(           │
  │                               │       token, base64url(secret)) │
  │                               │ 6. SyncEngine.init()           │
  │                               │                                 │
  │  显示会话列表                 │                                 │
  │<─────────────────────────────│                                 │
```

**参考文件**：`app/sources/auth/authChallenge.ts` (7 行)、`app/sources/auth/authGetToken.ts`

**鸿蒙实现要点**：
- `randomBytes(32)` → `SodiumCrypto.randomBytes(32)`
- `signKeyPairFromSeed` → `SodiumCrypto.signKeyPairFromSeed(seed)`
- `signDetached` → `SodiumCrypto.signDetached(challenge, secretKey)`
- 凭据存储 → `@ohos.data.relationalStore` (加密模式) 或 `@ohos.data.preferences`

### 1.2 恢复账户（QR 码）

```
设备 A (已登录)                设备 B (鸿蒙，新设备)              服务端
  │                                │                               │
  │                                │ 1. 生成临时 X25519 keypair    │
  │                                │ 2. POST /v1/auth/account/      │
  │                                │    request { publicKey }       │
  │                                │─────────────────────────────>│
  │                                │  ← { state: "requested" }     │
  │                                │                               │
  │                                │ 3. 显示 QR 码（含公钥）       │
  │  扫描 QR 码                   │                               │
  │<──────────────────────────────│                               │
  │                                │                               │
  │ 4. 用用户的 contentKeyPair      │                               │
  │    加密用户的 master secret    │                               │
  │ 5. POST /v1/auth/account/      │                               │
  │    response { publicKey,       │                               │
  │    response }                  │                               │
  │────────────────────────────────>│                               │
  │                                │                               │
  │                                │ 6. 轮询 POST /v1/auth/account/ │
  │                                │    request                     │
  │                                │  ← { state: "authorized",      │
  │                                │       response: "encrypted" }  │
  │                                │                               │
  │                                │ 7. boxDecrypt(response,       │
  │                                │    tempSecretKey) → secret     │
  │                                │ 8. authGetToken(secret)        │
  │                                │    → JWT token                 │
```

**关键**：步骤 4 中设备 A 用 `crypto_box_easy(secret, nonce, deviceBPublicKey, userSecretKey)` 加密。设备 B 用 `crypto_box_open_easy(response, nonce, deviceBPublicKey, deviceBSecretKey)` 解密。

### 1.3 恢复账户（手动输入密钥）

```
用户输入密钥 "XXXXX-XXXXX-..." → Base32 解码 → Ed25519 签名认证 → JWT token
```

纯算法实现，无外部依赖。

## 二、密钥推导

### 2.1 密钥层级

```
Master Secret (32 bytes, 用户创建账户时生成)
  │
  ├─ crypto_sign_seed_keypair(secret)
  │   → Ed25519 keypair
  │     → publicKey: 认证身份（存入数据库）
  │     → secretKey: 签名用
  │
  ├─ deriveKey('Happy EnCoder', ['content'])  → contentSeed (32 bytes)
  │   │
  │   └─ crypto_box_seed_keypair(contentSeed)
  │       → X25519 contentKeyPair
  │         → publicKey: 用于解密 Data Encryption Key
  │         → secretKey: 用于解密 Data Encryption Key
  │
  └─ deriveKey('Happy Coder', ['analytics', 'id']) → anonID (匿名统计)
```

### 2.2 deriveKey 实现

```typescript
// 从 app/sources/encryption/deriveKey.ts 移植
// 使用 libsodium 的 crypto_kdf_derive_from_key 或 HMAC-SHA512

function deriveKey(masterSecret: Uint8Array, context: string[]): Uint8Array {
  // HMAC-SHA512 迭代派生
  const key = masterSecret
  for (const part of context) {
    const hmac = crypto.createHmac('sha512', key)
    hmac.update(part)
    key = hmac.digest()
  }
  return key.slice(0, 32)
}
```

## 三、端到端加密

### 3.1 两种加密变体

**Legacy (SecretBox)**：
```
加密: nonce(24) + secretbox(plaintext, nonce, masterSecret)
解密: nonce = ciphertext[0:24], secretbox_open(ciphertext[24:], nonce, key)
```

**DataKey (AES-256-GCM)**：
```
加密: version(1, 0x00) + nonce(12) + aes_gcm(plaintext, nonce, key) + tag(16)
解密: version = ciphertext[0], nonce = ciphertext[1:13], tag = ciphertext[-16:]
```

### 3.2 Data Encryption Key (DEK) 生命周期

```
创建会话时:
  1. 随机生成 DEK (32 bytes)
  2. 用 contentKeyPair 加密: boxEncrypt(DEK, nonce, serverPublicKey, contentSecretKey)
  3. Bundle: version(1) + ephemeralPublicKey(32) + nonce(24) + ciphertext
  4. 存储到服务端 session.dataEncryptionKey

读取会话时:
  1. 从服务端获取加密的 DEK
  2. 解密: boxDecrypt(bundle, contentPublicKey, contentSecretKey)
  3. 用 DEK 初始化 SessionEncryption
```

### 3.3 消息加密/解密

```
发送消息:
  RawRecord → SessionEncryption.encrypt(rawRecord) → base64 → POST /v3/messages

接收消息:
  base64 → SessionEncryption.decrypt(encrypted) → RawRecord → UI 渲染

SessionEncryption 内部:
  - 有 DEK → AES-256-GCM (dataKey variant)
  - 无 DEK → NaCl SecretBox (legacy variant)
```

### 3.4 SessionEnvelope 结构

每条消息是 `SessionEnvelope`：

```typescript
{
  id: string,          // cuid2
  time: number,        // Date.now() 毫秒时间戳
  role: 'user' | 'agent',
  turn?: string,       // turn ID
  subagent?: string,   // subagent ID
  ev: SessionEvent     // 事件类型
}
```

**事件类型**：

| ev | 说明 | 来源 |
|----|------|------|
| `text` | 文本消息（可含 `thinking: true`） | user / agent |
| `service` | 服务消息 | agent |
| `tool-call-start` | 工具调用开始 | agent |
| `tool-call-end` | 工具调用完成 | agent |
| `file` | 文件引用 | agent |
| `turn-start` | Turn 开始 | agent |
| `start` | 会话/子代理开始 | agent |
| `turn-end` | Turn 结束 | agent |
| `stop` | 会话/子代理停止 | agent |

## 四、数据同步

### 4.1 初始数据拉取

```
SyncEngine.init()
  │
  ├─ 并行拉取:
  │   ├─ GET /v1/sessions         → 会话列表
  │   ├─ GET /v1/machines         → 机器列表
  │   ├─ GET /v1/account/profile  → 用户资料
  │   ├─ GET /v1/artifacts        → Artifact 列表
  │   ├─ GET /v1/friends          → 好友列表
  │   ├─ GET /v1/kv?prefix=       → KV 存储
  │   └─ GET /v1/feed             → Feed 动态
  │
  ├─ 初始化加密:
  │   ├─ 从 SecureStore 读取 master secret
  │   ├─ 推导 contentKeyPair
  │   └─ 解密所有 session/machine 的 DEK
  │
  └─ 标记 isDataReady = true
```

### 4.2 实时同步

```
WebSocket 连接 (user-scoped)
  │
  ├─ 收到 update { type: "new-message" }
  │   └─ 检查 seq 连续性:
  │       ├─ 连续 → 直接入队（不重新拉取）
  │       └─ 不连续 → 重新 GET /v3/messages?after_seq=lastSeq
  │
  ├─ 收到 update { type: "new-session" }
  │   └─ 重新 GET /v1/sessions
  │
  ├─ 收到 update { type: "update-session" }
  │   └─ 更新本地 session 数据
  │
  ├─ 收到 update { type: "delete-session" }
  │   └─ 清理本地 session + messages
  │
  ├─ 收到 ephemeral { type: "activity" }
  │   └─ 更新会话 thinking/active 状态
  │
  └─ 收到 ephemeral { type: "machine-activity" }
      └─ 更新机器在线/离线状态
```

### 4.3 消息发送

```
用户输入文本
  │
  ├─ 构建 RawRecord { role: "user", ev: "text", ... }
  ├─ SessionEncryption.encrypt(rawRecord) → encrypted
  ├─ 添加到 pendingOutbox
  ├─ POST /v3/sessions/:id/messages
  │   { messages: [{ localId, content: base64(encrypted) }] }
  └─ 成功 → 从 outbox 移除
      失败 → 重试（指数退避）
```

### 4.4 断线重连

```
WebSocket 断开
  │
  ├─ 指数退避重连 (1s, 2s, 4s, 8s, 30s max)
  │
  └─ 重连成功后全量刷新:
      ├─ 重新拉取 sessions, machines, artifacts, friends, feed
      ├─ 重新拉取所有已加载 session 的 messages
      └─ 重新发送 pendingOutbox 中的消息
```

## 五、RPC 调用

### 5.1 可用 RPC 方法

**会话级**（`{sessionId}:methodName`）：

| 方法 | 请求 | 响应 | 说明 |
|------|------|------|------|
| `abort` | `{}` | `void` | 中止当前操作 |
| `allow` | `{ id, mode }` | `void` | 批准权限请求 |
| `deny` | `{ id }` | `void` | 拒绝权限请求 |
| `switch` | `{ mode }` | `void` | 切换远程/本地模式 |
| `bash` | `{ command, cwd?, timeout? }` | `{ success, stdout?, stderr?, exitCode? }` | 远程 Bash |
| `readFile` | `{ path }` | `{ success, content? (base64) }` | 读文件 |
| `writeFile` | `{ path, content (base64), expectedHash? }` | `{ success, hash? }` | 写文件 |
| `listDirectory` | `{ path }` | `{ success, entries? }` | 列目录 |
| `getDirectoryTree` | `{ path, maxDepth }` | `{ success, tree? }` | 目录树 |
| `ripgrep` | `{ args, cwd? }` | `{ success, stdout?, stderr? }` | 搜索 |
| `killSession` | `{}` | `{ success }` | 终止会话 |

**机器级**（`{machineId}:methodName`）：

| 方法 | 请求 | 响应 | 说明 |
|------|------|------|------|
| `spawn-happy-session` | `{ directory, sessionId?, agent?, env? }` | `{ type: 'success', sessionId }` | 创建会话 |
| `stop-session` | `{ sessionId }` | `{ message }` | 停止会话 |
| `stop-daemon` | `{}` | `{ message }` | 停止 daemon |

### 5.2 RPC 调用流程

```typescript
// RpcClient.ets
async function rpcCall<T>(method: string, params: unknown, timeout = 30000): Promise<T> {
  const id = generateCuid2()
  const encryptedParams = sessionEncryption.encrypt(JSON.stringify(params))

  // 注册等待
  const promise = new Promise<T>((resolve, reject) => {
    pendingRequests.set(id, { resolve, reject, timer: setTimeout(() => {
      pendingRequests.delete(id)
      reject(new Error(`RPC timeout: ${method}`))
    }, timeout) })
  })

  // 发送 Request 帧
  wsTransport.send({
    event: 'rpc-call',
    id,
    data: { method, params: encryptedParams }
  })

  return promise
}

// 收到 rpc-call:ack 时
function handleAck(frame: WsResponse): void {
  const pending = pendingRequests.get(frame.id)
  if (pending) {
    clearTimeout(pending.timer)
    pendingRequests.delete(frame.id)
    if (frame.error) {
      pending.reject(new Error(frame.error))
    } else {
      const decrypted = sessionEncryption.decrypt(frame.data)
      pending.resolve(JSON.parse(decrypted))
    }
  }
}
```

### 5.3 RPC 参数加密

所有 RPC 的 `params` 和响应 `result` 都经过端到端加密：

```
发送: params → JSON.stringify → sessionEncryption.encrypt → base64
接收: result → base64 → sessionEncryption.decrypt → JSON.parse
```

加密密钥：
- 会话级 RPC → 用 session DEK 加密
- 机器级 RPC → 用 machine DEK 加密

### 5.4 路径安全

所有文件系统 RPC（readFile、writeFile、listDirectory、getDirectoryTree）在 CLI daemon 端会验证路径：
- 不允许目录穿越（`..`）
- 限制在 session 的工作目录内
- 鸿蒙客户端发送前可做客户端侧预校验
