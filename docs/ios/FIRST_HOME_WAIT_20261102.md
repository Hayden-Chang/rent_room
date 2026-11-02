# 首套房源首页提示：“再等等”修复

状态：`REVIEW_READY`，待用户确认 UI 和授权 GitHub 推送。本地已修复并验证，未创建 PR、合并、安装真机或发布应用。

## 问题与改动

“点这里，新建你的第一套房源吧！”下的“再等等”调用 `waitSecondHouse`，原命令只清除第二套房源的 `returnGuide`。页面随即重新查询 `homeGuide`，第一套提示的条件仍成立，导致看起来点击无效。

在原生专属 `ios/Core/inspection.js` 内增加可持久化的首套首页提示推迟状态，与原有第二套提示关闭在同一次强制保存事务中完成。旧存档缺少此可选状态时继续原有逻辑。未修改小程序或首页布局；`firstHouseId`、首次教学、房源及媒体、点数不因推迟提示而改变。

原生 `XunjuCore.js` 由 `node ios/scripts/build-core.mjs` 重新生成。未修改 `project.yml`；固定 XcodeGen 2.45.4 的确定性检查通过，未提交生成工程。

## 提交与来源

- Worktree：`/private/tmp/rent-room-ios-first-house-wait-20261102`
- 分支：`codex/ios-first-house-wait-20261102`
- 基线：`4f9ca323befd76eb4cdb3a56ef2d102158d91738`
- 已验证代码提交：`e7456541ef1b39bb8dac8b8504a5cc5318e97aba`
- 验证后仅补充本文档，未改变源代码、测试、资源、配置或选择器。
- 证据根目录：`/private/tmp/rent-room-first-house-wait-evidence-20261102`

## 自动回归

`node --test ios/tests/home-guide.test.mjs` 在修复前两项行为断言失败：首次推迟及保存失败后重试，仍然返回首套提示。原始文件 `pre-fix-node-corrected.log` 保留了预期空文案、实际首套文案的断言。首次测试误用底层保存错误文本，随后按既有产品错误文本修正；原始 `pre-fix-node.log` 也保留。

修复后执行：

```sh
node --test ios/tests/home-guide.test.mjs ios/tests/quiet-guidance.test.mjs
```

7/7 通过。新回归覆盖：示例房源下关闭首套提示、持久化与真实首次教学保留、后续第二套提示及其关闭、保存失败回滚和重试。相邻 quiet-guidance 覆盖现有教学与阶段提示边界。

原生定向选择如下，精确命令与理由见证据中的 `plan-02.json`、`runner-02.log`：

| 层级 | 精确选择器 | 影响边界 |
| --- | --- | --- |
| 新 UT | `XunjuTests/InspectionBusinessTests/testWaitDismissesFirstHomeReminderAcrossRelaunchAndPreservesTeaching` | 原生桥接、重开持久化、首次新建教学 |
| 新 UT | `XunjuTests/InspectionBusinessTests/testFailedHomeReminderDismissalKeepsPromptAndCanRetry` | 保存失败回滚与重试 |
| 既有 UT | `XunjuTests/InspectionBusinessTests/testGuideCloseScopesAndFeedbackRequestAreDurable` | homeGuide 反馈及关闭作用域 |
| 既有 UT | `XunjuTests/InspectionBusinessTests/testOtherHousesShowsReturnGuideBeforeLeavingAndStaleActionsDoNotDismissIt` | 后续第二套提示激活 |
| 新 UI | `XunjuUITests/ExampleHousesLaunchTests/testFirstHomeWaitDismissesReminderAndKeepsCreationAndTeachingAvailable` | 首次设置→真实点击→切页→杀进程重开→新建→首次教学 |

4 UT + 1 UI 全通过，0 失败、0 跳过。未运行全量本地 UT/UI；新修改的全部 UI 用例均已执行。本轮属于开发验证，未宣称已通过最终 PR head 或远程 CI 门禁。

## 运行与截图

- 共享 runner：`/Volumes/mac2/projects/git_repo/run_self/Simulator Management/bin/sim-test-run.mjs`
- 实时配置：同目录工程的 `config/runner.json`；池 `/tmp/todo-ios-sim-pool`，最终 UI 上限 3，本次仅选 1 方法。
- run ID：`rent-room-first-house-wait-20261102-02`，PID 96707。
- 设备：iPhone 14 Pro / iOS 18.3.1，UDID `8F178971-C203-4690-A83B-253046EACBB1`。
- 构建：共享 runner 管理的工程缓存 `/Volumes/mac2/codex-builds/time-fragment-dd-shared-e16e0f21a4e615e204cad897-simulator`，实际命令通过本工作树 `scripts/run-xcodebuild.sh`。
- 结果：证据目录下 `tests-02.build.xcresult`、`tests-02.xcresult`、`summary.json`、`receipt-02.json`、`runner-02.log`，退出码 0。
- runner 已释放执行槽和设备租约；设备生命周期保持由池管理。

`xcresulttool export attachments` 导出的 5 张截图经主 agent 原图检查，均为 1178 × 2556 像素；原始 UUID 文件与附件名对应见 `attachments/manifest.json`。证据根目录中的友好名称为原始 PNG 的逐字节副本：

| 文件 | 实际可见结果 |
| --- | --- |
| `before.png` | 两套示例卡片、完整首套提示、“再等等”及“去添加”，右下新建按钮 |
| `after.png` | 点击后整块提示消失，两套卡片、右下新建按钮与底部导航保留 |
| `reopened.png` | 重开后提示仍未出现，两套卡片保留 |
| `create.png` | 仍可打开新建房源页面 |
| `teaching.png` | 实际创建后仍进入“看房的三个阶段”第 1/4 步 |

## 审查与限制

主 agent 已独立重读最终代码 diff，核对可选状态兼容、保存失败回滚、实际首次创建、桥接查询缓存边界与生成资源来源，未发现额外问题。验证后未发生会使证据失效的更改。没有真机验证，不把模拟器结果当作设备或发布证据。

首次构建因本机全局 Git 的 HTTPS→SSH 改写导致 ZIPFoundation 下载失败，未执行测试。第二轮仅对当前进程设置 `GIT_CONFIG_GLOBAL=/dev/null`，相同提交与选择器通过；没有修改全局 Git 配置。原始 `runner.log` 和 `tests.build.xcresult` 保留。导出截图时普通沙盒无法写入 Xcode 的 TestReport 缓存，获工具授权后完成本地导出。

GitHub 推送被自动审批拒绝，理由是尚无向 `Hayden-Chang/rent_room` 上传完整源码分支的明确授权。未重试或改走其他上传方式；后续须由用户授权，再通过 GitHub Connector 创建 PR 并完成最终审查及适用门禁。
