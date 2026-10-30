# 寻居品牌 Logo 启动屏 · 视觉评审

用户确认沿用小程序现有的蓝紫底、白色「房屋＋对勾」Logo，并继续要求没有文字、没有小搭。当前为可独立运行的 SwiftUI 组件；尚未接入正式启动、初始化、首页导航或系统 LaunchScreen。

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

用户确认此版原生截图后，再处理真实启动衔接。当前只验证组件渲染，不证明冷启动切换或时长；不要人为延长启动时间。

## 验证映射

| 变更 | 定向验证 |
| --- | --- |
| Debug 评审入口与其他启动参数的隔离 | `XunjuTests/ComponentLogicTests/testReviewHostRequiresExplicitKnownSurface` |
| Logo 可见、全屏居中、无文字、仅一个图像、无按钮 | `XunjuUITests/BrandLaunchReviewTests/testBrandComposition` |
| 品牌素材来源一致 | 比较原始 v2 PNG 与生产资源的 SHA-256 |

沿用共享模拟器 runner、XcodeGen 包装脚本和每例 120 秒超时配置，只执行上述 2 条定向用例。

## 证据

状态：`REVIEW_READY`。用户已确认采用小程序 Logo；替换后的原生启动屏截图待用户最终确认。

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

已复核完整 diff：独立组件、Logo 资源、Debug 评审入口、定向测试和本说明；无业务数据或导航改动。后续证据文档提交不改变源码、资源、测试或配置，因此可复用上述 SHA 的截图，不将它称为文档提交生成的截图。PR 保持 Draft，未合并或部署。

未覆盖小屏、iPad、VoiceOver 实际朗读、深色模式或真实冷启动。Figma 尚未同步。

### 首轮失败与修正验证

`review-01.xcresult` 对应 SHA `5a5a17c748ed75f3ce8e2503228cbe05c4421901`：单测通过，UI 用例在 Logo 辅助功能横向中心断言失败（65.56 pt，预期 196.5 pt）。失败录屏里 Logo 视觉居中；该轮没有通过验收。原生录像和日志保留在 `attachments-01/` 与 `runner-01.log`，诊断视频抽帧不作为最终截图。

依据 [Apple 的 accessibility content shape 文档](https://developer.apple.com/documentation/swiftui/contentshapekinds/accessibility)，为圆角 Logo 显式定义匹配的辅助功能区域，并保留原居中断言。截图采集提前至断言前，追加应用与 Logo 原始坐标附件。第三轮在同一台 iOS 26.5 设备 `759E28A9-21EB-4AA1-9F4F-EF1850989C56` 上完整通过，验证了本次边界修正。第二轮 iOS 18.3.1 设备为 `8F178971-C203-4690-A83B-253046EACBB1`。
