# 寻居品牌 Logo 启动屏 · 视觉评审

用户确认沿用小程序现有的蓝紫底、白色「房屋＋对勾」Logo，并继续要求没有文字、没有小搭。当前为可独立运行的 SwiftUI 组件；尚未接入正式启动、初始化、首页导航或系统 LaunchScreen。

## 设计

- 直接复用 `output/branding/看房搭子-小程序头像-v2.png`，逐字节复制为受 Git 跟踪的生产资源 `brand-launch-icon.imageset/mini-program-logo.png`。应用构建不依赖本地 output 目录。
- 保持原图的蓝紫底、白色房屋与对勾，不重绘、不改色。以 112 × 112 pt 展示，使用 26 pt 连续圆角，无阴影或额外装饰。
- Logo 在全屏水平、垂直居中；背景沿用 `XJTheme.background`（`#F5F7FB`），连续覆盖安全区。
- 不显示小搭、标题、副标题或底部文案。保留不可见的辅助功能名称「寻居」。
- 静态、无按钮、无动画、无倒计时、无网络依赖；沿用 App 浅色约定。

Figma 插件未连接，尚未同步设计主稿。

## 预览与接入边界

Debug 启动参数：`--component-review brand-launch`。该入口复用现有 `#if DEBUG` 评审宿主，不创建 `AppWorkspace`，不读写用户房源或账号。Release 不识别评审参数。

用户确认此版原生截图后，再处理真实启动衔接。当前只验证组件渲染，不证明冷启动切换或时长；不要人为延长启动时间。

## 验证映射

| 变更 | 定向验证 |
| --- | --- |
| Debug 评审入口与其他启动参数的隔离 | `XunjuTests/ComponentLogicTests/testReviewHostRequiresExplicitKnownSurface` |
| Logo 可见、全屏居中、无文字、仅一个图像、无按钮 | `XunjuUITests/BrandLaunchReviewTests/testBrandComposition` |
| 品牌素材来源一致 | 比较原始 v2 PNG 与生产资源的 SHA-256 |

沿用共享模拟器 runner、XcodeGen 包装脚本和每例 120 秒超时配置，只执行上述 2 条定向用例。

## 证据

状态：`COMPONENT_BUILDING`。用户已同意采用现有小程序 Logo；替换后的原生截图待生成。上一版通用房屋图标截图不能作为此版证据。

本轮产物保存在任务 worktree 下 `artifacts/launch-logo-20261030/`，不提交构建产物。
