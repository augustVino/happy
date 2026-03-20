# @slopus/happy-wire

面向 Happy 客户端与服务的规范级 wire 规范包。

该包以 TypeScript 类型 + Zod schema 的形式定义共享的 wire 合约。它被刻意设计得很小且聚焦，仅包含协议级别的数据。

## 快速示例（旧版 vs 新版）

旧版与新版格式都封装在加密的会话（session）消息中传输。

旧版格式示例（已解密的载荷）：

```json
{
  "role": "user",
  "content": {
    "type": "text",
    "text": "fix the failing test"
  },
  "meta": {
    "sentFrom": "mobile"
  }
}
```

```json
{
  "role": "agent",
  "content": {
    "type": "output",
    "data": {
      "type": "message",
      "message": "I found the issue in api/session.ts"
    }
  },
  "meta": {
    "sentFrom": "cli"
  }
}
```

新版会话协议格式示例（已解密的载荷）：

```json
{
  "role": "session",
  "content": {
    "id": "msg_01",
    "time": 1739347230000,
    "role": "agent",
    "turn": "turn_01",
    "ev": {
      "t": "text",
      "text": "I found the issue in api/session.ts"
    }
  },
  "meta": {
    "sentFrom": "cli"
  }
}
```

现代会话协议用户信封（已解密的载荷）：

```json
{
  "role": "session",
  "content": {
    "id": "msg_legacy_user_01",
    "time": 1739347231000,
    "role": "user",
    "ev": {
      "t": "text",
      "text": "fix the failing test"
    }
  },
  "meta": {
    "sentFrom": "cli"
  }
}
```

协议不变量：
- 外层 `role = "session"` 用于标记现代会话协议的 payload。
- 在 `content` 内部，信封（envelope）的 `role` 仅为 `"user"` 或 `"agent"`。

会话协议发送灰度（`ENABLE_SESSION_PROTOCOL_SEND`）：
- 发送方发出现代会话协议的用户 payload（`role = "session"` 且 `content.role = "user"`）。
- 默认（未启用）：应用持续消费旧版用户 payload（`role = "user"`, `content.type = "text"`），并丢弃现代用户 payload。
- 启用后：应用消费现代用户 payload，并丢弃旧版用户 payload。
- 真值（truthy）取值：`1`、`true`、`yes`（不区分大小写）。

wire 级别的加密容器（legacy 与 new 均相同）：

```json
{
  "id": "msg-db-row-id",
  "seq": 101,
  "localId": null,
  "content": {
    "t": "encrypted",
    "c": "BASE64_ENCRYPTED_PAYLOAD"
  },
  "createdAt": 1739347230000,
  "updatedAt": 1739347230000
}
```

## 目的

`@slopus/happy-wire` 统一集中定义：
- 加密的消息/更新载荷
- 会话协议信封（envelope）与事件流
- 用于创建有效会话信封的辅助工具

目标是让 CLI/app/server/agent 在同一套 wire 合约上运行，并避免 schema 漂移（schema drift）。

## 包标识

- 名称：`@slopus/happy-wire`
- 工作区路径：`packages/happy-wire`
- 入口：`src/index.ts`
- 运行时依赖：`zod`, `@paralleldrive/cuid2`

## 公共导出

`src/index.ts` 会从以下位置导出全部内容：
- `src/messages.ts`
- `src/legacyProtocol.ts`
- `src/sessionProtocol.ts`

### `messages.ts` 导出

Schema + 推断出的类型：
- `SessionMessageContentSchema`
- `SessionMessage`
- `SessionMessageSchema`
- `MessageMetaSchema`
- `MessageMeta`
- `SessionProtocolMessageSchema`
- `SessionProtocolMessage`
- `MessageContentSchema`
- `MessageContent`
- `VersionedEncryptedValueSchema`
- `VersionedEncryptedValue`
- `VersionedNullableEncryptedValueSchema`
- `VersionedNullableEncryptedValue`
- `UpdateNewMessageBodySchema`
- `UpdateNewMessageBody`
- `UpdateSessionBodySchema`
- `UpdateSessionBody`
- `VersionedMachineEncryptedValueSchema`
- `VersionedMachineEncryptedValue`
- `UpdateMachineBodySchema`
- `UpdateMachineBody`
- `CoreUpdateBodySchema`
- `CoreUpdateBody`
- `CoreUpdateContainerSchema`
- `CoreUpdateContainer`

兼容性别名：
- `ApiMessageSchema` -> `SessionMessageSchema`
- `ApiMessage` -> `SessionMessage`
- `ApiUpdateNewMessageSchema` -> `UpdateNewMessageBodySchema`
- `ApiUpdateNewMessage` -> `UpdateNewMessageBody`
- `ApiUpdateSessionStateSchema` -> `UpdateSessionBodySchema`
- `ApiUpdateSessionState` -> `UpdateSessionBody`
- `ApiUpdateMachineStateSchema` -> `UpdateMachineBodySchema`
- `ApiUpdateMachineState` -> `UpdateMachineBody`
- `UpdateBodySchema` -> `UpdateNewMessageBodySchema`
- `UpdateBody` -> `UpdateNewMessageBody`
- `UpdateSchema` -> `CoreUpdateContainerSchema`
- `Update` -> `CoreUpdateContainer`

### `legacyProtocol.ts` 导出

Schema + 推断出的类型：
- `UserMessageSchema`
- `UserMessage`
- `AgentMessageSchema`
- `AgentMessage`
- `LegacyMessageContentSchema`
- `LegacyMessageContent`

### `sessionProtocol.ts` 导出

Schema + 推断出的类型：
- `sessionRoleSchema`
- `SessionRole`
- `sessionTextEventSchema`
- `sessionServiceMessageEventSchema`
- `sessionToolCallStartEventSchema`
- `sessionToolCallEndEventSchema`
- `sessionFileEventSchema`
- `sessionTurnStartEventSchema`
- `sessionStartEventSchema`
- `sessionTurnEndStatusSchema`
- `SessionTurnEndStatus`
- `sessionTurnEndEventSchema`
- `sessionStopEventSchema`
- `sessionEventSchema`
- `SessionEvent`
- `sessionEnvelopeSchema`
- `SessionEnvelope`
- `CreateEnvelopeOptions`
- `createEnvelope(...)`

## Wire 类型规范

## 公共基础规则

这些是 schema 级别的要求，而不仅是建议。

- `id`, `sid`, `machineId`, `call`, `name`, `title`, `description`, `ref`: `string`
- `seq`, `createdAt`, `updatedAt`, `size`, `width`, `height`, `version`, `activeAt`: `number`
- 所有可空字段都必须明确标注为 `.nullable()`。
- 所有可选字段都必须明确标注为 `.optional()`。
- `.nullish()` 表示 `undefined | null | <type>`。

## 消息/更新规范（`messages.ts`）

### `SessionMessageContentSchema`

```ts
{
  t: 'encrypted';
  c: string;
}
```

含义：
- `t` 是一个取值严格判别器（discriminator），其值为 `'encrypted'`。
- `c` 是将加密载荷字节编码为字符串后的结果（当前用法中通常为 base64）。

### `SessionMessageSchema`

```ts
{
  id: string;
  seq: number;
  localId?: string | null;
  content: SessionMessageContent;
  createdAt: number;
  updatedAt: number;
}
```

备注：
- 为了兼容不同的生产方（producer），`localId` 使用 `.nullish()`。
- 在这个共享 schema 中，`createdAt` 与 `updatedAt` 是必填字段。

### `MessageMetaSchema`

```ts
{
  sentFrom?: string;
  permissionMode?: 'default' | 'acceptEdits' | 'bypassPermissions' | 'plan' | 'read-only' | 'safe-yolo' | 'yolo';
  model?: string | null;
  fallbackModel?: string | null;
  customSystemPrompt?: string | null;
  appendSystemPrompt?: string | null;
  allowedTools?: string[] | null;
  disallowedTools?: string[] | null;
  displayText?: string;
}
```

## 旧版已解密载荷规范（`legacyProtocol.ts`）

### `UserMessageSchema`（旧版已解密载荷）

```ts
{
  role: 'user';
  content: {
    type: 'text';
    text: string;
  };
  localKey?: string;
  meta?: MessageMeta;
}
```

### `AgentMessageSchema`（旧版已解密载荷）

```ts
{
  role: 'agent';
  content: {
    type: string;
    [key: string]: unknown;
  };
  meta?: MessageMeta;
}
```

### `LegacyMessageContentSchema`

基于 `role` 的判别联合（discriminated union）：
- `'user'` -> `UserMessageSchema`
- `'agent'` -> `AgentMessageSchema`

## 顶层已解密载荷规范（`messages.ts`）

### `SessionProtocolMessageSchema`（现代已解密载荷包装器）

```ts
{
  role: 'session';
  content: SessionEnvelope;
  meta?: MessageMeta;
}
```

### `MessageContentSchema`

在顶层 `role` 上进行判别联合：
- `'user'` -> `UserMessageSchema`（旧版）
- `'agent'` -> `AgentMessageSchema`（旧版）
- `'session'` -> `SessionProtocolMessageSchema`（现代）

## 消息/更新规范（`messages.ts`）续

### `VersionedEncryptedValueSchema`

```ts
{
  version: number;
  value: string;
}
```

用于加密的、带版本跟踪（version-tracked）的 blob；当其存在时不允许为 null。

### `VersionedNullableEncryptedValueSchema`

```ts
{
  version: number;
  value: string | null;
}
```

用于需要在载荷存在时将其有意重置为 null，同时仍然保留版本信息的场景。

### `VersionedMachineEncryptedValueSchema`

```ts
{
  version: number;
  value: string;
}
```

机器更新（machine update）变体。与 `VersionedEncryptedValueSchema` 具有等价的结构。

### `UpdateNewMessageBodySchema`

```ts
{
  t: 'new-message';
  sid: string;
  message: SessionMessage;
}
```

### `UpdateSessionBodySchema`

```ts
{
  t: 'update-session';
  id: string;
  metadata?: VersionedEncryptedValue | null;
  agentState?: VersionedNullableEncryptedValue | null;
}
```

重要区别：
- `metadata.value` 是 `string` 当 metadata 块存在。
- `agentState.value` 可能为 `string` 或 `null` 当 block 存在。

### `UpdateMachineBodySchema`

```ts
{
  t: 'update-machine';
  machineId: string;
  metadata?: VersionedMachineEncryptedValue | null;
  daemonState?: VersionedMachineEncryptedValue | null;
  active?: boolean;
  activeAt?: number;
}
```

### `CoreUpdateBodySchema`

在 `t` 上做判别联合（discriminated union），且仅有且恰好 3 个变体：
- `'new-message'`
- `'update-session'`
- `'update-machine'`

### `CoreUpdateContainerSchema`

```ts
{
  id: string;
  seq: number;
  body: CoreUpdateBody;
  createdAt: number;
}
```

## 会话协议规范（`sessionProtocol.ts`）

## 角色

### `sessionRoleSchema`

```ts
'user' | 'agent'
```

角色含义：
- `'user'`：用户来源的信封（envelope）。
- `'agent'`：代理来源的信封（envelope）。

## 事件变体

`sessionEventSchema` 是以 `t` 为判别器（discriminator）的判别联合（discriminated union），共 9 个变体。

### 1) 文本事件

```ts
{
  t: 'text';
  text: string;
  thinking?: boolean;
}
```

### 2) 服务事件

```ts
{
  t: 'service';
  text: string;
}
```

### 3) 工具调用开始事件

```ts
{
  t: 'tool-call-start';
  call: string;
  name: string;
  title: string;
  description: string;
  args: Record<string, unknown>;
}
```

### 4) 工具调用结束事件

```ts
{
  t: 'tool-call-end';
  call: string;
}
```

### 5) 文件事件

```ts
{
  t: 'file';
  ref: string;
  name: string;
  size: number;
  image?: {
    width: number;
    height: number;
    thumbhash: string;
  };
}
```

### 6) 回合开始事件

```ts
{
  t: 'turn-start';
}
```

### 7) Start 事件

```ts
{
  t: 'start';
  title?: string;
}
```

### 8) 回合结束事件

```ts
{
  t: 'turn-end';
  status: 'completed' | 'failed' | 'cancelled';
}
```

### 9) Stop 事件

```ts
{
  t: 'stop';
}
```

## 信封（Envelope）

### `sessionEnvelopeSchema`

```ts
{
  id: string;
  time: number;
  role: 'user' | 'agent';
  turn?: string;
  subagent?: string; // must pass cuid2 validation when present
  ev: SessionEvent;
}
```

额外校验（`superRefine`）：
- 如果 `ev.t === 'service'`，那么 `role` MUST be `'agent'`。
- 如果 `ev.t === 'start'` 或 `ev.t === 'stop'`，那么 `role` MUST be `'agent'`。
- 如果 `subagent` 存在，则它 MUST 满足 `isCuid(...)`。

## 辅助函数合约

### `createEnvelope(role, ev, opts?)`

输入：
- `role: SessionRole`
- `ev: SessionEvent`
- `opts?: { id?: string; time?: number; turn?: string; subagent?: string }`

行为：
- 如果 `opts.id` 缺失，则使用 `createId()` 生成 `id`。
- 如果 `opts.time` 缺失，则将 `time` 设为 `Date.now()`。
- 仅在提供了 `turn` 时才包含 `turn`。
- 仅在提供了 `subagent` 时才包含 `subagent`。

输出：
- 返回一个经 `sessionEnvelopeSchema` 解析后的 `SessionEnvelope`。
- 当组合无效时会抛出异常（例如 `role = 'user'` 且 `ev.t = 'service'`）。

## 规范性 JSON 示例

## 使用 `new-message` 更新容器

```json
{
  "id": "upd-1",
  "seq": 100,
  "createdAt": 1739347200000,
  "body": {
    "t": "new-message",
    "sid": "session-1",
    "message": {
      "id": "msg-1",
      "seq": 55,
      "localId": null,
      "content": {
        "t": "encrypted",
        "c": "Zm9v"
      },
      "createdAt": 1739347199000,
      "updatedAt": 1739347199000
    }
  }
}
```

### `new-message` 已解密内容示例

`message.content.c`（密文）解密后会得到如下内容，用于会话协议消息：

```json
{
  "role": "session",
  "content": {
    "id": "env_01",
    "time": 1739347232000,
    "role": "agent",
    "turn": "turn_01",
    "ev": {
      "t": "text",
      "text": "I found 3 TODOs."
    }
  },
  "meta": {
    "sentFrom": "cli"
  }
}
```

针对用户文本迁移行为：
- 客户端只会发出现代 payload（`role = "session"` 且 `content.role = "user"`）。
- 如果 `ENABLE_SESSION_PROTOCOL_SEND` 被禁用，应用会继续消费旧版 payload，并丢弃现代 payload。
- 如果 `ENABLE_SESSION_PROTOCOL_SEND` 被启用，应用会消费现代 payload，并丢弃旧版 payload。

## 使用 `update-session` 更新容器

```json
{
  "id": "upd-2",
  "seq": 101,
  "createdAt": 1739347210000,
  "body": {
    "t": "update-session",
    "id": "session-1",
    "metadata": {
      "version": 8,
      "value": "BASE64..."
    },
    "agentState": {
      "version": 13,
      "value": null
    }
  }
}
```

## 使用 `update-machine` 更新容器

```json
{
  "id": "upd-3",
  "seq": 102,
  "createdAt": 1739347220000,
  "body": {
    "t": "update-machine",
    "machineId": "machine-1",
    "metadata": {
      "version": 2,
      "value": "BASE64..."
    },
    "daemonState": {
      "version": 3,
      "value": "BASE64..."
    },
    "active": true,
    "activeAt": 1739347220000
  }
}
```

## 会话协议信封

```json
{
  "id": "x8s1k2...",
  "role": "agent",
  "turn": "turn-42",
  "ev": {
    "t": "turn-start"
  }
}
```

## 解析/校验使用方式

```ts
import {
  CoreUpdateContainerSchema,
  sessionEnvelopeSchema,
} from '@slopus/happy-wire';

const maybeUpdate = CoreUpdateContainerSchema.safeParse(input);
if (!maybeUpdate.success) {
  // invalid update payload
}

const maybeEnvelope = sessionEnvelopeSchema.safeParse(envelopeInput);
if (!maybeEnvelope.success) {
  // invalid envelope/event payload
}
```

## 构建与发布规范

`package.json` 合约：
- `main`: `./dist/index.cjs`
- `module`: `./dist/index.mjs`
- `types`: `./dist/index.d.cts`
- `exports["."]` 同时提供 CJS 与 ESM 入口点，并带有类型路径。

构建脚本：
- `shx rm -rf dist && npx tsc --noEmit && pkgroll`

测试：
- 使用 `vitest` 测试 `src/*.test.ts`

发布门禁：
- `prepublishOnly` 会执行构建 + 测试

已发布的文件：
- `dist`
- `package.json`
- `README.md`

## Monorepo 构建依赖行为

在本仓库中，消费方工作区通过 package exports（指向 `dist/*`）来导入 `@slopus/happy-wire`。

这意味着在一次全新检出（clean checkout）时：
1. 先构建 wire：`yarn workspace @slopus/happy-wire build`
2. 再构建/类型检查依赖方。

发布到 npm 之后，依赖方会从已发布的 tarball 中消费预构建产物。

## 变更策略

当修改 wire schemas 时：
- 优先采用可加性（additive）的变更，以保持对旧消费方的兼容。
- 将判别器取值（`t`）视为协议级别 API，避免破坏性的重命名。
- 在此 README 中记录语义层面的变更。
- 在下游发布依赖新 schema 行为之前，先提升包版本号。

## 开发命令

```bash
# from repository root
yarn workspace @slopus/happy-wire build
yarn workspace @slopus/happy-wire test
```

## 发布命令（维护者）

```bash
# interactive release target selection from repo root
yarn release

# direct release invocation
yarn workspace @slopus/happy-wire release
```

该流程会使用仓库内其他可发布库同样的 `release-it` 流程来准备发布产物。
