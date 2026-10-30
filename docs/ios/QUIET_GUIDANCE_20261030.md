# iOS 同类别检查项引导同步

状态：`REVIEW_READY`，原生截图已生成并由主 agent 检查，待用户确认本轮 iOS 效果。PR #106，未合并或发布。

## 范围

与小程序 PR #102 保持同一规则：现场 C→D、D→E、E→F 等同阶段一级检查项完成后不再推荐下一项；首次教学、新建房源、跨阶段和全部完成提示保留。额度文案未改。

修改位于 `ios/Core/inspection.js`，只在原生引导查询中隐藏来源与目标阶段相同的 `next` 提示。该查询被桥接缓存，保持只读；既有答案、备注、媒体、完成历史及原始提示存档不被重写。旧提示重开仍隐藏，带旧提示 ID 的接受操作不会展开下一项。共享模型、小程序源码、原生布局和计费逻辑未改。

`ios/Xunju/Resources/XunjuCore.js` 由构建脚本重新生成；来源哈希同时补入主线已有的微信引导变更。`ios/project.yml` 和 XcodeGen 2.45.4 固定版本未改，生成工程未跟踪。

## 冻结源码与定向测试

实际证据 SHA：`b047fd6ed3ce0781d29e3e75bdb56c020d0bcf51`，工作树干净。原基线 `5dbe378` 后，主线合入房源长按提示 `abc042e`；在原生验收前已无冲突合并该主线并重新运行选定验证。后续仅追加本文时，源码、测试、资源、配置和选择器均与证据提交相同，可以复用该证据。

Node.js 24：4 项新增引导测试、3 项受影响桥接缓存测试通过。新增测试在修改前有 3 项按预期失败：精简/详细 C→D 仍有提示，以及重开旧提示仍显示。

```sh
node ios/scripts/build-core.mjs
node --test --test-name-pattern='same-phase|first-use teaching|read-only bridge|cached queries|cached guidance' ios/tests/quiet-guidance.test.mjs ios/tests/bridge-performance.test.mjs
```

原生结果：6 项精确单测、3 项精确 XCUITest，9 通过、0 失败、0 跳过。未运行全量单测或全量 UI 套件。

| 边界 | 精确选择器（类内方法） | 结果 |
| --- | --- | --- |
| 旧提示、过期操作、清空后重填 | `InspectionBusinessTests/testSamePhaseCompletionStaysQuietAfterClearingAndReopening` | 隐藏同阶段提示、重开及过期操作均不改记录 |
| 跨阶段和返回 | `InspectionBusinessTests/testOtherHousesShowsReturnGuideBeforeLeavingAndStaleActionsDoNotDismissIt` | 阶段提示、查看其他房源、返回和旧回调防护保留 |
| 关闭范围 | `InspectionBusinessTests/testGuideCloseScopesAndFeedbackRequestAreDurable` | 本房源关闭偏好与持久化保留 |
| 首次教学 | `InspectionBusinessTests/testTutorialRequiresActualSwipeAndResumesStoredStep`、`testTutorialSaveFailureRollsBackAndDuplicateSwipeCannotSkipStepFour` | 教学前置、恢复、保存失败和重复回调保留 |
| 新房源 | `InspectionBusinessTests/testFillingFixtureKeepsAnswersEmptyAndFirstGuidePending` | 双模式空答案、新房源填写提示保留 |
| 精简真实清单 | `InspectionBusinessUITests/testSimpleSamePhaseCompletionKeepsReadingPosition` | 实际点击完成室内环境 4 项；无提示、无跳动，重启后 4 项答案保留 |
| 详细真实清单 | `InspectionBusinessUITests/testDetailedSamePhaseCompletionKeepsReadingPosition` | 实际点击完成通风与采光 8 项；无提示、无跳动，重启后 8 项答案保留 |
| 重排清单及教学 | `InspectionBusinessUITests/testTemplateEdgeScrollAndSamePhaseCompletionKeepsReadingPosition` | 实际拖动排序、首次四步教学及左滑完成，之后同阶段完成保持位置 |

单测 target 为 `XunjuTests`，UI target 为 `XunjuUITests`。两个旧 UI 用例曾假定同阶段会出现“稍后”，现按新契约改为无气泡和位置不变的断言；保留真实输入与重排操作。完整 C→D→E→F、费用→合同、跨阶段和全部完成序列由 Node 隔离夹具覆盖，原生 UI 使用真实生产模板的代表类别，不声称整套模板逐项验收。

## 运行与截图

- 共享 runner：`/Volumes/mac2/projects/git_repo/run_self/Simulator Management/bin/sim-test-run.mjs`；配置 `config/runner.json`，最终 UI 上限 3，本轮选择 3。
- run：`xunju-quiet-guidance-20261030-02`；PID 4689，测试命令 PID 6290；session `01a18c02-6403-74b3-b168-3ba836334545`。
- iPhone 14 Pro / iOS Simulator 18.3.1，UDID `8F178971-C203-4690-A83B-253046EACBB1`；原始截图 1178×2556。
- 包装入口 `scripts/run-xcodebuild.sh`，project `ios/Xunju.xcodeproj`，scheme `Xunju`。实际独立缓存由 runner 解析为 `/Volumes/mac2/codex-builds/time-fragment-dd-shared-42d61e4fb5fcc94a6df1dfae-simulator`，归属于本 worktree。
- `.xcresult`：`/Volumes/mac2/codex-builds/xunju-quiet-guidance-20261030-02.xcresult`；构建 bundle 同前缀 `.build.xcresult`。退出 0，设备租约和执行槽已释放。
- 计划、完整命令、日志、权威摘要、receipt、原始附件和映射：本地忽略目录 `artifacts/ios-quiet-guidance/`。`run-02.sh` 与 `xunju-quiet-guidance-20261030-02.json` 包含全部精确选择器。
- 13 张附件无损复制到 `/Users/pc/.codex/visualizations/2026/10/30/01a18c02-6403-74b3-b168-3ba836334545/ios-quiet-guidance/`，manifest 记录原测试、尺寸和哈希。主 agent 已检查双模式新房源、完成无气泡、重开答案、重排后完成以及真实左滑后的教学界面。

本轮墙钟约 357 秒：缓存等待 0.033 秒、两阶段排队合计 1.278 秒、构建约 179.7 秒、测试命令约 176.4 秒。3 个 UI 方法合计约 134 秒，包含在测试命令时间内；启动/安装/结果收集未再细拆。

预检曾因 `changedUITests` 必须为字符串数组而拒绝计划，未启动测试；更正后 run 01 在依赖下载阶段因本机 Git HTTPS→SSH 重写失败，尚未运行用例。用单次环境变量仅覆盖 ZIPFoundation 固定仓库的 HTTPS 传输，确认固定版本可读后才执行 run 02。未改全局配置、依赖版本或共享 runner。原始失败计划、日志、构建 bundle 及 receipt 均保留。

本轮没有真机、支付、安装发行包或发布验证。首次教学与新建房源已实际点击；跨阶段和全部完成的保留由定向核心与原生单测证明，未声称本轮 UI 逐步完成这两条路径。
