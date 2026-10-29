# 寻居品牌启动屏 · 视觉评审

本稿对应用户确认的「打开 App 时短暂出现的品牌启动屏」。目前是可独立运行的 SwiftUI 组件；未接入正式启动、初始化、首页导航或系统 LaunchScreen。

## 设计

- 使用当前 iOS 工程的显示名「寻居」，副标题「看房手记」。
- 复用已存在的 `xiaoda-idle` 房屋角色，不新造品牌标志或增加图片下载。
- 背景沿用 `XJTheme.background`（`#F5F7FB`），文字沿用 `ink` 和 `muted`。标题与背景对比度约 14.15:1，辅助文字约 4.58:1。
- 132 pt 小搭，下面留 24 pt，再显示 32 pt 半粗标题；标题下间隔 12 pt 放 13 pt 副标题。字体随系统字号缩放。
- 标识组居中，底部文案「看房有记录，选家更有底」距底部安全区 32 pt，两侧保留 32 pt。
- 静态、无交互、无网络依赖、无倒计时。浅色与当前 App 一致；未另行设计深色模式。

设计资源直接来自现有工程。Figma 插件在本次会话中没有连接，尚未同步到设计主稿。

## 预览与后续接入边界

Debug 启动参数：`--component-review brand-launch`。该入口复用现有 `#if DEBUG` 评审宿主，不创建 `AppWorkspace`，不读写用户房源或账号。Release 不识别评审参数。

用户确认外观后，再处理系统启动背景与真实初始化阶段之间的衔接。不要为展示品牌而人为延长启动时间，不用网络请求决定屏幕的固定停留时间。系统启动页和 App 内品牌屏应分别实现与验证；当前截图只证明组件渲染，不证明真实冷启动切换。

Apple 参考：[Launching](https://developer.apple.com/design/human-interface-guidelines/launching)、[Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding)。系统 LaunchScreen 应尽可能贴近首屏；品牌内容放在 App 已启动后的界面。

## 验证映射

| 变更 | 定向验证 |
| --- | --- |
| 增加 Debug 评审入口 | `XunjuTests/ComponentLogicTests/testReviewHostRequiresExplicitKnownSurface` |
| 默认布局、文字、居中、屏内边界、无按钮 | `XunjuUITests/BrandLaunchReviewTests/testBrandComposition` |
| 最大辅助字号、文字完整性与顺序 | `XunjuUITests/BrandLaunchReviewTests/testBrandCompositionWithAccessibilityText` |

使用共享模拟器 runner 和项目 XcodeGen 包装脚本；不运行全量测试。无业务逻辑变更，未选择其他业务用例。

## 证据

代码提交：`f74bb36d67980a4e28cd8e55fb72bc7b970c3034`。运行编号：`xunju-brand-launch-20261030-01`。

计划与日志位于当前 worktree 的 `artifacts/launch-page-20261030/`。测试、截图检查及视觉批准结果将在完成后记录。
