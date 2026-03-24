# HarmonyOS 客户端测试策略与质量保障

> 本文档定义 HarmonyOS 客户端（`packages/happy-harmony`）的全生命周期测试策略、验收标准和代码质量检查清单。

## 目录

1. [测试原则](#测试原则)
2. [测试框架选型](#测试框架选型)
3. [各 Phase 验收测试清单](#各-phase-验收测试清单)
4. [代码质量检查清单](#代码质量检查清单)
5. [架构合规性检查项](#架构合规性检查项)
6. [持续集成策略](#持续集成策略)

---

## 测试原则

### 核心原则

1. **TDD 优先** — 新功能先写测试，遵循 RED-GREEN-REFACTOR 循环
2. **80% 测试覆盖率** — 单元测试覆盖率不低于 80%
3. **测试与源文件同目录** — `.test.ets` 或 `.spec.ts` 与被测文件放在一起
4. **不 Mock 真实依赖** — 优先集成测试，保证端到端行为正确
5. **加密一致性验证** — 与现有 CLI/App 结果严格比对

### 测试金字塔

```
       E2E 测试 (5%)
      ─────────────
     集成测试 (25%)
    ────────────────
   单元测试 (70%)
  ───────────────────
```

---

## 测试框架选型

### 鸿蒙端测试方案

| 测试类型 | 框架 | 文件扩展名 | 说明 |
|---------|------|-----------|------|
| 单元测试 | `@ohos/hypium` | `.test.ets` | 鸿蒙官方测试框架 |
| 组件测试 | `@ohos/hypium` + `@ohos.arkui.ui` | `.test.ets` | UI 组件渲染与交互 |
| 加密测试 | Vitest (Node.js) | `.spec.ts` | FFI/NDK 层通过 Node.js 验证 |

**加密测试策略**: Phase 0 的加密验证在 Node.js 环境运行，确保与现有实现一致。鸿蒙端只需验证 FFI 调用成功。

### 服务端测试方案

| 测试类型 | 框架 | 说明 |
|---------|------|------|
| 单元测试 | Vitest | 项目统一框架 |
| WebSocket 测试 | Vitest + `ws` | 模拟客户端连接 |
| 集成测试 | Vitest + `happy-server` | 复用现有模式 |

**文件位置**: `packages/happy-server/sources/app/api/*.test.ts`

### E2E 测试方案

| 测试类型 | 工具 | 说明 |
|---------|------|------|
| 认证流程 | Vitest | 模拟完整登录/恢复流程 |
| 消息同步 | Vitest + mock WebSocket | 验证消息收发与解密 |
| RPC 交互 | Vitest | 验证权限审批等 RPC 调用 |

**文件位置**: `packages/happy-harmony/tests/e2e/*.test.ts`

---

## 各 Phase 验收测试清单

### Phase 0: 加密 PoC

**目标**: 验证鸿蒙端加密与现有实现一致

#### 验收测试

| 测试项 | 测试方法 | 通过标准 |
|-------|---------|---------|
| Ed25519 签名一致性 | 固定输入，比对签名输出 | 与 CLI 结果完全一致 |
| `crypto_box` 加解密 | 固定 plaintext/nonce，比对结果 | 与 CLI 结果完全一致 |
| `crypto_secretbox` 加解密 | 固定 plaintext/nonce，比对结果 | 与 CLI 结果完全一致 |
| FFI 调用成功 | 调用 `sodium_init()` 无异常 | 返回 0 或 1 |
| 真实账户认证 | 用真实 secret 登录 | 成功获取 JWT |
| 会话样本解密 | 用真实账户解密一条消息 | 能正确解析内容 |

#### 测试文件

```
packages/happy-harmony/common/src/main/ets/crypto/
├── SodiumFFI.test.ets        # FFI 调用测试
├── SodiumCrypto.test.ets      # 加密算法测试
└── BufferUtils.test.ets       # Buffer 工具测试
```

#### 一致性验证脚本

在 `packages/happy-cli` 中创建验证脚本，生成固定输入的预期输出，鸿蒙端逐项比对。

---

### Phase 1: Server WebSocket

**目标**: 独立 WebSocket 通道可用

#### 验收测试

| 测试项 | 测试方法 | 通过标准 |
|-------|---------|---------|
| 连接建立 | 模拟客户端连接 `/v1/ws` | 成功建立，JWT 认证通过 |
| Ping/Pong | 发送 `ping` request | 10s 内收到 `ping:ack` |
| Push 消息接收 | 服务端推送 `update` 事件 | 客户端正确解析 |
| Request/Response | 发送带 `id` 的请求 | 收到对应 `:ack` 响应 |
| RPC 调用 | 发送 `rpc-call` | 正确调用并返回结果 |
| Socket.IO 兼容性 | 连接现有 Socket.IO 端 | 无异常，功能不受影响 |

#### 测试文件

```
packages/happy-server/sources/app/api/
├── wsTransport.test.ts        # 传输层测试
└── wsHandlers.test.ts         # 消息处理器测试
```

#### 测试示例

```typescript
import { describe, it, expect } from 'vitest';
import { WebSocket } from 'ws';
import { createTestServer } from './helpers';

describe('WebSocket Transport', () => {
  it('should authenticate and establish connection', async () => {
    const ws = new WebSocket('ws://localhost:3005/v1/ws?token=xxx');
    await new Promise(resolve => ws.on('open', resolve));
    expect(ws.readyState).toBe(WebSocket.OPEN);
  });

  it('should handle ping/pong within timeout', async () => {
    const response = await sendWsRequest({
      event: 'ping',
      id: 'test001',
      data: {}
    });
    expect(response.event).toBe('ping:ack');
    expect(response.id).toBe('test001');
  });
});
```

---

### Phase 2: 客户端骨架 + 认证

**目标**: 可启动、可登录、可恢复

#### 验收测试

| 测试项 | 测试方法 | 通过标准 |
|-------|---------|---------|
| App 启动 | 冷启动 | 无崩溃，首屏正常 |
| 创建账户 | 输入设备名，完成注册 | 成功登录，保存凭据 |
| QR 恢复 | 扫描 QR 码 | 成功恢复账户 |
| 手动恢复 | 输入 secret | 成功恢复账户 |
| 自动登录 | 重启 App | 自动从本地凭据登录 |
| 退出登录 | 点击退出 | 清除凭据，返回登录页 |

#### 测试文件

```
packages/happy-harmony/
├── auth/src/main/ets/
│   ├── AuthService.test.ets
│   └── TokenStore.test.ets
└── tests/e2e/
    └── auth-flow.test.ts      # E2E 认证流程
```

#### E2E 测试流程

```typescript
describe('Authentication Flow', () => {
  it('should complete full registration and auto-login', async () => {
    // 1. 创建账户
    const result = await authService.createAccount('My Harmony Device');
    expect(result.token).toBeDefined();
    expect(result.user.id).toBeDefined();

    // 2. 验证凭据已保存
    const hasCredentials = await tokenStore.hasCredentials();
    expect(hasCredentials).toBe(true);

    // 3. 模拟重启，自动登录
    await authService.initialize();  // 从本地恢复
    const isLoggedIn = await authService.isLoggedIn();
    expect(isLoggedIn).toBe(true);
  });
});
```

---

### Phase 3: 核心功能闭环

**目标**: 最小可用版本（MVP）

#### 验收测试

| 测试项 | 测试方法 | 通过标准 |
|-------|---------|---------|
| 会话列表加载 | 拉取 `/v1/sessions` | 正确显示所有会话 |
| 消息收发 | 发送消息，接收回复 | 消息正确解密显示 |
| 消息分页 | `GET /v3/sessions/:id/messages?after_seq=N` | 正确分页加载 |
| 权限审批 | RPC 批准请求 | Agent 继续执行 |
| 拒绝请求 | RPC 拒绝请求 | Agent 停止/报错 |
| 模式切换 | RPC 切换 mode | mode 正确变更 |
| 终止会话 | RPC kill session | 会话终止 |
| 新建会话 | 选择机器、路径、Profile | 会话创建成功 |

#### 测试文件

```
packages/happy-harmony/
├── sync/src/main/ets/
│   ├── SyncEngine.test.ets
│   └── SessionSync.test.ets
├── rpc/src/main/ets/
│   ├── RpcClient.test.ets
│   └── SessionRpc.test.ets
└── tests/e2e/
    ├── session-flow.test.ts     # 会话流程
    └── message-flow.test.ts     # 消息流程
```

#### 消息流 E2E 测试

```typescript
describe('Message Flow', () => {
  it('should send and receive messages with decryption', async () => {
    // 1. 发送消息
    await chatService.sendMessage(sessionId, {
      type: 'text',
      text: 'Hello from Harmony'
    });

    // 2. 等待 agent 回复
    const response = await waitForMessage(sessionId, 10000);
    expect(response.role).toBe('agent');

    // 3. 验证解密成功
    const decrypted = await cryptoService.decryptMessage(response.content);
    expect(decrypted.type).toBeDefined();
  });
});
```

---

### Phase 4: 功能补全（P1/P2）

**目标**: 对齐 RN 客户端功能

#### P1 功能验收清单

| 功能 | 测试方法 | 通过标准 |
|------|---------|---------|
| 删除会话 | 删除后刷新列表 | 会话消失 |
| 会话文件浏览 | 打开文件列表 | 正确显示 |
| 文件查看 | 打开文件 | 内容正确显示 |
| 远程 Bash | 发送命令 | 返回执行结果 |
| 启动/停止 daemon | RPC 调用 | daemon 状态正确 |
| Kill 会话 | RPC 调用 | 会话终止 |
| 批准 CLI 认证 | 审批请求 | CLI 继续运行 |
| 密钥备份 | 导出密钥 | QR 码/文件正确 |
| API Key 管理 | 添加/删除 | 持久化成功 |
| Profile 管理 | 创建/编辑/删除 | 正确保存 |

#### P2 功能验收清单

| 功能 | 测试方法 | 通过标准 |
|------|---------|---------|
| Artifact 管理 | 查看/删除 | 正确显示 |
| 好友系统 | 添加/删除 | 好友列表更新 |
| 使用量统计 | 查看统计 | 数据正确 |
| 推送通知 | 触发推送 | 通知到达 |
| 主题切换 | 切换主题 | UI 立即更新 |
| 语言切换 | 切换语言 | 文案立即更新 |
| GitHub OAuth | 授权登录 | 绑定成功 |

#### 测试文件

```
packages/happy-harmony/tests/e2e/
├── p1/
│   ├── session-delete.test.ts
│   ├── file-browser.test.ts
│   ├── remote-bash.test.ts
│   └── settings.test.ts
└── p2/
    ├── artifact.test.ts
    ├── friend-system.test.ts
    └── i18n.test.ts
```

---

### Phase 5: 优化打磨

**目标**: 性能、体验、可维护性

#### 性能基准测试

| 指标 | 目标 | 测试方法 |
|------|------|---------|
| 会话列表渲染 | <100ms | 渲染 100 条会话 |
| 消息滚动 FPS | >55 FPS | 滚动 200 条消息 |
| 图片加载 | <500ms | 加载 10 张图片 |
| 代码块高亮 | <200ms | 渲染 100 行代码 |
| 启动时间 | <2s | 冷启动到首屏 |

#### 体验检查清单

| 检查项 | 通过标准 |
|-------|---------|
| 加载态统一 | 所有异步操作显示 loading |
| 错误提示统一 | 错误文案友好，带重试按钮 |
| 空态统一 | 空列表显示占位图和提示 |
| 网络异常 | 自动重连，断网提示 |
| 崩溃恢复 | 崩溃后重启可恢复状态 |

#### 可维护性检查

| 检查项 | 通过标准 |
|-------|---------|
| 日志完整 | 关键路径有日志 |
| 埋点完整 | 用户行为可追踪 |
| 调试开关 | 可开启调试模式 |
| 临时代码清理 | 无 TODO/FIXME 未处理 |

---

## 代码质量检查清单

### 不可变模式合规性

```typescript
// WRONG: Mutation
function updateUser(user: User, name: string): User {
  user.name = name;  // MUTATION!
  return user;
}

// CORRECT: Immutability
function updateUser(user: User, name: string): User {
  return { ...user, name };
}
```

**检查项**:
- [ ] 函数不修改传入参数
- [ ] 对象更新使用展开运算符
- [ ] 数组操作使用 `map`/`filter`/`slice`，不用 `push`/`splice`

### 错误处理完整性

**检查项**:
- [ ] 所有 `async` 函数有 try-catch
- [ ] 网络请求有超时处理
- [ ] 错误日志记录上下文
- [ ] UI 层错误提示用户友好

```typescript
// CORRECT: Complete error handling
try {
  const result = await apiCall();
  return result;
} catch (error) {
  logger.error('Operation failed', { context, error });
  throw new UserFriendlyError('操作失败，请稍后重试');
}
```

### 文件大小限制

| 类型 | 推荐行数 | 最大行数 |
|------|---------|---------|
| 工具函数 | 50-200 | 400 |
| 组件 | 100-300 | 600 |
| 页面 | 200-500 | 800 |
| 服务模块 | 200-400 | 800 |

### 函数大小限制

| 复杂度 | 推荐行数 | 最大行数 |
|-------|---------|---------|
| 简单函数 | <20 | 50 |
| 中等复杂度 | <30 | 70 |
| 高复杂度 | <40 | 100 |

**超长函数拆分**:
- 提取子函数
- 提取常量
- 使用管道/组合模式

### 嵌套深度限制

**最大嵌套深度: 4 层**

```typescript
// WRONG: 5+ 层嵌套
if (a) {
  if (b) {
    if (c) {
      if (d) {
        if (e) {  // 太深!
          // ...
        }
      }
    }
  }
}

// CORRECT: 提前返回
if (!a) return;
if (!b) return;
if (!c) return;
if (!d) return;
// e 处理
```

### 安全检查

| 检查项 | 说明 |
|-------|------|
| 无硬编码密钥 | 密钥从环境变量或安全存储读取 |
| 输入验证 | 所有外部输入使用 Zod 验证 |
| 敏感数据日志 | 日志不包含 token/密钥/敏感内容 |
| HTTPS 通信 | 生产环境强制 HTTPS |

---

## 架构合规性检查项

### 模块职责边界

| 模块 | 职责 | 不应包含 |
|------|------|---------|
| `crypto/` | 加密算法、FFI 调用 | UI 逻辑、网络请求 |
| `auth/` | 认证、令牌管理 | UI 渲染、业务逻辑 |
| `network/` | HTTP/WebSocket 传输 | 加密、UI |
| `sync/` | 数据同步、状态管理 | UI 渲染 |
| `rpc/` | RPC 调用封装 | UI 交互 |
| `ui/` | UI 组件、页面 | 业务逻辑、加密 |

### 依赖方向合规

```
ui/ → sync/ → rpc/ → network/ → crypto/
     ↘   auth/ ↗
```

**禁止反向依赖**:
- `crypto/` 不能依赖其他模块
- `network/` 不能依赖 `sync/` 或 `ui/`
- `rpc/` 不能依赖 `ui/`

### 接口契约一致性

**检查项**:
- [ ] API 调用符合 `docs-harmony/prd/05-protocol-spec.md`
- [ ] WebSocket 消息格式符合协议规范
- [ ] 加密结果与现有实现一致
- [ ] Zod schema 与后端定义一致

---

## 持续集成策略

### CI 流程

```yaml
# .github/workflows/harmony-test.yml
name: Harmony Tests

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: yarn install
      - run: yarn test:harmony:unit

  crypto-verification:
    runs-on: ubuntu-latest
    steps:
      - run: yarn test:harmony:crypto

  integration-tests:
    runs-on: ubuntu-latest
    services:
      happy-server:
        image: happy-server:latest
    steps:
      - run: yarn test:harmony:integration
```

### 测试命令

```json
{
  "scripts": {
    "test:harmony:unit": "vitest packages/happy-harmony/**/*.test.ts",
    "test:harmony:crypto": "node scripts/verify-crypto.js",
    "test:harmony:integration": "vitest packages/happy-harmony/tests/e2e",
    "test:harmony:coverage": "vitest --coverage"
  }
}
```

### 代码覆盖率要求

| 模块 | 最低覆盖率 |
|------|-----------|
| `crypto/` | 90% |
| `auth/` | 85% |
| `network/` | 80% |
| `sync/` | 75% |
| `rpc/` | 75% |
| `ui/` | 60% |

---

## 附录: 测试文件模板

### 单元测试模板

```typescript
import { describe, it, expect, beforeEach } from 'vitest';
import { functionToTest } from './module';

describe('FunctionToTest', () => {
  beforeEach(() => {
    // 测试前准备
  });

  it('should do something correctly', () => {
    const input = { /* ... */ };
    const expected = { /* ... */ };
    const result = functionToTest(input);
    expect(result).toEqual(expected);
  });

  it('should handle error case', () => {
    const input = { /* invalid */ };
    expect(() => functionToTest(input)).toThrow();
  });
});
```

### 集成测试模板

```typescript
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { setupTestServer, closeTestServer } from './helpers';

describe('Integration: SomeFeature', () => {
  beforeAll(async () => {
    await setupTestServer();
  });

  afterAll(async () => {
    await closeTestServer();
  });

  it('should complete full flow', async () => {
    // 完整业务流程测试
  });
});
```

---

## 变更记录

| 日期 | 版本 | 变更说明 |
|------|------|---------|
| 2026-03-23 | 1.0 | 初始版本 |
