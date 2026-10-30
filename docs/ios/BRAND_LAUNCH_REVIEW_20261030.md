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

状态：`REVIEW_READY`，等待用户明确确认此版视觉。

- 证据代码 SHA：`c9136a274c1f3ea22432f50b8ae4b7eaf7ff6469`，基线 `eb75079b3e46726e5742cc4c861dc7a278d9dd31`。
- 运行：`xunju-brand-launch-icon-20261030-01`。1 条单测 + 1 条 UI 测试，**2 passed / 0 failed / 0 skipped**。
- 设备：iPhone 16，iOS 26.5（23F77），arm64；UDID `5FC4A20B-AF44-4A92-BF91-B0096BEBF1D9`。
- 原始 PNG 为 **1178 × 2556 px**，未缩放或裁切。图标画布 96 × 96 pt，测试验证其中心与应用全屏中心一致，误差不超过 1 pt。
- XcodeGen 2.45.4 两次生成一致；未修改 `project.yml` 或提交生成工程。现有共享构建缓存复用成功。
- 共享 runner 退出码 0；本轮设备租约、执行槽位与队列条目均已释放。未自动重试测试。
- GitHub 查询未返回此提交的 PR workflow runs，不能将本地通过称为远端 CI 通过。

产物均位于任务 worktree `/Volumes/mac2/projects/git_repo/run_self/rent_room/.worktrees/ios-launch-page-20261030`：

| 产物 | 路径 |
| --- | --- |
| 完整测试结果 | `artifacts/launch-icon-20261030/review-01.xcresult` |
| 原始日志 | `artifacts/launch-icon-20261030/runner-01.log` |
| 精确计划与复现命令 | `artifacts/launch-icon-20261030/plan-01.json`、`run-01.sh` |
| 结果、截图哈希与附件映射 | `artifacts/launch-icon-20261030/evidence-01.json` |
| 原始附件清单 | `artifacts/launch-icon-20261030/attachments-01/manifest.json` |
| 纯图标原生截图 | `artifacts/launch-icon-20261030/brand-launch-icon-only.png` |

主 agent 已查看原生截图：浅灰白背景覆盖全屏，蓝紫色房屋轮廓清晰、居中；不显示小搭或品牌文案。系统状态栏仍显示。截图来自 XCUITest 的 Debug 组件宿主，不证明正式冷启动切页或启动时长。

已复核本次完整 diff：只涉及独立组件、其矢量资源、Debug 入口、定向测试和本说明，无业务工作区、数据或导航改动。后续文档证据提交不改变源码、资源、测试或配置，可复用上述 SHA 的截图；不把它称为文档提交生成的截图。PR 保持 Draft，未合并或部署。

上一稿的素材与文字截图仅作历史记录，不用于验收本次修订。本次未覆盖小屏、iPad、VoiceOver 实际朗读、深色模式或真实冷启动。Figma 尚未同步。
