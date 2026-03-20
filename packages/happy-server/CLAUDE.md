# Happy Server

Fastify 后端，加密同步 + Socket.IO 实时通信。

## 技术栈

| 技术 | 说明 |
|------|------|
| Runtime | Node.js 20 |
| 语言 | TypeScript (strict) |
| 框架 | Fastify 5 |
| 数据库 | PostgreSQL + Prisma ORM |
| 验证 | Zod |
| HTTP | Axios |
| 实时 | Socket.io |
| 缓存/发布订阅 | Redis (ioredis) |
| 测试 | Vitest |
| 包管理 | Yarn |

## 命令

| 命令 | 说明 |
|------|------|
| `yarn build` | TypeScript 类型检查 (`tsc --noEmit`) |
| `yarn start` | 启动服务 |
| `yarn test` | 运行测试 |
| `yarn migrate` | Prisma 迁移 |
| `yarn generate` | 生成 Prisma client |
| `yarn db` | 启动本地 PostgreSQL Docker |

## 代码风格

- 4 空格缩进
- 函数式和声明式编程，避免类
- `@/` 别名 → `./sources/`，只用绝对导入
- 接口优于类型，避免 enum（用 map 代替）
- 测试文件 `.spec.ts` 后缀，与源文件同目录
- 目录用小写 + 连字符
- 工具函数文件名与函数名一致
- 非必要不创建文件，优先编辑现有文件
- 不主动创建文档文件

## 文件结构

```
/sources
├── app/              # 入口点（api.ts, timeout.ts）
├── apps/api/routes   # API 路由
├── modules/          # 可复用模块（非应用逻辑）
│   ├── ai/           # AI 服务封装
│   ├── eventbus/     # 事件总线
│   ├── lock/         # 分布式锁
│   └── media/        # 媒体文件处理
├── utils/            # 底层工具
├── recipes/          # 独立脚本
├── services/         # 核心服务（pubsub.ts）
├── storage/          # 数据库工具（db.ts, inTx.ts）
└── main.ts           # 主入口
```

## 数据库

- Prisma ORM，用 `inTx` 包裹事务
- 复杂字段用 `Json` 类型
- **禁止自行创建迁移**，仅运行 `yarn generate`
- 事务内不做非事务操作（如文件上传）

## 事件总线

- eventbus 支持进程内和进程间通信（本地或 Redis）
- 事务提交后用 `afterTx` 发事件，不直接 emit

## API 开发

- 路由在 `/sources/apps/api/routes`
- Fastify + Zod 类型安全路由定义
- **幂等性**: 所有操作必须幂等，客户端可能自动重试

## 开发注意事项

- DB 操作放在 `sources/apps/` 对应子文件夹的独立文件中，以实体类型 + 操作命名（如 `friendAdd`）
- Action 函数只返回必要数据，不"以防万一"返回多余字段
- 非要求不添加日志
- 使用 `privacyKit.decodeBase64` / `privacyKit.encodeBase64` 替代 Buffer
- GitHub 用户名使用实际用户名
- Action 函数完成后添加文档注释并保持同步
- 不运行 `yarn dev`，用 `yarn dev` 启动并加载正确的 env 文件

## 详细文档

- [调试指南](.claude/docs/debugging.md) — 远程日志、常见问题、诊断命令
