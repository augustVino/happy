# Unistyles 样式指南

## 创建样式

```typescript
import { StyleSheet } from 'react-native-unistyles'

const styles = StyleSheet.create((theme, runtime) => ({
    container: {
        flex: 1,
        backgroundColor: theme.colors.background,
        paddingTop: runtime.insets.top,
        paddingHorizontal: theme.margins.md,
    },
    text: {
        color: theme.colors.typography,
        fontSize: 16,
    }
}))
```

## 使用样式

React Native 组件直接提供样式：

```typescript
const MyComponent = () => (
    <View style={styles.container}>
        <Text style={styles.text}>Hello</Text>
    </View>
)
```

其他组件使用 `useStyles` hook：

```typescript
const { styles } = useStyles(styles)
```

## 变体

```typescript
const styles = StyleSheet.create(theme => ({
    button: {
        paddingHorizontal: 16,
        paddingVertical: 8,
        borderRadius: 8,
        variants: {
            color: {
                primary: { backgroundColor: theme.colors.primary },
                secondary: { backgroundColor: theme.colors.secondary },
            },
            size: {
                small: { paddingHorizontal: 8, paddingVertical: 4 },
                large: { paddingHorizontal: 24, paddingVertical: 12 },
            }
        }
    }
}))

const { styles } = useStyles(styles, { button: { color: 'primary', size: 'large' } })
```

## 媒体查询

```typescript
import { StyleSheet, mq } from 'react-native-unistyles'

const styles = StyleSheet.create(theme => ({
    container: {
        backgroundColor: {
            [mq.only.width(0, 768)]: theme.colors.background,
            [mq.only.width(768)]: theme.colors.secondary,
        }
    }
}))
```

## 断点

```typescript
const { breakpoint } = useStyles()
const isTablet = breakpoint === 'md' || breakpoint === 'lg'
```

## Expo Image 特殊处理

`width`/`height` 和 `tintColor` 必须在组件上直接设置，不能通过 Unistyles：

```typescript
<Image
    style={[{ width: 100, height: 100 }, styles.image]}
    tintColor={theme.colors.primary}
    source={{ uri: 'https://example.com/image.jpg' }}
/>
```

## 最佳实践

1. 始终用 `StyleSheet.create` from `react-native-unistyles`
2. RN 和 Reanimated 组件直接提供样式，其他用 `useStyles` hook
3. 需要主题/运行时访问时使用函数模式
4. 用 variants 代替条件样式
5. 用断点代替手动计算尺寸
6. 样式定义放在组件/页面文件的**最末尾**
