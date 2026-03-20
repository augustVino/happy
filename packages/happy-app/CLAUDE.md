# Happy App

React Native (Expo) + Web 客户端，含 Tauri macOS 桌面版。

## 命令

| 命令 | 说明 |
|------|------|
| `yarn start` | Expo 开发服务器 |
| `yarn ios` / `yarn android` | 原生运行 |
| `yarn web` | Web 浏览器运行 |
| `yarn prebuild` | 生成原生目录 |
| `yarn typecheck` | TypeScript 类型检查 |
| `yarn test` | Vitest 测试 |
| `yarn tauri:dev` | macOS 桌面开发 |
| `yarn ota` | EAS Update 生产部署 |

## 开发规范

- 路径别名 `@/*` → `./sources/*`
- 4 空格缩进
- TypeScript strict 模式
- 样式定义放在组件/页面文件**最末尾**
- 页面始终用 `memo` 包裹
- 非平凡 hook → 在 `hooks/` 创建专用 hook 并注释说明逻辑

### 核心原则

- **不做向后兼容**（除非明确要求）
- **永远不显示加载错误**，自动重试
- 主数据通过 "sync" class 同步，始终使用 invalidate sync
- 优先使用 `Item` 组件和 `ItemList` 容器
- 使用 `useHappyAction`（`@sources/hooks/useHappyAction.ts`）处理异步操作
- **禁止使用** React Native 的 `Alert`，用 `@/modal` 代替
- 全屏 ScrollView 和内容容器使用 `@/components/layout` 的宽度约束
- 始终使用 expo-router API，不用 react-navigation API
- 导航中避免自定义 header，尽量不用 Stack.Screen options
- 页面参数尽可能在 `_layout.tsx` 中设置（避免布局偏移）
- 使用 `Avatar` 组件显示头像
- Web 热键使用 `useGlobalKeyboard`
- 异步锁使用 `AsyncLock` 类
- 临时脚本放 `sources/trash/`
- **Expo Image 不用 Unistyles**，用经典样式
- 用户可见字符串一律用 `t()` 翻译，开发页面除外

## 详细文档

- [架构概览](.claude/docs/architecture.md) — 技术栈、项目结构、核心模式
- [Unistyles 样式指南](.claude/docs/unistyles.md) — 样式创建、变体、媒体查询
- [国际化指南](.claude/docs/i18n.md) — t() 用法、添加翻译、语言配置
- [Changelog 管理](.claude/docs/changelog.md) — 版本记录规范
