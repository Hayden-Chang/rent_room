# 寻居纯图标启动屏 · 视觉评审

本稿对应用户确认的品牌启动屏，以及最新要求「用图标，不需要小搭，不需要任何文字」。当前为可独立运行的 SwiftUI 组件；尚未接入正式启动、初始化、首页导航或系统 LaunchScreen。

## 设计

- 仅显示一个房屋图标；不显示小搭、标题、副标题、底部文案或其他文字。
- 复用 `apps/wechat/src/assets/icons/home-selected.svg` 的原始房屋线条与蓝紫色 `#4D56DF`。单独的矢量资源保留清晰度，不改动现有导航图标。
- 图标画布为 96 × 96 pt，在全屏水平与垂直居中；背景使用现有 `XJTheme.background`（`#F5F7FB`），连续覆盖安全区。
- 保留不可见的辅助功能名称「寻居」，供读屏识别；界面没有文字。
- 静态、无按钮、无动画、无倒计时、无网络依赖。外观沿用 App 的浅色约定。

Figma 插件未连接，尚未同步设计主稿。

## 预览与接入边界

Debug 启动参数：`--component-review brand-launch`。该入口复用现有 `#if DEBUG` 评审宿主，不创建 `AppWorkspace`，不读写用户房源或账号。Release 不识别评审参数。

用户确认外观后，再处理系统启动背景与真实初始化阶段之间的衔接。不要人为延长启动时间。当前证据只验证组件渲染，不证明冷启动切换或时长。

## 验证映射

| 变更 | 定向验证 |
| --- | --- |
| Debug 评审入口与其他启动参数的隔离 | `XunjuTests/ComponentLogicTests/testReviewHostRequiresExplicitKnownSurface` |
| 图标可见、全屏居中、无文字、仅一个图像、无按钮 | `XunjuUITests/BrandLaunchReviewTests/testBrandComposition` |

纯图标没有字号布局，已移除上一稿的辅助字号测试。使用共享模拟器 runner、项目 XcodeGen 包装脚本和已有超时配置，只执行上述 2 条定向用例。

## 证据

状态：`COMPONENT_BUILDING`。上一稿的小搭和文字截图已失效，本次需要重新生成原生证据并由用户确认。

原始证据将保存在任务 worktree 下 `artifacts/launch-icon-20261030/`，不提交构建产物。完成后记录实际 SHA、设备、结果包与图片尺寸。
