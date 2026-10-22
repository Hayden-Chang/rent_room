# 顶楼组件评审

日期：2026-10-22。Draft PR #46，base 为 `codex/ios-parity-20261019`；当前组件代码提交 `b5f780b38c97cdd34f7851a5557e76cf036556b4`。共享规则与小程序 PR #45 相同，原有页面整合代码未修改。

## 待评审状态

“顶楼”未填写、选是自动问题、高亮问题按钮左滑展开、取消后仍选是、重启保留取消、改选否清除自动问题。问题覆盖与答案、备注、媒体独立。

`--component-review top-floor --top-floor-review-id <UUID>` 仅在 Debug 中进入。宿主使用生产 `MPFieldRow`、`ChecklistPresentation.write` 和 `NativeStore`，数据位于临时 `XunjuTopFloorReview/<UUID>` 目录，不访问 Keychain、账号或用户记录；未传显式组件参数时应用启动方式保持。

## 定向模拟器计划

计划：`/private/tmp/xunju-top-floor-ios-20261022/plan-06.json`，phase 为 development。6 UT、1 UI；未运行全量或最终合并验证。

新增 UT：

- `XunjuTests/TopFloorTests/testYesFlagsAndPresenterCancellationPersistsWithoutChangingAnswer`
- `XunjuTests/TopFloorTests/testLegacyNegativeQuestionMigratesOnceOnDiskAndThroughImport`
- `XunjuTests/TopFloorTests/testReviewRouteRequiresExplicitComponentArgument`

受影响既有 UT：`NativeStoreTests` 的 `testCanonicalCatalogAndRoundTripRetainAnswersAndZero`、`testIndependentIssueFlagFilteringAndCollapsedFormDoNotMutate`、`testImportIsAtomicAndPreservesGlobalSettings`。对应共享清单、问题覆盖、保存/重载和导入边界。

唯一 UI：`XunjuUITests/TopFloorReviewTests/testYesAutomaticIssueSwipeCancellationAndRelaunch`，真实点击选项、左滑、点击取消、终止重开并改答，计划保存 6 个状态截图。

经共享 runner 和本仓库 `scripts/run-xcodebuild.sh` 执行，XcodeGen 2.45.4；`project.yml` 未修改，未提交生成工程。原生 core 已由 `ios/scripts/build-core.mjs` 生成且包装脚本的新鲜度校验通过。

## 当前证据边界

首轮 `xunju-top-floor-20261022-01` 在 Swift 包解析期间因本机 GitHub HTTPS→SSH 重写而失败（退出 74），尚未执行任何测试。回执 `/tmp/todo-ios-sim-pool/run-receipts/xunju-top-floor-20261022-01.json` 与 `result-01.build.xcresult` 保留。

第二轮 `xunju-top-floor-20261022-02` 对该进程临时使用 HTTPS，不改共享 Git 配置。runner PID 95082；已确认队列文件 `/tmp/todo-ios-sim-pool/queue/xunju-top-floor-20261022-02.json`。计划结果位置 `/Volumes/mac2/codex-builds/xunju-top-floor-20261022/result-02.xcresult`，排队不代表测试通过或截图已经生成。

第二轮后续在新增测试中发现文件写入缺少 `keepPrevious` 参数，已修正；未执行测试。第三轮在构建期间因主审发现共同生成规则还影响其他事实项，经 runner 的 SIGTERM 协议主动停止，随后收紧规则并加入保护用例；确认生成的 302 项只有顶楼定义变化。第四轮因从子目录生成 core 导致包装脚本新鲜度检查失败，已按要求从仓库根目录重新生成，`--check` 通过。

第五轮 `xunju-top-floor-20261022-05` 使用上述最终代码，构建已成功，原定 6 UT、1 UI 正在继续。结果路径为 `/Volumes/mac2/codex-builds/xunju-top-floor-20261022/result-05.xcresult`；没有由构建成功推断测试通过。

第五轮后续在等待测试资源时，因本说明的补写改变了工作区快照而被 runner 拒绝，未执行测试。第六轮先提交全部说明再冻结工作区；不在运行期间写入本 worktree。功能代码仍与 `b5f780b` 等价，计划结果为 `/Volumes/mac2/codex-builds/xunju-top-floor-20261022/result-06.xcresult`。最终结果以该实际 bundle 和 receipt 为准。

## 第六轮实际结果

`62494b464a2907b599e4a76387f3429d1b81a2f9` 的 6 UT、1 UI 全部通过，0 跳过、0 失败，runner 退出 0。构建与测试回执 `/tmp/todo-ios-sim-pool/run-receipts/xunju-top-floor-20261022-06.json`，完整结果 `/Volumes/mac2/codex-builds/xunju-top-floor-20261022/result-06.xcresult`。测试设备 iPhone 16 / iOS Simulator 26.5，UDID `5FC4A20B-AF44-4A92-BF91-B0096BEBF1D9`。本轮结束后没有该 run 的活动 slot 记录。

原始附件已通过 `xcresulttool export attachments` 导出，六张均为 1178 × 2556。原样保存于 `/Volumes/mac2/codex-builds/xunju-top-floor-20261022/screenshots-06/`，`manifest.json` 记录 bundle、证据 SHA、导出原名和逐文件 SHA-256：

| 状态 | 原始截图文件 |
| --- | --- |
| 未填写，0 异常 | `top-floor-01-unanswered.png` |
| 选是，红色问题样式，1 异常 | `top-floor-02-yes-automatic-issue.png` |
| 左滑，红色问题、备注、相机三个按钮 | `top-floor-03-swipe-cancel-action.png` |
| 取消问题，仍选是，备注保留，0 异常 | `top-floor-04-manually-cancelled.png` |
| 终止重开，取消状态保留 | `top-floor-05-cancellation-after-relaunch.png` |
| 改选否，0 异常 | `top-floor-06-no-clears-automatic-issue.png` |

主 agent 已逐张直接查看，确认标题“顶楼”、是/否选项、问题色与取消后的恢复样式、左滑按钮和备注均符合本次组件范围。取消前后“是”的选择保持；重启截图与取消后截图的 SHA-256 一致。没有把这些隔离组件图片当作完整页面或真机证据。

原始 runner 日志、计划、精确命令、摘要和首次附件导出位于 `/private/tmp/xunju-top-floor-ios-20261022/`。本说明补写发生在执行完成之后，和证据 SHA 比较仅为文档变化，功能/测试/配置/生成输入未变，复用原证据。

状态：`REVIEW_READY`，待用户明确视觉批准后才继续完整页面业务整合。不合并或部署；未做最终 PR head 合并 campaign，也未声称整个 iOS 应用已验收。小程序侧尚有 3 个备份用例超时且工具池未取得截图，见 PR #45。

## 用户批准与组合版本验证

2026-10-22 用户明确回复“确认通过，合入”，组件视觉审批和两份 PR 的合并授权已取得。仅合入现有 iOS 开发线，不将父 PR #39 合入 main，不部署或发布。

目标分支前进至 `5585607310f37b55c49f2fe17b1720352bc24d1b`（楼道标题 #44），生成清单、原生 core 和组件分派入口发生冲突。保留顶楼及楼道两项变更，从合并后的源清单重新生成两个产物；手工组合 Debug 组件分派，使两个显式入口都可用。冲突使旧证据失效，组合版本重新冻结后执行 final-pr-head campaign。

原生定向集合为上述 6 UT 加 `XunjuTests/ComponentLogicTests/testReviewHostRequiresExplicitKnownSurface`，覆盖组合后的组件参数解析。UI 精确选择 2 项：新增 `XunjuUITests/TopFloorReviewTests/testYesAutomaticIssueSwipeCancellationAndRelaunch` 优先验证本需求；既有 `XunjuUITests/ChecklistFormatTests/testCorridorHeadingAndSanitationDetailStayDistinct` 验证冲突涉及的楼道入口与分组。没有执行全量单测或 UI 套件；2 项低于最终阶段 3 项上限。共享规则定向运行 top-floor、model、inspection-wording 三文件，覆盖合并后的清单、迁移、问题覆盖及楼道投影。

最终计划、精确命令和日志存于 `/private/tmp/xunju-top-floor-merge-20261022/`；本段先提交后冻结，实际结果待执行结束后补记。小程序上一候选的 66 项已全部通过，旧超时记录保留，微信实际 UI 截图仍缺失；这些不作为 iOS 证据。

组合 SHA `72da10b1e3b75f571a698e34e00767c387e55a62` 的 final campaign：7 UT 与楼道 UI 通过，顶楼 UI 在取消按钮出现前失败，合计 8 通过、1 失败。完整 `result-01.xcresult` 与退出 65 回执保留，UDID `759E28A9-21EB-4AA1-9F4F-EF1850989C56`，iPhone 16 / iOS 26.5。原始失败录像、层级和合成事件已导出至 `attachments-01/`，主 agent 直接查看：选是后自动异常正常，手势后行仍收起；XCTest 对 44 点选项按钮实际只注入 x=300→266、34 点/34 ms 的短促移动。仅凭这些证据不能确定组件拒绝还是输入未充分交付。

单一失败恢复仅调整该测试的输入：在真实完整字段行上执行原生 `swipeLeft()`，保留取消按钮、答案不变、重启及改答的全部原断言和超时；启用已有 Debug `--parity-trace`，将原生识别轨迹存为附件，便于判别手势交付。生产代码、组件布局和业务状态未改。该精确方法重跑通过后，可与原 8 项按单一失败恢复规则组合，无需重跑通过项。44 点按钮上的极短原生 flick 没有被本次恢复运行覆盖，原失败继续保留。
