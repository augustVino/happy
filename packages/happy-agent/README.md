# Happy Agent

用于远程控制 Happy Coder 代理的 CLI 客户端。

不同于同时负责运行与控制代理的 `happy-cli`，`happy-agent` 仅负责对代理进行控制：创建会话、发送消息、读取历史记录、监控状态，并停止会话。

## 安装

来自 monorepo：

```bash
yarn workspace happy-agent build
```

或全局软链接：

```bash
cd packages/happy-agent && npm link
```

## 认证

Happy Agent 通过二维码进行账号认证，与在 Happy 移动端中绑定设备使用的流程相同。

```bash
# 使用 Happy 移动端扫描二维码进行认证
happy-agent auth login

# 查询认证状态
happy-agent auth status

# 清除已存储的凭据
happy-agent auth logout
```

凭据存储在 `~/.happy/agent.key`。

## 命令

### 列出会话

```bash
# 列出所有会话
happy-agent list

# 仅列出处于激活状态的会话
happy-agent list --active

# 以 JSON 输出
happy-agent list --json
```

### 会话状态

```bash
# 获取会话的实时状态（支持按 ID 前缀匹配）
happy-agent status <session-id>

# 以 JSON 输出
happy-agent status <session-id> --json
```

### 创建会话

```bash
# 使用标签创建新会话
happy-agent create --tag my-project

# 指定工作目录
happy-agent create --tag my-project --path /home/user/project

# 以 JSON 输出
happy-agent create --tag my-project --json
```

### 发送消息

```bash
# 向某个会话发送消息
happy-agent send <session-id> "Fix the login bug"

# 发送消息并等待代理完成
happy-agent send <session-id> "Run the tests" --wait

# 以 JSON 输出
happy-agent send <session-id> "Hello" --json
```

### 消息历史

```bash
# 查看消息历史
happy-agent history <session-id>

# 限制为最近 N 条消息
happy-agent history <session-id> --limit 10

# 以 JSON 输出
happy-agent history <session-id> --json
```

### 停止会话

```bash
happy-agent stop <session-id>
```

### 等待空闲

```bash
# 等待代理进入空闲状态（默认超时时间 300 秒）
happy-agent wait <session-id>

# 自定义超时时间
happy-agent wait <session-id> --timeout 60
```

当代理进入空闲状态时退出码为 `0`；超时则为 `1`。

## 环境变量

- `HAPPY_SERVER_URL` - API 服务器地址（默认值：`https://api.cluster-fluster.com`）
- `HAPPY_HOME_DIR` - 凭据存储目录（默认值：`~/.happy`）

## 会话 ID 匹配

所有接收 `<session-id>` 的命令都支持前缀匹配。你可以提供会话 ID 的前几个字符，CLI 将自动解析出完整 ID。

## 加密

所有会话数据都进行端到端加密。新会话使用带有每会话密钥的 AES-256-GCM。由其他客户端创建的既有会话将使用相应的密钥方案解密（AES-256-GCM 或传统 NaCl secretbox）。

## 需求

- Node.js >= 20.0.0
- 用于认证的 Happy 移动端账号

## 发布到 npm

维护者可以发布新版本：

```bash
yarn release               # 在仓库根目录执行：选择要发布的库
# 或直接：
yarn workspace happy-agent release
```

此流程：
- 通过 `prepublishOnly` 运行测试/构建检查
- 创建发布提交以及 `happy-agent-vX.Y.Z` 标签
- 生成说明并创建 GitHub release
- 将 `happy-agent` 发布到 npm

## 许可证

MIT
