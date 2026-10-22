# 楼道标题组件验收（2026-10-22）

状态：`REVIEW_READY`，视觉批准待用户明确确认。小程序 UI 另因实例池异常 BLOCKED，不能把本次 iOS 组件证据称为两端整页/真机或合并验收。

## 修改及来源

- 上级 `topic_14` 显示“楼道状况正常”，下级 `f14_0` 保留“楼道卫生正常”。异味、照明等子项、ID与顺序不变。
- 修改共享清单源与按原分组 ID 的旧模板显示映射，重建 topics 及 XunjuCore.js；不重写已存模板、答案、问题标记、备注、媒体。
- 基于未合并的 iOS Draft PR #39，parent `4cabe5fb8ef5f87704cce947fc59ce91e0b01327`；本次 Draft PR #44 仅以该 iOS 开发分支为目标。
- 产品代码提交 `3800b56cab3ee8e38d1e3e096ad432afc840d554`；**截图与最终运行源码为 `0c2c6c0254e055126ce8211094e3a6423c9652de`**。后续仅追加本文，不把截图改称来自文档提交。
- 独立组件宿主仅在 DEBUG 且显式 `--component-review corridor` 时打开；从本机临时 NativeStore 的实际 bundled shared rules 取得生产 MPFieldRow 数据，渲染前置夹具不打开用户 workspace。普通启动与 Release 不进入该宿主；未修改业务页面。

## 测试映射与结果

| 范围 | 精确选择器 / 命令 | 结果 |
| --- | --- | --- |
| 新/旧模板标题、搜索、原房源 JSON 保留 | Node 24.19.0，`node node_modules/vitest/vitest.mjs run tests/inspection-wording.test.js` | 两任务分支均5/5；`artifacts/corridor-title/wording-node24.log` |
| 生成关系 | Node 24.19.0 执行 `scripts/build.mjs` 及 `ios/scripts/build-core.mjs --check` | 通过；302字段；无生成漂移 |
| 原生 form 投影、所有分组折叠与持久化不变 | `XunjuTests/ChecklistPresentationTests/testEveryCategoryAndGroupFoldsOnlyItsDescendantsWithoutWritingAnswers` | run-02，3800b56，1/1通过，13.038秒 |
| 显式宿主入口与未知/默认参数边界 | `XunjuTests/ComponentLogicTests/testReviewHostRequiresExplicitKnownSurface` | run-04，0c2c6c0，通过 |
| 实际标题/子项及真实点击折叠、展开 | `XunjuUITests/ChecklistFormatTests/testCorridorHeadingAndSanitationDetailStayDistinct` | run-04，0c2c6c0，通过，19.276秒 |

去重为两项原生 UT、一项 XCUITest；run-04 权威摘要为2通过、0失败、0跳过。未跑全量单测或 UI 套件。本次 UI 风险只有标题与该分组折叠显示，单个精确方法覆盖，不超过3项限制。

run-02 的已通过 form UT 可复用：检查 `3800b56..0c2c6c0`，仅新增显式 DEBUG 宿主及入口解析断言、替换本次新增 UI 用例的启动前提；共享规则、清单源、资源、NativeStore、ChecklistPresentation、生产组件及原 form UT 均无变化。新入口断言与修改的 UI 用例已在 run-04 执行。共享 JS 文案用例另于0c2c6c0重新通过。

## 原始运行证据

- worktree：`/Volumes/mac2/projects/git_repo/run_self/rent_room/.worktrees/corridor-title-ios-20261022`。
- runner 配置：`/Volumes/mac2/projects/git_repo/run_self/Simulator Management/config/runner.json`。
- run ID：`xunju-corridor-title-20261022-04`；runner PID3564、test PID4313，租约与槽位已释放。
- iPhone 16 / iOS Simulator 26.5（23F77），UDID `5FC4A20B-AF44-4A92-BF91-B0096BEBF1D9`，两张截图均 **1178×2556**。
- 计划、完整日志及权威摘要：本 worktree 的 `artifacts/corridor-title/plan-04.json`、`simulator-04.log`、`summary-04.json`。
- `.xcresult`：`/private/tmp/xunju-corridor-title-20261022-04.xcresult`；build bundle 同名 `.build.xcresult`。
- 原始导出及 manifest：`/private/tmp/xunju-corridor-title-attachments-04/`。
- 未改像素的截图副本：`/Users/pc/.codex/visualizations/2026/10/22/01a16154-4d0e-7c42-b754-ef11882535b4/corridor-title/ios-expanded.png`、`ios-collapsed.png`。
- 实际 DerivedData 为 runner 解析的 `/Volumes/mac2/codex-builds/time-fragment-dd-shared-55ab9c97358055ed2dcc18cb-simulator`，registry 对应本任务 worktree，不共享其他工作树可写缓存。
- 通过仓库 `scripts/run-xcodebuild.sh` 与共享租约执行精确选择器；XcodeGen 2.45.4，生成两次一致；project.yml未改，生成 .xcodeproj 未跟踪或提交。

主 agent 已直接查看两张原始导出图：展开时粗体上级为“楼道状况正常”，下方缩进的具体项为“楼道卫生正常”，另保留无异味、照明；是/否按钮与文字完整可见。折叠时子项隐藏、上级及选项保留。测试再次展开后子项恢复。本证据是生产组件的独立宿主，不是完整业务新建流程通过。

## 未通过与取消的尝试

1. run-01：构建在 ZIPFoundation 解析时被本机 HTTPS→SSH 全局重写挡住，测试未执行；仅当前进程跳过全局 Git 配置后继续，未修改全局配置。
2. run-02：form UT通过，但 UI 在“添加房源”后的 `coach.next` 前置查询超时；诊断图仍为添加弹层，没有到达楼道项。因此未将其视为标题回归或成功；未顺手修改无关业务，也未删除任何既有 UI 用例。
3. run-03：拟为失败方法设置执行上限，发现该参数改变共享缓存身份触发新冷构建；按 runner 已实现的 SIGTERM 清理协议只取消本任务 run-03，保留日志。没有重复占用设备或停止其他任务。
4. run-04：使用原兼容暖缓存命令、显式组件入口，解析 UT与标题 UI全部通过。产品规则与原生投影保持run-02的字节，边界仅为评审宿主与本次新用例。

最末绿灯后没有修改执行源/测试/资源。主 agent 已在发布 PR 更新后单独检查最终 diff、生成边界、隔离目录及证据；没有额外代码发现。远程 statuses为空不代表CI通过。UI批准、父分支接入、main合并、真机部署与发布仍各自未执行或未授权，不能称为 merge-ready。
