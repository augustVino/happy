# Session Forking：`--resume` 行为

## 运行的命令

### 初始会话

```bash
claude --print --output-format stream-json --verbose 'list files in this directory'
```
- 原始 Session ID: `aada10c6-9299-4c45-abc4-91db9c0f935d`
- 创建文件: `~/.claude/projects/.../aada10c6-9299-4c45-abc4-91db9c0f935d.jsonl`

### 使用 --resume 恢复

```bash
claude --print --output-format stream-json --verbose --resume aada10c6-9299-4c45-abc4-91db9c0f935d 'what file did we just see?'
```
- 新 Session ID: `1433467f-ff14-4292-b5b2-2aac77a808f0`
- 创建新文件: `~/.claude/projects/.../1433467f-ff14-4292-b5b2-2aac77a808f0.jsonl`

## 关键发现

### Session 文件行为
- 创建**新** session 文件，分配**新** session ID
- 原始 session 文件保持不变
- 恢复后存在两个独立文件

### 历史保留
- 新 session 文件包含原始会话的**完整历史**
- 历史记录前置于新文件开头
- 包含一行摘要

### Session ID 重写
- 所有历史消息的 `sessionId` 字段**更新为新 ID**
- 在新 ID 下统一历史记录

### 新文件结构
```
Line 1:         前序对话摘要
Lines 2-6:      完整历史（sessionId 已更新）
Lines 7-8:      当前交互的新消息
```

## 对 CLI 的影响

使用 `--resume` 时：
1. 必须处理响应中的新 session ID
2. 原始 session 作为历史记录保留
3. 所有上下文在新 ID 下保留
4. `stream-json` 输出中的 session ID 是新 ID
