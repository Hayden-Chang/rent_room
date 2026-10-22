# 顶楼组件评审

日期：2026-10-22。Draft PR #46，base 为 `codex/ios-parity-20261019`；组件代码提交 `eaeaa0803b4e91520e0ff32bae9b6559b17d899e`。共享规则与小程序 PR #45 相同，原有页面整合代码未修改。

## 待评审状态

“顶楼”未填写、选是自动问题、高亮问题按钮左滑展开、取消后仍选是、重启保留取消、改选否清除自动问题。问题覆盖与答案、备注、媒体独立。

`--component-review top-floor --top-floor-review-id <UUID>` 仅在 Debug 中进入。宿主使用生产 `MPFieldRow`、`ChecklistPresentation.write` 和 `NativeStore`，数据位于临时 `XunjuTopFloorReview/<UUID>` 目录，不访问 Keychain、账号或用户记录；未传显式组件参数时应用启动方式保持。

## 定向模拟器计划

计划：`/private/tmp/xunju-top-floor-ios-20261022/plan-02.json`，phase 为 development。6 UT、1 UI；未运行全量或最终合并验证。

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

原始 runner 日志和命令位于 `/private/tmp/xunju-top-floor-ios-20261022/`。真实截图、`.xcresult` 与用户视觉批准尚缺，组件仍未通过 UI gate。不得把新增测试或 bundle 生成当作原生行为通过证据；不继续完整页面业务整合，不合并或部署。
