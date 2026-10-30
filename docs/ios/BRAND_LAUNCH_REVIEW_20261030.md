# 寻居品牌 Logo 启动屏 · 接入与验证

用户确认沿用小程序现有的蓝紫底、白色「房屋＋对勾」Logo，并继续要求没有文字、没有小搭。用户随后以「可以的」批准原生视觉；同一组件现接入 AppRoot 的本机记录读取阶段，并配置系统 LaunchScreen。

## 设计

- 直接复用 `output/branding/看房搭子-小程序头像-v2.png`，逐字节复制为受 Git 跟踪的生产资源 `brand-launch-icon.imageset/mini-program-logo.png`。应用构建不依赖本地 output 目录。
- 保持原图的蓝紫底、白色房屋与对勾，不重绘、不改色。以 112 × 112 pt 展示，使用 26 pt 连续圆角，无阴影或额外装饰。
- Logo 在全屏水平、垂直居中；背景沿用 `XJTheme.background`（`#F5F7FB`），连续覆盖安全区。
- 显式设置与圆角 Logo 一致的辅助功能形状，保持读屏边界与显示区域一致。
- 不显示小搭、标题、副标题或底部文案。保留不可见的辅助功能名称「寻居」。
- 静态、无按钮、无动画、无倒计时、无网络依赖；沿用 App 浅色约定。

Figma 插件未连接，尚未同步设计主稿。

## 预览与接入边界

Debug 启动参数：`--component-review brand-launch`。该入口复用现有 `#if DEBUG` 评审宿主，不创建 `AppWorkspace`，不读写用户房源或账号。Release 不识别评审参数。

系统 LaunchScreen 使用 UIKit storyboard。圆角透明 PNG 由 `ios/scripts/render-launch-logo.swift` 以相同的 112 pt、26 pt 连续圆角、3 倍分辨率导出，背景和全屏中心与 SwiftUI 组件一致。AppRoot 读取完成后沿用既有设置页/房源页分流，无定时器、最低展示时长或额外网络等待；失败重试分支保留。

`project.yml` 是工程配置唯一真源。新增 XunjuLaunch 验证 scheme 保留成功用例录屏，默认 Xunju scheme 不变。正式启动验证用每例唯一 `--business-test UUID` 隔离数据目录；返回用户用例使用已有 fixture 准备本机房源。

## 验证映射

| 变更 | 定向验证 |
| --- | --- |
| Debug 评审入口与其他启动参数的隔离 | `XunjuTests/ComponentLogicTests/testReviewHostRequiresExplicitKnownSurface` |
| Logo 可见、全屏居中、无文字、仅一个图像、无按钮 | `XunjuUITests/BrandLaunchReviewTests/testBrandComposition` |
| 品牌素材来源一致 | 比较原始 v2 PNG 与生产资源的 SHA-256 |

沿用共享模拟器 runner、XcodeGen 包装脚本和每例 120 秒超时配置，只执行上述 2 条定向用例。

## 证据

状态：`APPROVED`。用户已批准下列 iOS 26.5 原生截图。以下为接入前组件证据，正式启动验证另列。

- 证据代码 SHA：`2c8b406b48bfc40b5ae32e557625946fe330e164`；基线 `eb75079b3e46726e5742cc4c861dc7a278d9dd31`。
- `xunju-brand-launch-logo-20261030-02`：iPhone 14 Pro / iOS 18.3.1（22D8075），**1 UT + 1 UI，2 passed / 0 failed / 0 skipped**。
- `xunju-brand-launch-logo-20261030-03`：iPhone 16 / iOS 26.5（23F77），**1 UT + 1 UI，2 passed / 0 failed / 0 skipped**；使用首轮失败的同一台设备复验。
- 两张原始 PNG 均为 **1178 × 2556 px**，未缩放或裁切；应用视口 393 × 852 pt。两次坐标附件均记录 Logo `(140.667, 370, 112, 112)`，中心相对屏幕中心误差小于 1 pt。
- 原图与生产 PNG 的 SHA-256 均为 `5157f06cdeb3d4b270f2262ac86f911345a64bdf86ad09e35a0375bf2d2ba57b`，原图为 1254 × 1254 px。
- XcodeGen 2.45.4 确定性生成校验通过。未修改工程配置或提交生成工程。两轮 runner 均退出 0，设备租约、执行槽位与队列条目已释放。
- 第三轮使用 runner 支持的 `--config`，只将本轮候选设备前缀收窄为原 iOS 26.5 设备名；共享 poolRoot、并发上限和租约机制保持不变，未修改全局配置。

产物位于任务 worktree `/Volumes/mac2/projects/git_repo/run_self/rent_room/.worktrees/ios-launch-page-20261030/artifacts/launch-logo-20261030/`：

| 产物 | iOS 18.3.1 | iOS 26.5 |
| --- | --- | --- |
| 完整测试结果 | `review-02.xcresult` | `review-03.xcresult` |
| 原始日志 | `runner-02.log` | `runner-03.log` |
| 精确计划与复现命令 | `plan-02.json`、`run-02.sh` | `plan-03.json`、`run-03.sh`、`runner-ios26.json` |
| 结果与截图哈希 | `evidence-02.json` | `evidence-03.json` |
| 截图与原始坐标附件清单 | `attachments-02/manifest.json` | `attachments-03/manifest.json` |
| 原生截图 | `brand-launch-logo.png` | `brand-launch-logo-ios26.png` |

主 agent 已查看两张截图：Logo 保持蓝紫底白色房屋与对勾，圆角、尺寸和居中位置一致；浅灰白背景连续覆盖安全区，没有小搭或品牌文字。系统状态栏保留。截图来自 Debug 组件宿主，不证明正式冷启动切页或时长。

组件证据后的文档提交不改变源码、资源、测试或配置，可复用上述 SHA 的组件截图。PR 未合并或部署。

以上组件证据未覆盖小屏、iPad、VoiceOver 实际朗读、深色模式或真实冷启动。Figma 尚未同步。

### 首轮失败与修正验证

`review-01.xcresult` 对应 SHA `5a5a17c748ed75f3ce8e2503228cbe05c4421901`：单测通过，UI 用例在 Logo 辅助功能横向中心断言失败（65.56 pt，预期 196.5 pt）。失败录屏里 Logo 视觉居中；该轮没有通过验收。原生录像和日志保留在 `attachments-01/` 与 `runner-01.log`，诊断视频抽帧不作为最终截图。

依据 [Apple 的 accessibility content shape 文档](https://developer.apple.com/documentation/swiftui/contentshapekinds/accessibility)，为圆角 Logo 显式定义匹配的辅助功能区域，并保留原居中断言。截图采集提前至断言前，追加应用与 Logo 原始坐标附件。第三轮在同一台 iOS 26.5 设备 `759E28A9-21EB-4AA1-9F4F-EF1850989C56` 上完整通过，验证了本次边界修正。第二轮 iOS 18.3.1 设备为 `8F178971-C203-4690-A83B-253046EACBB1`。

## 正式接入结果

设计状态：`APPROVED`。接入代码已完成；冷启动视觉状态：`RUNTIME_VISUAL_PENDING`。不能将功能用例通过解释为系统启动画面已通过。

- 接入代码 SHA：`11da2d40fc60a3a25a0c88de0fa871e31012b599`。
- `AppRoot` 用 `BrandLaunchSurface` 替换读取文字；工作区构造、失败重试、首次设置和房源导航逻辑不变。
- 系统启动页为 `Resources/LaunchScreen.storyboard`，通过 `UILaunchStoryboardName` 配置。原生导出的 336 × 336 px PNG 按 3x 展示为 112 pt，背景使用固定 `LaunchBackground` 色值。
- `XunjuLaunch` 验证 scheme 保留成功用例录像；默认 `Xunju` scheme 不变。未提交生成工程。
- 使用同一台 iPhone 16 / iOS 26.5，正式 Bundle ID `com.keeline.xunju.ios`，每条业务 UI 用例使用独立 UUID 数据目录。

| 验证范围 | 精确用例 | 结果 |
| --- | --- | --- |
| 编译后的启动配置、资源和全屏布局 | `XunjuTests/LaunchScreenTests/testBuiltAppCanLoadCenteredLaunchScreen` | 通过 |
| 既有购买及隐私配置 | `XunjuTests/NativeStorefrontTests/testFinishedConsumableHistoryAndExistingPrivacyKeysReachBuiltApp` | 通过 |
| Debug 评审入口隔离 | `XunjuTests/ComponentLogicTests/testReviewHostRequiresExplicitKnownSurface` | 通过 |
| Logo 居中、无文字、无按钮 | `XunjuUITests/BrandLaunchReviewTests/testBrandComposition` | 通过 |
| 首次设置、选择持久化、进入房源页 | `XunjuUITests/LaunchIntegrationTests/testFirstLaunchReachesSetupAndRelaunchRetainsChoice` | 通过 |
| 已有房源、后台返回、进程重启 | `XunjuUITests/LaunchIntegrationTests/testReturningLaunchRestoresHomesAndResumeKeepsCurrentPage` | 通过 |

`xunju-launch-integration-20261030-01`：3 UT + 3 UI，**6 passed / 0 failed / 0 skipped**，runner 退出 0。XcodeGen 2.45.4 确定性生成校验通过。完整结果位于本 worktree 的 `artifacts/launch-integration-20261030/integration-01.xcresult`，精确计划、命令、日志和截图清单分别为 `plan-01.json`、`run-01.sh`、`runner-01.log`、`attachments-01/manifest.json`。

原生组件截图 `brand-launch-integrated.png` 已查看，保持批准的外观。正式启动录像为 `first-launch.mp4`、`returning-launch.mp4`；录像确实抵达设置页和房源页，但系统接管启动到 App 首帧之间出现黑屏。`first-launch.mp4` 最前面仍显示上一条评审用例的 Logo，不能把这几帧当作系统 LaunchScreen 成功证据。没有验证真实冷启动时长或无黑屏衔接。

## 系统启动画面诊断及当前阻塞

所有诊断保留同一源码 SHA，未据此修改批准的设计。

- `integration-02.xcresult`：同设备、同正式标识，仅静态组件复查，1 UI 通过；在有效租约内收集上一轮系统日志。
- `integration-03.xcresult`：临时 xcconfig 给各 target 原标识追加 `.launchprobe20261030`，保留原 App 数据；1 UT 通过，首次设置 UI 用例因 120 秒执行限额失败。该轮使用 `ARCHS=arm64`。导出的录屏附件是不可播放的文本占位，不能用作全新安装的视觉验收。额外 `native-capture-03.mov` 只覆盖结束阶段，也不能证明冷启动。
- `system-launch-01.log`、`system-splashboard-01.log` 保留系统日志；部分 SplashBoard 消息为 `<compose failure [shared UUID]>`，不能从未解码内容推断具体根因。
- `integration-04` 静态对照完成构建后长期等待设备，后续在未持有设备租约时取消，runner 退出 143；没有测试结果，不计为通过。
- 普通原生采集使用共享基础设施导出的租约、心跳和释放 API，尝试对正式标识安装同一构建。设备列表查询出现 15 秒超时，取得租约后安装又出现 30 秒超时，未取得有效普通冷启动录像。记录见 `native-launch-evidence.json`。
- 取消的 runner、采集等待进程均已结束。本任务队列、执行槽和设备租约最终核查为空；自身异步心跳与释放竞争留下的残留也已通过基础设施释放接口清理。未重启、清空或删除池设备，未卸载原 App。

[Apple TN3118](https://developer.apple.com/documentation/technotes/tn3118-debugging-your-apps-launch-screen) 将旧启动快照列为排查方向之一；当前证据不足以确认缓存为本问题根因。下一步是在共享设备空闲且获准改变设备生命周期后恢复模拟器环境，再完成正式标识的普通启动录像验证。

PR 保持 Draft，未合并、部署或安装到真机。后续仅证据文档的提交可复用上述代码 SHA 的功能结果，不应标记冷启动视觉验收完成。
