# Happy

随时随地编程——从手机端控制 AI 编程代理。

免费。开源。随处编程。

## 安装

```bash
npm install -g happy-coder
```

## 从源码运行

从已检出的仓库开始：

```bash
# 仓库根目录
yarn cli --help

# 包目录
yarn cli --help
```

## 使用

### Claude（默认）

```bash
happy
```

这将：
1. 启动一个 Claude Code 会话
2. 显示二维码，以便在手机端连接
3. 允许 Claude Code 与你的移动端应用之间进行实时会话共享

### Gemini

```bash
happy gemini
```

启动具备远程控制能力的 Gemini CLI 会话。

**首次设置：**
```bash
# 使用 Google 完成身份验证
happy connect gemini
```

## 命令

### 主命令

- `happy` – 启动 Claude Code 会话（默认）
- `happy gemini` – 启动 Gemini CLI 会话
- `happy codex` – 启动 Codex 模式
- `happy acp` – 启动通用 ACP 兼容型代理

### 实用命令

- `happy auth` – 管理身份验证
- `happy connect` – 将 AI 供应商 API keys 存储到 Happy 云端
- `happy sandbox` – 配置沙箱运行时限制
- `happy notify` – 向你的设备发送推送通知
- `happy daemon` – 管理后台服务
- `happy doctor` – 系统诊断与故障排查

### 连接子命令

```bash
happy connect gemini     # 为 Gemini 使用 Google 完成身份验证
happy connect claude     # 为 Anthropic 完成身份验证
happy connect codex      # 为 OpenAI 完成身份验证
happy connect status     # 显示所有供应商的连接状态
```

### Gemini 子命令

```bash
happy gemini                      # 启动 Gemini 会话
happy gemini model set <model>    # 设置默认模型
happy gemini model get            # 显示当前模型
happy gemini project set <id>     # 设置 Google Cloud Project ID（适用于 Workspace 账号）
happy gemini project get          # 显示当前 Google Cloud Project ID
```

**可用模型：** `gemini-2.5-pro`, `gemini-2.5-flash`, `gemini-2.5-flash-lite`

### 通用 ACP 命令

```bash
happy acp gemini                     # 运行内置的 Gemini ACP 命令
happy acp opencode                   # 运行内置的 OpenCode ACP 命令
happy acp opencode --verbose         # 包含原始后端/信封日志
happy acp -- custom-agent --flag     # 直接运行任意 ACP 兼容命令
```

### 沙箱子命令

```bash
happy sandbox configure  # 交互式沙箱设置向导
happy sandbox status     # 显示当前沙箱配置
happy sandbox disable    # 禁用沙箱
```

## 选项

### Claude 选项

- `-m, --model <model>` - 要使用的 Claude 模型（默认：sonnet）
- `-p, --permission-mode <mode>` - 权限模式：auto、default 或 plan
- `--claude-env KEY=VALUE` - 为 Claude Code 设置环境变量
- `--claude-arg ARG` - 向 Claude CLI 传递额外参数

### 全局选项

- `-h, --help` - 显示帮助信息
- `-v, --version` - 显示版本号
- `--no-sandbox` - 禁用当前 Claude/Codex 运行的沙箱

## 环境变量

### Happy 配置

- `HAPPY_SERVER_URL` - 自定义服务器 URL（默认：https://api.cluster-fluster.com）
- `HAPPY_WEBAPP_URL` - 自定义 Web 应用 URL（默认：https://app.happy.engineering）
- `HAPPY_HOME_DIR` - Happy 数据的自定义主目录（默认：~/.happy）
- `HAPPY_DISABLE_CAFFEINATE` - 禁用 macOS 的防睡眠（设置为 `true`、`1` 或 `yes`）
- `HAPPY_EXPERIMENTAL` - 启用实验性功能（设置为 `true`、`1` 或 `yes`）

### Gemini 配置

- `GEMINI_MODEL` - 覆盖默认 Gemini 模型
- `GOOGLE_CLOUD_PROJECT` - Google Cloud Project ID（Workspace 账号必需）

## Gemini 认证

### 个人 Google 账号

个人 Gmail 账号开箱即用：

```bash
happy connect gemini
happy gemini
```

### Google Workspace 账号

Google Workspace（组织）账号需要一个 Google Cloud Project：

1. 在 [Google Cloud Console](https://console.cloud.google.com/) 中创建一个项目
2. 启用 Gemini API
3. 设置项目 ID：

```bash
happy gemini project set your-project-id
```

或使用环境变量：
```bash
GOOGLE_CLOUD_PROJECT=your-project-id happy gemini
```

**指南：** https://goo.gle/gemini-cli-auth-docs#workspace-gca

## 贡献

有兴趣参与贡献吗？请参阅 [CONTRIBUTING.md](CONTRIBUTING.md) 了解开发设置与规范。

## 需求

- Node.js >= 20.0.0

### 针对 Claude

- 已安装并完成登录的 Claude CLI（`claude` 命令在 PATH 中可用）

### 针对 Gemini

- 已安装 Gemini CLI（`npm install -g @google/gemini-cli`）
- 使用 `happy connect gemini` 完成 Google 账号身份验证

## 许可证

MIT
