# Phase 3 真机验证计划

> Phase 3 完成标准：会话列表、消息同步、聊天、RPC、新建会话全部打通。

---

## 第〇步：前置准备（所有验证的前提）

### 0.1 确认 Docker 可用

打开终端，运行：

```bash
docker --version
```

预期输出类似 `Docker version 24.x.x`。如果没有安装，前往 https://www.docker.com/products/docker-desktop/ 下载安装。

### 0.2 确认 Node.js 版本

```bash
node --version
```

需要 Node.js 20+。如果版本不对，用 `nvm install 20 && nvm use 20` 切换。

### 0.3 确认 Yarn 可用

```bash
yarn --version
```

需要 1.22.22。如果没有：

```bash
npm install -g yarn@1.22.22
```

### 0.4 确认 psql 可用（macOS）

```bash
which psql
```

如果返回空，说明没有安装 PostgreSQL 客户端。推荐安装方式（任选其一）：

```bash
# 方式 A：Homebrew 安装（只装客户端，不装服务端）
brew install libpq && echo 'export PATH="/opt/homebrew/opt/libpq/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc

# 方式 B：安装 Postgres.app（带 GUI，适合不熟悉命令行的人）
# 从 https://postgresapp.com/ 下载安装，然后在 Settings 里打开 psql 的 PATH
```

安装后验证：

```bash
psql --version
```

预期输出类似 `psql (PostgreSQL) 16.x`。

---

## 一、启动服务端

### 1.1 启动 PostgreSQL 数据库

```bash
cd /Users/liepin/Documents/study/happy/packages/happy-server

# 启动 PostgreSQL 容器（首次启动会自动拉取镜像，约 1-2 分钟）
yarn db
```

预期输出：一长串 Docker 容器 ID。

验证数据库运行中：

```bash
docker ps | grep postgres
```

预期看到一行输出，STATUS 列为 `Up`。

> **如果报错 "port 5432 already in use"**：说明已有 PostgreSQL 在运行，可以忽略（直接复用）。

> **如果容器启动后立即退出 (Exited)**：`postgres` 最新镜像 (v18) 与现有挂载路径不兼容。手动指定版本启动：
> ```bash
> docker run -d -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=handy \
>   -v $(pwd)/.pgdata:/var/lib/postgresql/data -p 5432:5432 postgres:15-alpine
> ```

### 1.2 （可选）启动 Redis

```bash
# 在 packages/happy-server 目录下
yarn redis
```

Redis 用于多进程 pub/sub，本地开发非必需，但启用后功能更完整。

### 1.3 确认环境变量

```bash
# 在 packages/happy-server 目录下
cat .env.dev
```

确认以下关键配置存在：

```
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/handy
HANDY_MASTER_SECRET=your-super-secret-key-for-local-development
PORT=3005
```

如果 `.env.dev` 文件不存在，创建它：

```bash
cat > .env.dev << 'EOF'
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/handy
HANDY_MASTER_SECRET=your-super-secret-key-for-local-development
PORT=3005
METRICS_ENABLED=false
DANGEROUSLY_LOG_TO_SERVER_FOR_AI_AUTO_DEBUGGING=true
S3_HOST=localhost
S3_PORT=9000
S3_USE_SSL=false
S3_ACCESS_KEY=minioadmin
S3_SECRET_KEY=minioadmin
S3_BUCKET=happy
S3_PUBLIC_URL=http://localhost:9000/happy
NODE_ENV=development
EOF
```

> **重要**：`yarn dev` 脚本会依次加载 `.env` 和 `.env.dev`。如果 `.env` 文件不存在，需要先创建一个空文件，否则 Server 启动报错：
> ```bash
> touch .env
> ```
>
> **注意**：`METRICS_ENABLED` 建议设为 `false`。设为 `true` 时 Server 会监听 9090 端口，容易与系统其他服务冲突导致启动失败。

### 1.4 运行数据库迁移（首次需要）

```bash
# 在 packages/happy-server 目录下
yarn migrate
```

预期输出：显示迁移 SQL 被执行。

> **注意**：如果没有 `yarn migrate` 命令，可以手动运行：
> ```bash
> npx prisma migrate deploy
> ```

### 1.5 启动 MinIO（S3 兼容存储）

Server 启动依赖 MinIO，未启动会导致 Server 直接崩溃。

```bash
# 在 packages/happy-server 目录下
yarn s3
```

验证 MinIO 运行中：

```bash
docker ps | grep minio
```

预期看到 STATUS 列为 `Up`。MinIO API 端口 9000，管理控制台端口 9001。

> **如果报错 "port 9000 already in use"**：说明已有 MinIO 在运行，可以忽略。
>
> **如果容器名冲突**（已有同名 minio 容器但未运行），先删除再启动：
> ```bash
> docker rm minio && yarn s3
> ```

### 1.6 启动 Server

```bash
# 在 packages/happy-server 目录下
yarn dev
```

预期输出包含：

```
Server listening at http://0.0.0.0:3005
```

看到这行说明启动成功。**保持这个终端窗口不要关闭**。

### 1.7 验证 Server 可达

打开一个**新的终端窗口**：

```bash
curl http://localhost:3005/
```

预期返回：`Welcome to Happy Server!` 或类似欢迎信息。

### 1.8 验证 WebSocket 端点

```bash
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  http://localhost:3005/v1/ws
```

预期返回的第一行是 `HTTP/1.1 101 Switching Protocols`，说明 WebSocket 端点可用。按 `Ctrl+C` 退出。

### 1.9 查看本机 IP 地址

鸿蒙手机需要通过局域网 IP 访问你电脑上的 Server：

```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```

记下输出中的 IP 地址（通常是 `192.168.x.x`），后面会用到。

---

## 二、检查数据库数据

### 2.1 连接数据库

```bash
psql -h localhost -p 5432 -U postgres -d handy
```

提示输入密码时输入：`postgres`

看到 `handy=#` 提示符说明连接成功。

### 2.2 查看所有账户

```sql
SELECT id, "firstName", "lastName", username, "createdAt" FROM "Account";
```

### 2.3 查看所有会话

```sql
SELECT s.id, s.tag, s.active, s."lastActiveAt", a.username
FROM "Session" s JOIN "Account" a ON s."accountId" = a.id
ORDER BY s."updatedAt" DESC
LIMIT 20;
```

### 2.4 查看每个会话的消息数量

```sql
SELECT s.tag, COUNT(sm.id) as message_count
FROM "Session" s
LEFT JOIN "SessionMessage" sm ON s.id = sm."sessionId"
GROUP BY s.id, s.tag
ORDER BY message_count DESC
LIMIT 20;
```

### 2.5 查看所有机器

```sql
SELECT m.id, m.active, m."lastActiveAt", a.username
FROM "Machine" m JOIN "Account" a ON m."accountId" = a.id
ORDER BY m."lastActiveAt" DESC;
```

### 2.6 查看在线机器

```sql
SELECT m.id, m."lastActiveAt", a.username
FROM "Machine" m JOIN "Account" a ON m."accountId" = a.id
WHERE m.active = true;
```

### 2.7 检查前提条件

在 psql 中依次运行，确认数据满足验证要求：

```sql
-- 至少 1 个账户？
SELECT COUNT(*) AS account_count FROM "Account";

-- 至少 1 个会话？
SELECT COUNT(*) AS session_count FROM "Session";

-- 至少 1 个有消息的会话？
SELECT COUNT(*) AS sessions_with_messages
FROM "Session" s
WHERE EXISTS (SELECT 1 FROM "SessionMessage" sm WHERE sm."sessionId" = s.id);

-- 至少 1 台在线机器？（Step 5-8 需要）
SELECT COUNT(*) AS active_machines FROM "Machine" WHERE active = true;
```

如果账户数为 0，需要先通过 Web 客户端或 API 创建一个测试账户。如果会话数为 0，需要先通过 happy-cli 创建一个会话。

输入 `\q` 退出 psql。

---

## 三、准备鸿蒙设备

### 3.1 开启开发者模式

1. 打开鸿蒙手机的 **设置**
2. 进入 **关于手机**
3. 连续点击 **版本号** 7 次，直到提示 "您已处于开发者模式"
4. 返回设置，进入 **系统和更新** → **开发人员选项**
5. 打开 **USB 调试** 开关
6. （可选）打开 **"仅充电"模式下允许 ADB 调试**

### 3.2 用 USB 连接手机到电脑

1. 用 USB-C 数据线连接手机和 Mac
2. 手机上弹出 "是否允许 USB 调试" 时，勾选 "始终允许"，点击 **确定**

### 3.3 安装 hdc 工具

hdc 是 HarmonyOS 的设备调试工具（类似 Android 的 adb）。如果你已安装 DevEco Studio，hdc 已在 PATH 中。

```bash
hdc version
```

如果找不到命令，hdc 通常位于：

```bash
# DevEco Studio 内置的 hdc
~/Library/Huawei/Sdk/openharmony/*/toolchains/hdc
```

将其加入 PATH 或直接用完整路径。

### 3.4 确认设备连接

```bash
hdc list targets
```

预期输出类似：`7001005458323933328a0cfb6010b00`（设备序列号）。

如果没有输出：
- 确认 USB 线连接正常
- 确认手机上已允许 USB 调试
- 尝试拔插 USB 重新连接

---

## 四、配置鸿蒙客户端的服务端地址

鸿蒙客户端默认连接 `https://api.cluster-fluster.com`（线上地址），本地验证需要切换到你的开发 Server。

有两种方式：

### 方式 A：代码中临时修改（推荐用于首次验证）

编辑 `packages/happy-harmony/common/src/main/ets/constants/ServerConfig.ets`，将第 14 行：

```typescript
const DEFAULT_SERVER_URL: string = 'https://api.cluster-fluster.com';
```

改为（替换为你实际的 Mac IP）：

```typescript
const DEFAULT_SERVER_URL: string = 'http://192.168.x.x:3005';
```

> 注意使用 `http://` 而非 `https://`，本地开发 Server 没有配置 SSL。

### 方式 B：运行时通过 App 设置修改

如果 App 内有设置页面可以修改 Server URL，在 App 启动后通过设置页面修改为 `http://192.168.x.x:3005`。

### 确认手机和电脑在同一局域网

```bash
# 在 Mac 上 ping 手机的 IP（可以在手机 Wi-Fi 设置中查看）
# 或者直接在手机浏览器中打开 http://192.168.x.x:3005/
# 如果显示 "Welcome to Happy Server!" 说明网络连通
```

---

## 五、构建并部署到手机

### 5.1 在 DevEco Studio 中打开项目

1. 打开 DevEco Studio
2. 选择 **Open**
3. 选择目录 `/Users/liepin/Documents/study/happy/packages/happy-harmony`

### 5.2 等待工程同步

DevEco Studio 会自动同步 ohpm 依赖。首次打开可能需要 5-10 分钟。等待底部状态栏不再显示同步进度。

### 5.3 确认签名配置

1. 菜单栏 **File** → **Project Structure**
2. 左侧选择 **Signing Configs**
3. 确认已配置签名（应已有 debug 签名）
4. 如果未配置，点击 **Sign in** 登录华为开发者账号，然后勾选 **Automatically generate signature**

### 5.4 选择目标设备

DevEco Studio 顶部工具栏，设备下拉框中应显示你连接的鸿蒙手机名称。选择它。

### 5.5 构建并运行

点击工具栏的 **Run** 按钮（绿色三角形），或按 `Shift + F10`。

首次编译约需 3-5 分钟。看到手机上 App 自动打开即部署成功。

---

## 六、分步验证流程

### Step 1: 应用启动与认证 (M4-M6)

**目标**: 验证 Phase 2 的认证链路在 Phase 3 代码下仍然正常。

**准备**：打开一个新的终端窗口，启动日志监控：

```bash
hdc shell hilog | grep -E "IndexPage|SessionsPage|ChatPage|SyncEngine|WsTransport|AppViewModel|SessionRpc|MachineRpc|EncryptionService|DataKeyManager|ServerConfig"
```

| # | 操作 | 预期结果 | 日志关键字 |
|---|------|----------|-----------|
| 1.1 | 冷启动 App | libsodium 初始化成功，检查凭据 | `IndexPage`, `libsodium initialized` |
| 1.2 | 有凭据时 | 自动跳转到 SessionsPage（显示 Loading → 数据加载完成） | `User authenticated`, `navigating to sessions` |
| 1.3 | 无凭据时（新装） | 显示 Create Account / Restore Account | `No stored credentials` |
| 1.4 | 创建新账户 | 生成密钥对、调用 `POST /v1/auth`、存储凭据、跳转 SessionsPage | `Account created` |
| 1.5 | 恢复账户 | 扫码或手动输入 secret，验证签名，登录成功 | `Account restored` |
| 1.6 | 杀进程后重启（上滑杀掉 App，重新打开） | 自动登录，直达 SessionsPage | `restoreSession` success |

**检查点**:
- [ ] 日志中能看到 `AppViewModel initialized successfully`
- [ ] 日志中能看到 `Sync complete: N sessions, M machines`
- [ ] 日志中能看到 `WebSocket connected`

**常见问题**:

| 问题 | 原因 | 解决 |
|------|------|------|
| App 启动后白屏/闪退 | libsodium.so 加载失败 | 检查 `libs/arm64-v8a/libsodium.so` 是否存在 |
| 创建账户报网络错误 | 手机无法访问 Server | 确认手机和 Mac 同一局域网，ping 192.168.x.x:3005 |
| 创建账户报 500 错误 | Server 端问题 | 查看 Server 终端的错误日志 |
| 无法连接 `http://` 地址 | 明文流量被阻止 | 检查手机是否开启了"仅安全连接"等限制 |

### Step 2: WebSocket 连接与心跳 (M7)

**目标**: 验证 WebSocket 稳定连接和心跳机制。

| # | 操作 | 预期结果 | 日志关键字 |
|---|------|----------|-----------|
| 2.1 | 进入 SessionsPage 后 | WebSocket 连接建立 | `WsTransport connected`, `WebSocket connected` |
| 2.2 | 等待 25 秒 | 收到心跳 ping，服务端返回 pong | `heartbeat ping`, `pong received` |
| 2.3 | 切到后台再回来 | 连接保持或自动重连 | `reconnecting`, `reconnected` |
| 2.4 | 断开网络再恢复（关闭 Wi-Fi → 等 5 秒 → 重新打开） | 3 次心跳超时后标记断开，网络恢复后重连 | `connection lost`, `reconnected` |

**检查点**:
- [ ] `AppStorage.IS_CONNECTED` 为 `true`
- [ ] 心跳间隔约 25 秒，超时 10 秒
- [ ] 连接断开后 UI 有相应提示（至少日志可见）

**同时检查 Server 日志**：

在 Server 终端中应能看到连接/断开日志。如果开启了 `DANGEROUSLY_LOG_TO_SERVER_FOR_AI_AUTO_DEBUGGING=true`，日志会记录到 `packages/happy-server/.logs/` 目录。

### Step 3: 会话列表加载 (M8)

**目标**: 验证 REST 初始拉取 + 解密 + 列表渲染。

**前提**: 数据库中已有会话数据（参见第二节 2.7 检查）。

| # | 操作 | 预期结果 | 日志关键字 |
|---|------|----------|-----------|
| 3.1 | 进入 SessionsPage | 会话列表显示，标题已解密 | `Sync complete` |
| 3.2 | 检查每个 SessionItem | 标题、最后消息预览、相对时间正确显示 | — |
| 3.3 | 点击 Machines 按钮 | 机器面板展开，在线机器显示绿色状态 | — |
| 3.4 | 空账户 | 显示 EmptyStateView "No Sessions" | — |
| 3.5 | 下拉刷新（如已实现） | 重新拉取并刷新列表 | `Data changed - UI refreshed` |

**检查点**:
- [ ] 会话标题是明文（非加密密文）
- [ ] 机器列表中在线/离线状态正确
- [ ] `LazyForEach` 滚动流畅，无明显卡顿
- [ ] 长列表（> 50 条）滚动无 OOM

**常见问题**:

| 问题 | 原因 | 解决 |
|------|------|------|
| 会话标题显示为乱码/Base64 | DEK 解密失败 | 新设备首次看到会话时 DEK 不可用，属于正常（Step 10 验证） |
| 列表为空但数据库有数据 | 认证账户不匹配 | 确认手机登录的账户与数据库中有会话的账户是同一个 |

### Step 4: 进入聊天页 (M9)

**目标**: 验证消息加载、解密和渲染。

**前提**: 数据库中有带消息的会话（参见第二节 2.4 检查）。

| # | 操作 | 预期结果 | 日志关键字 |
|---|------|----------|-----------|
| 4.1 | 点击一个有消息的会话 | 跳转 ChatPage，标题栏显示会话名称 | `Session loaded: N messages` |
| 4.2 | 检查消息列表 | 消息按时间排序，用户消息靠右，agent 消息靠左 | — |
| 4.3 | 检查消息内容 | 文本消息正确解密显示 | — |
| 4.4 | 检查特殊消息 | `tool-call-start/end` 显示工具名称，`turn-start/end` 显示分隔线 | — |
| 4.5 | 检查 ThinkingIndicator | 如果 agent 正在思考，显示 "Thinking..." 动画 | — |
| 4.6 | 检查 CodeBlock | 代码块有语法高亮/背景色区分 | — |
| 4.7 | 检查 DiffView | diff 块有增/删行颜色区分 | — |
| 4.8 | 点击返回 | 回到 SessionsPage，列表状态保持 | — |

**检查点**:
- [ ] 消息内容完全解密（无乱码、无 Base64 密文）
- [ ] 空会话显示 "No messages yet" 空态
- [ ] 加载中显示 LoadingIndicator
- [ ] 加载失败显示错误信息

### Step 5: 发送消息与实时接收

**目标**: 验证消息发送链路和 WebSocket 实时推送。

**前提**: 需要一台在线的 machine daemon 运行 Claude Code agent。

**如何启动本地 daemon**：

```bash
# 在项目根目录，使用 happy-cli 启动 daemon
cd /Users/liepin/Documents/study/happy
yarn cli daemon start

# 或手动启动 Claude Code agent
yarn cli session start
```

确认 daemon 已上线：

```bash
# 在 psql 中检查
psql -h localhost -p 5432 -U postgres -d handy -c "SELECT id, active FROM \"Machine\" WHERE active = true;"
```

| # | 操作 | 预期结果 | 日志关键字 |
|---|------|----------|-----------|
| 5.1 | 在输入框输入文本 | 键盘弹出，输入正常 | — |
| 5.2 | 点击发送 | 消息立即出现在列表中（乐观更新），状态变为 "Thinking..." | `Message sent` |
| 5.3 | 等待 agent 回复 | agent 消息通过 WebSocket 推送并自动出现在列表中 | `handleNewMessage` |
| 5.4 | ThinkingIndicator | agent 处理期间显示动画，回复完成后消失 | — |
| 5.5 | 发送多条消息 | 消息顺序正确，无重复或丢失 | — |
| 5.6 | 切到后台再回来 | 新消息仍然能收到 | — |

**检查点**:
- [ ] 发送后消息立即出现在列表底部（乐观更新）
- [ ] agent 回复后消息自动追加，无需手动刷新
- [ ] 消息列表自动滚动到底部
- [ ] Thinking 状态正确显示/消失

### Step 6: 权限审批 (M10)

**目标**: 验证 agent 工具调用的权限审批流程。

**前提**: 需要一个会话中 agent 会触发需要权限的工具（如文件写入、bash 命令）。可以发送类似 "帮我在桌面创建一个 hello.txt 文件" 这样的消息来触发。

| # | 操作 | 预期结果 | 日志关键字 |
|---|------|----------|-----------|
| 6.1 | 发送触发工具调用的消息 | PermissionDialog 弹出，显示工具名称和参数 | — |
| 6.2 | 点击 Approve | 调用 `SessionRpc.allow()`，agent 继续执行 | `rpc-call`, `allow` |
| 6.3 | 发送另一个触发消息 | 新的 PermissionDialog 弹出（FIFO 队列） | — |
| 6.4 | 点击 Deny | 调用 `SessionRpc.deny()`，agent 收到拒绝 | `deny` |
| 6.5 | 多个权限请求排队 | 依次弹出，每次只显示一个 | — |
| 6.6 | 检查切换审批模式 | 如果支持 always-allow 模式切换 | `switchMode` |

**检查点**:
- [ ] PermissionDialog 正确显示工具名称、描述
- [ ] 参数可折叠/展开查看
- [ ] Approve/Deny 后 dialog 消失，agent 行为符合预期
- [ ] 多个请求排队不丢失

### Step 7: 新建会话 (M11)

**目标**: 验证完整的新建会话流程。

| # | 操作 | 预期结果 | 日志关键字 |
|---|------|----------|-----------|
| 7.1 | 点击 SessionsPage 的 "+" 按钮 | 跳转 NewSessionPage | — |
| 7.2 | 选择 AI Profile | Default / Coding / Analysis 选项可选 | — |
| 7.3 | 输入工作目录 | 目录路径输入正常 | — |
| 7.4 | 点击 Next → PickMachinePage | 显示在线机器列表 | — |
| 7.5 | 选择一台在线机器 | 机器高亮选中 | — |
| 7.6 | 点击 Next → PickPathPage | 显示确认的目录路径 | — |
| 7.7 | 点击 Create | 调用 `MachineRpc.spawnHappySession()`，RPC 成功后跳转 ChatPage | `rpc-call`, `spawnHappySession` |
| 7.8 | 新会话出现在列表 | 返回 SessionsPage 能看到新创建的会话 | `Data changed - UI refreshed` |

**检查点**:
- [ ] RPC 调用成功（加密参数发送、解密响应）
- [ ] 新会话在列表中正确显示
- [ ] 能在新会话中发送消息
- [ ] 无在线机器时给出提示

### Step 8: RPC 操作验证

**目标**: 验证各种 RPC 操作的端到端可用性。

| # | 操作 | 预期结果 | RPC 方法 |
|---|------|----------|----------|
| 8.1 | 在 ChatPage 菜单中执行 abort | 会话终止 | `sessionId:abort` |
| 8.2 | 在 ChatPage 菜单中执行 kill | 会话被杀死 | `sessionId:killSession` |
| 8.3 | 在 SessionsPage 选中机器执行 stop daemon | daemon 停止 | `machineId:stopDaemon` |

**检查点**:
- [ ] RPC 请求发送成功（加密帧格式正确）
- [ ] RPC 响应解密成功
- [ ] 操作结果符合预期

### Step 9: 多设备同步验证

**目标**: 验证多端实时同步。

**如何启动 Web 客户端**：

```bash
# 在项目根目录
cd /Users/liepin/Documents/study/happy
yarn web
```

然后在浏览器打开 `http://localhost:3000`（具体端口看终端输出），登录同一个账户。

| # | 操作 | 预期结果 |
|---|------|----------|
| 9.1 | 在 Web 端发送消息 | 鸿蒙端实时收到新消息 |
| 9.2 | 在鸿蒙端发送消息 | Web 端实时收到 |
| 9.3 | 在 Web 端新建会话 | 鸿蒙端会话列表更新 |
| 9.4 | 在 Web 端删除会话 | 鸿蒙端会话列表更新 |

**检查点**:
- [ ] 双端数据最终一致
- [ ] WebSocket `update` 事件正确触发 UI 刷新

### Step 10: 异常场景与边界测试

| # | 操作 | 预期结果 |
|---|------|----------|
| 10.1 | 无网络时启动 App（关闭 Wi-Fi 和数据） | 显示错误提示，不崩溃 |
| 10.2 | WebSocket 连接中断后恢复 | 自动重连，数据恢复 |
| 10.3 | DEK 解密失败（新设备首次看到会话） | 会话显示但标题为空，不崩溃 |
| 10.4 | 快速连续点击发送（连点 10 次） | 消息不重复 |
| 10.5 | 超长消息（> 4000 字符） | 正常发送和显示 |
| 10.6 | 特殊字符消息（emoji、换行、代码片段） | 正常显示 |
| 10.7 | 大量会话（> 100） | 列表滚动流畅 |
| 10.8 | 大量消息（> 500） | 消息列表滚动流畅 |
| 10.9 | 退出登录后重新登录 | WebSocket 断开后重连，数据重新加载 |

---

## 七、验证工具与调试方法

### 7.1 鸿蒙设备日志查看

```bash
# 实时查看所有关键模块日志
hdc shell hilog | grep -E "IndexPage|SessionsPage|ChatPage|SyncEngine|WsTransport|AppViewModel|SessionRpc|MachineRpc|EncryptionService|DataKeyManager"

# 只看错误日志
hdc shell hilog -r && hdc shell hilog | grep -iE "error|fail|crash"

# 清除旧日志后重新捕获
hdc shell hilog -r
```

### 7.2 服务端日志查看

```bash
# Server 终端直接看输出（如果用 yarn dev 启动）

# 如果开启了文件日志，查看最新日志
ls -la packages/happy-server/.logs/*.log | tail -5
tail -100 packages/happy-server/.logs/*.log

# 搜索错误
tail -500 packages/happy-server/.logs/*.log | grep -iE "error|fail"

# 监控 WebSocket 连接
tail -200 packages/happy-server/.logs/*.log | grep -iE "websocket|connected|disconnected"

# 监控 RPC 调用
tail -200 packages/happy-server/.logs/*.log | grep -iE "rpc|spawn"
```

### 7.3 关键日志标记

| 标记 | 含义 |
|------|------|
| `libsodium initialized` | FFI 加载成功 |
| `User authenticated` | 认证恢复成功 |
| `AppViewModel initialized successfully` | 初始化完成（含 SyncEngine + WebSocket） |
| `Sync complete: N sessions, M machines` | REST 拉取完成 |
| `WebSocket connected` | WebSocket 连接建立 |
| `heartbeat ping` / `pong received` | 心跳正常 |
| `connection lost` | 连接断开 |
| `handleNewMessage` | 收到新消息推送 |
| `Data changed - UI refreshed` | 实时更新回调触发 |
| `handleNewSession` | 收到新会话推送 |
| `rpc-call` | RPC 请求发出 |
| `DEK decrypted` | 数据密钥解密成功 |
| `Failed to decrypt` | 解密失败（需关注） |
| `AppViewModel disposed` | 退出登录清理完成 |

### 7.4 数据库实时检查

验证过程中可以随时用 psql 确认数据状态：

```bash
# 快速查看会话数和消息数
psql -h localhost -p 5432 -U postgres -d handy -c "
  SELECT
    (SELECT COUNT(*) FROM \"Session\") as sessions,
    (SELECT COUNT(*) FROM \"SessionMessage\") as messages,
    (SELECT COUNT(*) FROM \"Machine\" WHERE active = true) as active_machines;
"
```

### 7.5 网络抓包（可选）

如需验证 WebSocket 帧格式，可通过 Charles/mitmproxy 代理抓包：
- 过滤 `v1/ws` 路径
- 检查 JWT token 认证
- 检查 ping/pong 心跳帧
- 检查 `update` / `ephemeral` 事件帧

---

## 八、通过标准总表

| 里程碑 | 验证项 | 通过条件 |
|--------|--------|----------|
| M4 | 创建账户并登录 | 注册、登录、凭据持久化均成功 |
| M5 | 恢复已有账户 | 扫码/手动恢复后数据一致 |
| M6 | 自动登录 | 杀进程重启后直达 SessionsPage |
| M7 | WebSocket 连接稳定 | 心跳正常，断线重连 |
| M8 | 会话列表正常显示 | 标题解密、机器状态正确 |
| M9 | 发送消息并看到 agent 回复 | 乐观更新 + 实时推送 |
| M10 | 权限审批可用 | Dialog 弹出、Approve/Deny 生效 |
| M11 | 能新建会话 | RPC spawn 成功、列表更新 |
| M12 | 多端同步 | 双端数据一致 |
| M13 | 异常场景不崩溃 | 断网、快速操作、边界数据均正常 |

---

## 九、优先级排序

**P0（必须通过，否则 Phase 3 不算完成）**:
1. Step 1: 应用启动与认证
2. Step 2: WebSocket 连接与心跳
3. Step 3: 会话列表加载
4. Step 4: 聊天页消息显示
5. Step 5: 发送与接收消息

**P1（核心功能）**:
6. Step 6: 权限审批
7. Step 7: 新建会话
8. Step 8: RPC 操作

**P2（体验和稳定性）**:
9. Step 9: 多设备同步
10. Step 10: 异常场景

---

## 附录：快速启动清单（每次验证前复制粘贴）

```bash
# === 终端 1：启动 Server ===
cd /Users/liepin/Documents/study/happy/packages/happy-server
touch .env      # 确保 .env 存在（yarn dev 会加载它）
yarn db         # 启动 PostgreSQL（如果还没启动）
yarn s3         # 启动 MinIO（如果还没启动，Server 依赖此服务）
yarn dev        # 启动 Server

# === 终端 2：查看本机 IP + 启动日志监控 ===
ifconfig | grep "inet " | grep -v 127.0.0.1   # 记下 IP
hdc shell hilog | grep -E "IndexPage|SessionsPage|ChatPage|SyncEngine|WsTransport|AppViewModel"

# === 终端 3（按需）：查看数据库 ===
psql -h localhost -p 5432 -U postgres -d handy   # 密码: postgres
```

然后在 DevEco Studio 中 Run 到手机即可开始验证。
