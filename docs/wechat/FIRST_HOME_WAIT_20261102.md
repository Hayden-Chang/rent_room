# 首套房源首页“再等等”修复

状态：`APPROVED_FOR_MERGE`。代码回归、官方编译及真实开发者工具交互回归已通过；用户在看到实际截图和行为证据后明确回复“授权，合入到主线吧”，批准当前小程序 UI 效果、分支推送及经 PR 合入。此授权不包含上传体验版、提审或发布。

## 问题和改动

首页的“点这里，新建你的第一套房源吧！”与第二套邀请共用 `waitSecondHouse`，但旧操作只清除 `returnGuide`。随后的 `showHomeXiaoda` 仍满足首套条件，提示立即再次显示。

仅在 `apps/wechat/src/lib/home-xiaoda.js` 中将首次提示推迟状态写入原来的强制保存事务，展示时识别该状态。属性 `firstHouseGuideDeferred` 与已合入的 iOS PR #127 一致。没有把关闭提示伪装为已创建首套房源，不修改教学开关、房源记录、媒体、点数或页面布局。第二套邀请和反馈/感谢状态保持各自原有行为。保存失败保留原提示并可重试。

## 代码验证

- Worktree：`/private/tmp/rent-room-wechat-first-house-wait-20261102`
- 分支：`codex/wechat-first-house-wait-20261102`
- 开发基线：`bb5c8311`（远程 main）；没有编辑脏的主目录。
- 本地证据：`/private/tmp/rent-room-wechat-first-house-wait-evidence-20261102`

新增 `tests/home-guide.test.js` 六项回归。在旧代码上有两项预期行为失败：推迟后首套提示仍显示，以及保存失败后成功重试仍显示。原始断言在 `pre-fix.log`。修复后六项全通过，另覆盖第二套提示、反馈/感谢防护和旧用户兼容。

新增构建后 App/Page 重启用例于 `tests/example-launch-runtime.test.js`，使用实际 `dist/app.js` 与 `dist/pages/home/index.js`、真实 store 和可丢弃文件系统 mock，验证首套提示关闭、重建 App 后保持关闭、两套示例及点数和教学进度保留。此 VM 测试不声称执行了真实触摸。

| 边界 | 定向用例 | 结果 |
| --- | --- | --- |
| 首套提示关闭、持久化、失败回滚、兼容和防护 | `tests/home-guide.test.js` | 6 通过 |
| 既有第二套提示、反馈提交与关闭、设置保存 | `tests/first-meeting-runtime.test.js` | 14 通过 |
| 实际构建 App/Page 重启及示例保护 | `tests/example-launch-runtime.test.js` | 7 通过 |

实际命令：先 `npm run build`，然后定向运行上述三文件。新增 App/Page 用例后对其所在最小文件单独运行，7 项全通过；其他通过结果来自相同生产源码，未因测试文件新增而冒称全套再次执行。日志为 `build.log`、`post-fix.log`、`built-page.log`。

`npm run check` 通过：官方 wcc 编译 22 份 WXML、wcsc 编译 24 份 WXSS，15 页、主包 2,096,640 字节。完整日志 `check.log` 和应用工作树内 `apps/wechat/artifacts/compile-result.json`。未修改或提交 dist、生成清单、密钥或工具个人配置。

## 真实交互计划与环境阻碍

新增 `tests/e2e/home-guide-wait.cjs`，通过固定实例池连接、只读观测真实首页；实际设置、再等等、切页、新建操作由 CUA 原生点击完成。DevTools Compile 重载用于证明 App 重启后仍持久化。脚本核对示例记录、点数和首次教学，并导出关闭前、关闭后、重载后和教学截图。测试数据必须使用 `WECHAT_TEST_DATA_ROOT=xunju-test-home-guide-wait-20261102` 的独立构建。

初始共享池状态：槽 1/2/3 均为 `quarantined`；三个原控制任务已退出，但对应开发者工具进程仍存活。槽 1/2 原健康检查失败，槽 3 的 IDE 和内部服务未同时就绪。用户明确授权“允许恢复槽 3 并继续验收”后，通过固定 recover 入口恢复槽 3，保留登录配置，没有操作其他槽。维护回执为 `slot-3-recovery-receipt.json`。

首轮 `1c92f9218e61403abd9c373c16e65b1e` 已证明关闭提示和切页，但在 DevTools Compile 重载后 SDK 读取超时，未完成全流程。原始失败回执、日志、断言及已取得截图保存在 `attempt-01/`。只修复测试观察脚本，让重载后重新连接同一个受租约管理的 SDK 端点；未再次更改业务修复。第二轮实际发生一次断线重连并完成全部行为断言，不把重连隐去或把首轮冒称通过。

## 已完成的真实点击证据

- 代码证据 SHA：`23ef3cb5e4c46fe6e3f5f1330c0ca4a28fe98337`；其业务源码及单位回归相对 `b9034a8f35e75a5bb5cb761f7590a01272a749c3` 未变，唯一变化是 E2E 观察脚本重连。原 27 项单位/VM 通过结果可以复用；新增或修改的唯一 E2E 脚本已完整执行。
- run ID：`f80dc31c683440bc9735d13f73b6f9e2`，runner PID 31524，槽 3 复用 PID 30184；源码快照状态为空。
- 快照哈希：`9240a911df5ef0b6bc2aa43b23e82c373221da1cb26c0713e243f1551778fed9`。
- 工具 Stable 2.01.2510290、基础库 3.17.3、iPhone 12/13 (Pro) 模拟器，首页 390 × 671 CSS 像素；SDK 首页实际截图 780 × 1342 像素，教学截图 780 × 1506 像素。
- 固定入口：`WECHAT_POOL_UI_REVIEW=1 python3 /Volumes/mac2/codex-builds/wechat-instance-pool/runner/pool.py --root /Volumes/mac2/codex-builds/wechat-instance-pool run --project /private/tmp/rent-room-wechat-first-house-wait-20261102/apps/wechat/dist --wait 120 --timeout 720 -- node /private/tmp/rent-room-wechat-first-house-wait-20261102/apps/wechat/tests/e2e/home-guide-wait.cjs`。
- `ui-02-receipt.json` 状态 `passed`、`residentState=idle`。本任务测试数据已由池清理，项目关闭、租约正常归还；工具进程保留，不退出其他任务或用户实例。

原生 CUA 依次真实点击：首次设置“排好啦”→“选好啦”→首套提示“再等等”→我的→房源→开发者工具 Compile 重载 App→新建→创建房源。观察脚本未调用这些生产 handler 或直接修改页面 data。`ui-02-home-guide-assertions.json` 断言全部通过：提示关闭、App 重载后仍关闭、两套原示例完整记录及原点数保持、真实首套创建后仍进入教学第 1 步。

证据目录中的 4 张原始 SDK 截图由主 agent 检查：`home-guide-before.png`、`home-guide-after.png`、`home-guide-reopened.png`、`home-guide-teaching-preserved.png`。前者完整展示首套提示和“再等等”；后两张首页图中气泡消失、示例卡片和新建入口保留；教学图展示“看房的三个阶段”第 1/4 步。未声称已验收 iPhone/Android 实机。

主 agent 独立重读最终生产源码和用例 diff，未发现额外问题。验证后仅补充本文档，不改变源、生成输入、测试、资源或配置，因此不使上述证据失效。

早先小程序分支推送被自动审批拒绝，理由是此前 iOS 授权未覆盖新增的小程序 payload；没有绕过上传。用户随后明确回复“授权，合入到主线吧”，已授权当前分支上传 `Hayden-Chang/rent_room`、创建 PR 并合入 main。

最终合入检查：重新 fetch 的主线为 `1b1629f951a81bd28cc6f9f5f7326b8fee5001e0`，较开发基线仅新增 iOS 长按菜单和阶段教学文案相关文件，不涉及微信源码、构建输入、测试或环境。`git merge-tree --write-tree HEAD origin/main` 无冲突，模拟树 `26b0af23c6fce8a11e01c18bcc78c6ee787d690e` 相对新主线的微信业务和测试 diff，与已验证版本逐字节一致。UI 风险及选择的唯一 E2E 用例保持不变；既有 27 项单位/VM、官方编译和真实点击证据可复用。最后变更仅更新本文档的用户授权记录，不影响运行或测试。最终 PR head、Checks 和合并回执记录于 PR。
