# 寻居品牌启动屏 · 视觉评审

本稿对应用户确认的「打开 App 时短暂出现的品牌启动屏」。目前是可独立运行的 SwiftUI 组件；未接入正式启动、初始化、首页导航或系统 LaunchScreen。

## 设计

- 使用当前 iOS 工程的显示名「寻居」，副标题「看房手记」。
- 复用已存在的 `xiaoda-greet` 挥手房屋角色，不新造品牌标志或增加图片下载。素材检查发现 idle 图片左缘有裁切残留，因此选用更干净的 greet 资源。
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

状态：`REVIEW_READY`，待用户明确确认视觉。未接入启动业务、未合并、未部署真机。

- 证据代码 SHA：`94f5ad5670b9e7b6a430d64190ac22a5e40e6539`；基线 `eb75079b3e46726e5742cc4c861dc7a278d9dd31`。
- 最终运行：`xunju-brand-launch-20261030-05`，1 条单测 + 2 条 UI 测试，3 passed / 0 failed / 0 skipped。未运行全量测试。
- 设备：iPhone 14 Pro，iOS 18.3.1，arm64；UDID `8F178971-C203-4690-A83B-253046EACBB1`。
- 实际导出的两张 PNG 均为 **1178 × 2556 px**，393 × 852 pt 设备。保留原始截图尺寸，不缩放或裁切。
- XcodeGen **2.45.4** 两次生成一致。未修改 `project.yml`，未提交生成工程。
- 构建缓存由共享 runner 管理，实际路径为 `/Volumes/mac2/codex-builds/time-fragment-dd-shared-959ce06771d8a1a80f238b26-simulator`；旧前缀是基础设施命名，实际工程、scheme 和 targets 均为 Xunju。
- runner 退出码 0，设备租约和执行槽位均已释放。最终运行设置每条用例 120 秒上限，没有自动重试。

所有路径相对于本任务 worktree `/Volumes/mac2/projects/git_repo/run_self/rent_room/.worktrees/ios-launch-page-20261030`：

| 产物 | 路径 |
| --- | --- |
| 完整测试结果 | `artifacts/launch-page-20261030/review-05.xcresult` |
| 原始日志 | `artifacts/launch-page-20261030/runner-05.log` |
| 精确计划与可复现命令 | `artifacts/launch-page-20261030/plan-05.json`、`run-05.sh` |
| 结果摘要、截图哈希及附件映射 | `artifacts/launch-page-20261030/evidence-05.json` |
| 原始导出清单 | `artifacts/launch-page-20261030/attachments-05/manifest.json` |
| 默认字号截图 | `artifacts/launch-page-20261030/brand-launch-default.png` |
| 最大辅助字号截图 | `artifacts/launch-page-20261030/brand-launch-accessibility.png` |

主 agent 已检查两张实际截图：默认版标识与文字居中，浅灰白背景连续覆盖安全区；最大辅助字号下标题、副标题完整，底部文案分为两行，均不重叠、不越界。截图来自 Debug 原生组件宿主，不是设计合成图，也不证明正式冷启动时长或切页效果。

已单独复核最终 PR 的组件、Debug 入口、测试和验证范围，未发现阻断代码问题。后续证据记录只修改本文，不改变源码、测试、资源、配置或验证命令，因此可复用上述 SHA 的证据；不将其称为文档提交生成的截图。PR 保持 Draft，视觉批准与后续启动接入尚未发生。

### 前序运行及限制

第一次运行在排队结束时因新增说明文档触发冻结保护，未执行测试；第二次运行因素材复核调整而主动中断。第三次构建成功，但 `simctl list devices -j` 在测试启动前失败。第四次单测和默认截图用例通过，随后 iOS 26.5 / iPhone 16 的辅助字号查询与诊断截图通道挂起；该轮取消后结果包未完整收尾，只保留其日志和恢复出的原始 PNG 作诊断，不将其当作最终完整通过证据。

最终第五次由共享池分配到 iOS 18.3.1 / iPhone 14 Pro，完整通过并导出两张附件。不同运行、设备与结果包不混称；iOS 26.5 的辅助字号测试通道问题未被本次组件设计修复。

本轮未验收小屏、iPad 横屏、VoiceOver 实际朗读、系统深色外观和真实冷启动切换。组件没有动画；当前 App 固定浅色，未引入新的深色模式约定。Figma 尚未同步。
