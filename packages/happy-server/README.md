# Happy Server

开源端到端加密的 `Claude Code` 客户端的极简后端。

## Happy 是什么？

Happy Server 是面向安全 `Claude Code` 客户端的同步核心。它让多设备能够共享加密对话，同时保持完全隐私：服务器从不看到你的消息，只会存储它无法读取的加密数据块。

## 功能

- 🔐 **零知识** - 服务器会存储加密数据，但无法解密
- 🎯 **最小暴露面** - 仅包含安全同步所需的关键功能，除此之外不提供  
- 🕵️ **隐私优先** - 不做分析、不追踪、不进行数据挖掘
- 📖 **开源** - 实现透明，便于审计与自建部署
- 🔑 **密码学认证** - 不存储密码，仅使用公钥签名
- ⚡ **实时同步** - 基于 WebSocket 的跨设备同步
- 📱 **多设备** - 在手机、平板和电脑之间无缝管理会话
- 🔔 **推送通知** - 当 `Claude Code` 完成任务或需要权限时通知你（加密传输，我们无法看到内容）
- 🌐 **可横向扩展** - 按需支持水平扩容

## 工作原理

你的 `Claude Code` 客户端会在本地生成加密密钥，并把 Happy Server 当作安全中继使用。消息在离开你的设备之前会进行端到端加密。服务器的职责很简单：存储加密数据块，并在你的设备之间进行实时同步。

## 部署

**你不需要自建部署！** 我们在 `happy-api.slopus.com` 提供的免费云端 Happy Server 与运行你自己的方案一样安全。因为所有数据在到达我们的服务器之前都会先进行端到端加密，所以即使我们真的想看，也根本无法读取你的消息。加密发生在你的设备上，只有你拥有密钥。

话虽如此，如果你更倾向于运行自己的基础设施，Happy Server 也是开源且支持自建部署。无论你使用我们的服务器还是你自己的服务器，安全模型都是一致的。

## 使用 Docker 自建部署

独立的 Docker 镜像会在单个容器内运行全部服务，并且没有外部依赖（不需要 Postgres、Redis 或 S3）。

```bash
docker build -t happy-server -f Dockerfile .
```

从 monorepo 根目录运行：

```bash
docker run -p 3005:3005 \
  -e HANDY_MASTER_SECRET=<your-secret> \
  -v happy-data:/data \
  happy-server
```

该方案使用：
- **PGlite** - 内嵌 PostgreSQL（数据存储在 `/data/pglite`）
- **本地文件系统** - 用于文件上传（存储在 `/data/files`）
- **内存事件总线** - 不需要 Redis

数据会在 `happy-data` 这个 Docker 卷中持久化，并在容器重启后继续保留。

### 环境变量

| 变量 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `HANDY_MASTER_SECRET` | 是 | - | 用于认证/加密的主密钥 |
| `PUBLIC_URL` | 否 | `http://localhost:3005` | 客户端侧用于文件 URL 的公开基础地址 |
| `PORT` | 否 | `3005` | 服务器端口 |
| `DATA_DIR` | 否 | `/data` | 基础数据目录 |
| `PGLITE_DIR` | 否 | `/data/pglite` | PGlite 数据库目录 |

### 可选：外部服务

如果你希望使用外部 Postgres 或 Redis 来替代内置默认值，请设置：

| 变量 | 说明 |
|------|------|
| `DATABASE_URL` | PostgreSQL 连接地址（绕过 PGlite） |
| `REDIS_URL` | Redis 连接地址 |
| `S3_HOST` | S3/MinIO 主机地址（绕过本地文件存储） |

## 许可

MIT - 使用它、修改它，并在任何地方部署它。