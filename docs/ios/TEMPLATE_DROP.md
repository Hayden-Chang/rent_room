# iOS 清单拖动松手落位修复

2026-11-02。状态：`REVIEW_READY`，待用户确认效果；未合并、未部署。PR：[#110](https://github.com/Hayden-Chang/rent_room/pull/110)。

## 行为与实现

拖动时继续跟手移动并让出目标槽位；松手直接提交当前排序，不再从原位置重播 0.18 秒换位动画。连续向上、向下拖动使用当前排序对应的落点。

- 在无动画事务中停止边缘滚动并提交顺序。
- 每个手势冻结一份由当前顺序、实际行高和 1 pt 分隔线计算的位置快照。仅观察行高，不缓存排序前的行原点。
- 结束、取消或离开组件时释放快照。停用项、排序数据规则与存储接口保持原实现。
- 渲染事务观察只在已有 DEBUG 组件评审入口中运行；新增测试使用真实原生拖动，不调用排序 handler。临时坐标诊断已移除。
- 小程序、`project.yml`、生成的 Xcode 工程均不在变更范围。

## 证据

生产代码与 UI 证据 SHA：`7950ac09f09b07829d08ccecc57be9679f1edd21`。此后仅提交本报告和静态证据，不改变代码、测试、配置、生成输入或测试选择，证据等价。

最终 UI：iPhone 14 Pro / iOS 18.3.1，UDID `8F178971-C203-4690-A83B-253046EACBB1`，截图均为 1178×2556。主 agent 已逐张检查向上/向下落位截图，并检查真实录屏的松手边界。截图来自 `.xcresult` 原始附件，视频为 XCTest 原始屏幕录制。

- [修复后双向拖动录像](evidence/template-drop-20261102/fixed-drag.mp4)
- [修复前回跳录像](evidence/template-drop-20261102/original-replay.mp4)
- [拖动前](evidence/template-drop-20261102/before.png)、[向上落位](evidence/template-drop-20261102/upward.png)、[向下落位](evidence/template-drop-20261102/downward.png)
- [最终 UI 结果](evidence/template-drop-20261102/ui-summary.json)、[原始附件清单](evidence/template-drop-20261102/attachments.json)

录屏高置信度文字匹配采样：原代码在最后一个拖动态到首个松手态中，标题 Y 从 980 px 回跳至 1377 px（约 132 pt），随后再次滑到目标；修复后向上为 980→975 px，向下为 1364→1377 px，均继续落入相邻目标位置，无回原位重播。完整采样值见 [原始观测](evidence/template-drop-20261102/original-frame-observations.json) 和 [修复后观测](evidence/template-drop-20261102/fixed-frame-observations.json)。这是已录制手势的采样证据，不代表所有设备和时序的穷举证明。

## 回归与精确选择

| 边界 | 测试 selector | 结果 |
| --- | --- | --- |
| 真实向上、向下连续拖动；两次准确落点；松手渲染事务无动画 | `XunjuUITests/InspectionSetupReviewTests/testNativeDropCommitsInPlaceInBothDirections` | 最终 SHA 通过，7.367 秒 |
| 双向移动不修改停用项 | `XunjuTests/InspectionSetupTests/testReorderBothDirectionsPreservesDisabledCategories` | `9d41194a8bf7748c5d8abc198d7ee4e261b1008e` 通过 |
| 原位及无效移动不修改草稿 | `XunjuTests/InspectionSetupTests/testInvalidDropAndToggleCannotAlterDraft` | 同上通过 |
| 评审入口必须显式指定 | `XunjuTests/InspectionSetupTests/testSetupReviewRequiresExplicitArgument` | 同上通过 |

修复前新增 UI 用例在原主线 `09328a3b614b05e0522c7c5de1375aa9c484e988` 的实际拖动后，因“重复换位动画”断言失败：[结果](evidence/template-drop-20261102/original-failure.json)、[运行日志](evidence/template-drop-20261102/red-transaction.txt)。

去掉动画后，录屏发现连续第二次拖动使用旧坐标；新增准确落点断言复现 `591.653 pt != 457.653 pt ± 2 pt`：[失败日志](evidence/template-drop-20261102/red-repeat.txt)。保持失败记录，未把早期仅验证相对顺序的通过结果作为完成依据。

最终恢复遵循单失败规则：`9d41194` 的完整定向 campaign 是 **3 UT 通过、1 UI 失败**；`7950ac0` 只修复该 UI 失败涉及的坐标来源，单测覆盖的草稿模型、禁用保护和评审入口解析均未改变，故保留三项单测结果，只重跑该精确 UI 方法。最终 UI 通过且 0 skipped。参见 [原 campaign](evidence/template-drop-20261102/prior-campaign-summary.json)、[最终日志](evidence/template-drop-20261102/final-landing.txt)。没有运行全量 UT/UI。

## 复现与运行边界

Worktree：`/private/tmp/rent-room-ios-template-drop-20261102`；分支：`codex/ios-template-drop-20261102`。

共享 runner 配置：`/Volumes/mac2/projects/git_repo/run_self/Simulator Management/config/runner.json`；池 `/tmp/todo-ios-sim-pool`。最终 run ID `rent-template-drop-final-landing-20261102`，runner PID 24834，test PID 25082，Session ID `01a19a8e-c6f1-7720-b62d-88b7f6c7eae1`。退出码 0，设备租约与执行槽已归还。

实际独立构建缓存（由共享 runner 分配，名称前缀来自基础设施）：`/Volumes/mac2/codex-builds/time-fragment-dd-shared-07ee9c75284186c7e82e7eb4-simulator`。本任务 worktree/命令哈希专用，未手动复用其他工程的缓存。

完整结果路径：

```text
/Volumes/mac2/codex-builds/rent-template-drop-red-transaction-20261102.xcresult
/Volumes/mac2/codex-builds/rent-template-drop-final-geometry-20261102.xcresult
/Volumes/mac2/codex-builds/rent-template-drop-final-landing-20261102.xcresult
```

最终计划：[ui-plan.json](evidence/template-drop-20261102/ui-plan.json)。复现时更换 run ID、headSha 和结果路径，通过共享 runner 执行：

```sh
PATH=/opt/homebrew/bin:$PATH env \
  GIT_CONFIG_COUNT=1 \
  GIT_CONFIG_KEY_0=url.https://github.com:443/weichsel/ZIPFoundation.git.insteadOf \
  GIT_CONFIG_VALUE_0=https://github.com/weichsel/ZIPFoundation.git \
  node '/Volumes/mac2/projects/git_repo/run_self/Simulator Management/bin/sim-test-run.mjs' \
  --plan /绝对路径/本轮计划.json -- \
  /private/tmp/rent-room-ios-template-drop-20261102/scripts/run-xcodebuild.sh \
  -project /private/tmp/rent-room-ios-template-drop-20261102/ios/Xunju.xcodeproj \
  -scheme XunjuLaunch -destination 'platform=iOS Simulator,id=__SIM_UDID__' \
  -derivedDataPath /Volumes/mac2/codex-builds/rent-template-drop-唯一运行号-__SIM_UDID__ \
  -resultBundlePath /Volumes/mac2/codex-builds/rent-template-drop-唯一运行号.xcresult \
  test -only-testing:XunjuUITests/InspectionSetupReviewTests/testNativeDropCommitsInPlaceInBothDirections
```

临时 Git 环境仅解决当前机器 HTTPS→SSH 全局重写导致的依赖下载问题；未改全局配置。构建经 `scripts/run-xcodebuild.sh` 与 XcodeGen 2.45.4 确定性检查。

## 审查与剩余验收

主 agent 分别审查 PR 最终源代码 diff、精确测试断言、失败/恢复证据及截图。发布前仍需用户确认松手效果；尚无本次修复的物理 iPhone 手势验收，边缘自动滚动与非等高行的完整设备路径未在本轮 UI 用例执行。最终验证使用隔离组件评审草稿，不触碰用户房源。GitHub Checks 与 UI 批准分别记录，不能用本地通过代替批准或发布。

研究依据（2026-11-02 读取）：Apple 的 [offset](https://developer.apple.com/documentation/swiftui/view/offset(_:)) 区分显示位移与原始布局尺寸；[onGeometryChange](https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:)) 可只观察需要的几何值，单参数 action 版本支持 iOS 16+。实际旧坐标问题由本机手势追踪确认；解决方案是只测量高度，并按当前顺序计算位置。
