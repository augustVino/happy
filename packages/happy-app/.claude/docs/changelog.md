# Changelog 管理

应用内含版本更新日志功能，向用户展示版本历史。

## 添加更新记录

1. 更新 `/CHANGELOG.md` 中最新版本
2. 格式：

```markdown
## Version [NUMBER] - YYYY-MM-DD
- 简短描述（用户视角）
- 另一项变更
```

3. 版本号递增（1, 2, 3...），日期用 ISO 格式

## 重新生成数据

```bash
npx tsx sources/scripts/parseChangelog.ts
```

生成 `sources/changelog/changelog.json` 供应用使用。

## 规范

- 每条记录以动词开头（Added, Fixed, Improved, Updated, Removed）
- 从用户视角撰写，聚焦变更内容而非技术细节
- 每个版本开头加一段主题概述
- `yarn ota` 时自动解析
