# iOS 引导左滑连续展开组件验收

状态：`REVIEW_READY`，Draft PR [#112](https://github.com/Hayden-Chang/rent_room/pull/112)。尚待用户确认效果，正式 `HouseDetailPage` 的 `swipeProgress` 接入、页面回归、合并与发布未执行。

## 缺陷与改动

引导第 3 步的 `XiaodaSwipeTarget` 消费拖动，但原先只在手势结束时调用 `completed()`。底层行没有收到位移，第 4 步直接 `coordinator.reveal`，操作栏因此跳到展开状态。

组件现在把合法左滑的连续位移交给 `swipeProgress`，复用原有方向、速度阈值与 -132…0 夹紧规则；松手后使用 0.22 秒 ease-out 完成展开，再推进说明。错误方向/未达阈值的手势回到收起状态；页面退出或场景失活使待完成回调失效。减少动态效果模式使用无动画收尾，但尚未单独实测该系统设置。

本阶段只在现有 DEBUG `InspectionTeachingReviewHost` 中把回调接到真实 `MPFieldRow` 的 coordinator。无新账户、后端或存储写入。正式页面未接入新位移回调，因此不能称为正式引导已修复。

## 自动化复现

修复前基线 `09328a3b614b05e0522c7c5de1375aa9c484e988`，仅添加 [新测试与宿主采样入口](evidence/swipe-reveal-20261102/red-test.patch) 及 [DEBUG 只读采样器](evidence/swipe-reveal-20261102/red-recorder.swift.txt)。

`testTeachingSwipeRendersIntermediateActionWidths` 用原生触摸以 70 pt/s 左拖 85 pt。CADisplayLink 采样窗口实际渲染的行像素，而非模型 offset；在行上方的固定扫描线上观察红色操作按钮的可见宽度。采样器只在明确的组件测试路由和 `--record-teaching-swipe` 参数下启用，Release 排除。

- 修复前实际宽度为 `[0, 44]`；“至少 3 个中间宽度”的断言按预期失败。闭合与展开校准断言均通过，因此这是缺陷复现，不是环境或观察失败。
- 修复后前段实际宽度为 `0, 13, 15, 19, 23, 26, 30, 34, 38, 42, 43, 44`；后段手势提示图遮挡会令颜色计数波动，不能把全序列解释成严格单调轨迹。主 agent 查看了原始中间帧，确认按钮实际从右侧逐渐露出。
- 新测试未改变动画速度或直接设置产品完成状态。全屏截图校准最终三个按钮已出现；操作次数仍为 0。

## 精确验证范围

证据源码提交：`eb880d158b7db1965693752985a40a6382edf1de`。运行时源码工作树干净。

| 类型 | 精确 selector | 映射原因 |
| --- | --- | --- |
| 新 UT | `XunjuTests/XiaodaTeachingTests/testTeachingGestureExposesClampedProgressAndClearsRejectedAttempts` | 位移输出、夹紧、取消后重试 |
| 既有 UT | `XunjuTests/XiaodaTeachingTests/testTeachingGestureRejectsTapRightVerticalAndAllowsRetry` | 方向与取消契约 |
| 既有 UT | `XunjuTests/XiaodaTeachingTests/testTeachingGestureUsesChecklistShortFlickThreshold` | 短划速度阈值 |
| 既有 UT | `XunjuTests/MiniProgramComponentTests/testSwipeFollowsFingerAndHandlesReverseAndVerticalScroll` | 新回调使用现有 coordinator.move/reveal/close |
| 新 UI，风险 1 | `XunjuUITests/InspectionTeachingReviewTests/testTeachingSwipeRendersIntermediateActionWidths` | 原生拖动期间真实像素出现中间状态 |
| 既有 UI，风险 2 | `XunjuUITests/InspectionTeachingReviewTests/testGuardedSwipeTeachingAndRentFreeNumberKeyboard` | 拒绝点按/长按/右滑/竖滑、正常完成引导；该既有方法下游的数字键盘与备注保留同时通过 |

结果：4 UT + 2 UI = **6 通过，0 失败，0 跳过**。没有运行全量 UT/UI；本次新增与修改 UI 方法全部执行。未执行正式页面集成测试、真机、VoiceOver、减少动态效果设置或其他系统版本，不声称这些范围通过。

## 证据与运行环境

- iPhone 14 Pro / iOS 18.3.1 (22D8075) / arm64；UDID `8F178971-C203-4690-A83B-253046EACBB1`。
- Scheme `Xunju`，XcodeGen 2.45.4；工程真源 `ios/project.yml` 未改，生成 `.xcodeproj` 未纳入版本控制。
- runner 配置：`/Volumes/mac2/projects/git_repo/run_self/Simulator Management/config/runner.json`。
- 工作树：`/private/tmp/rent-room-ios-swipe-reveal-animation-20261102`。
- session：`01a19a99-7662-7402-a7bb-16b54adf2430`。
- run ID：`rent-room-swipe-reveal-red-01a19a99` / `rent-room-swipe-reveal-green-01a19a99`。
- 修复前构建 PID 22949、测试 PID 23606；修复后测试 PID 24409。完整阶段记录见 receipt。
- 修复后 `.xcresult`：`/private/tmp/rent-room-swipe-reveal-evidence/green.xcresult`；修复前为同目录 `red.xcresult`；构建包分别为 `green.build.xcresult` / `red.build.xcresult`。
- runner 使用本工作树独占的缓存键 `cc334543ebf2fd16b9a7ef7a`，实际 DerivedData 为 `/Volumes/mac2/codex-builds/time-fragment-dd-shared-cc334543ebf2fd16b9a7ef7a-simulator`；目录前缀来自共享基础设施，测试项目仍是 Xunju。
- 修复后 queue 1.078 秒、构建阶段约 14.8 秒、测试命令阶段约 40.0 秒，后者包含安装/启动/收尾，未进一步拆分。不能把它全部当作测试方法耗时。
- 执行完成后 runner 的设备租约与执行槽已释放，未关闭/清除设备。
- [修复前计划](evidence/swipe-reveal-20261102/red-plan.json)、[命令](evidence/swipe-reveal-20261102/red-command.sh)、[日志](evidence/swipe-reveal-20261102/red.log)、[结果](evidence/swipe-reveal-20261102/red-summary.json)、[receipt](evidence/swipe-reveal-20261102/red-receipt.json)。
- [修复后计划](evidence/swipe-reveal-20261102/green-plan.json)、[命令](evidence/swipe-reveal-20261102/green-command.sh)、[日志](evidence/swipe-reveal-20261102/green.log)、[结果](evidence/swipe-reveal-20261102/green-summary.json)、[receipt](evidence/swipe-reveal-20261102/green-receipt.json)。
- [原始截图来源与 SHA-256](evidence/swipe-reveal-20261102/images.json)。全屏 1178 × 2556，行采样 329 × 48。PNG 均从本次 `.xcresult` 导出。

## 效果

以下 GIF 由真实采样帧按顺序制作，使用便于观察的统一播放间隔，**不是原速录屏**，不作为帧率/动画时长证据。PNG 原始帧另行保留。

![真实采样帧回放](evidence/swipe-reveal-20261102/swipe-sampled-playback.gif)

![实际中间帧](evidence/swipe-reveal-20261102/green/swipe-frame-6-width-30.png)

[展开前完整截图](evidence/swipe-reveal-20261102/green/swipe-before.png) · [展开后完整截图](evidence/swipe-reveal-20261102/green/swipe-after.png)

## 主 agent 审查与剩余门禁

PR 创建后已通过 GitHub Connector 重新读取远端 diff、6 个源码/测试文件范围与提交 status：未发现需要返工的代码问题；该源码提交的 status 列表为空，不能称为远端 CI 通过。`HouseDetailPage` 未改，仍明确等待视觉批准和接入。

绿色验证之后只增加本说明与 `docs/ios/evidence/swipe-reveal-20261102/` 的文档/证据；这些路径不属于工程 sources/resources，也不改变测试选择、生成输入或运行环境。最终文档提交可复用 `eb880d1` 的证据，不把证据称为在后来文档 SHA 上重新执行。后续页面接入会改变执行路径，必须按影响补页面验证。
