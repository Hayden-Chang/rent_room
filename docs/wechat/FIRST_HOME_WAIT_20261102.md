# 首套房源首页“再等等”修复

状态：代码回归及官方编译通过；真实开发者工具点击与截图待验收，当前不具备合入条件。未上传体验版、提审或发布。

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

目前尚未执行此用例。共享池状态核对：槽 1/2/3 均为 `quarantined`；三个原控制任务已退出，但对应开发者工具进程仍存活。槽 1/2 原健康检查失败，槽 3 的 IDE 和内部服务未同时就绪。按项目 AGENTS.md，只能在明确授权的维护操作中通过受保护 recover 入口处理；没有自行停止进程、删锁、清登录缓存、接管其他实例或绕开池测试。已向用户请求仅恢复槽 3 的维护授权。

真实截图和用户 UI 验收尚缺，不能把 mock/VM、编译成功或脚本语法检查当作点击验收。代码已可审查，PR 应保持草稿，等待恢复工具并完成该回归。
