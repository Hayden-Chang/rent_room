# 房源长按提示验收（2026-10-30）

## 范围与状态

需求：iOS 与微信房源列表上方显示“长按支持更多操作 / 我知道了”；点击后移除提示和占用空间，本机以后不再显示。没有房源时不显示，不修改房源记录。

微信已接入正式首页源码。iOS 为 `HouseLongPressHint` 真实 SwiftUI 组件和 DEBUG 隔离评审入口，状态 `REVIEW_READY`，**尚未接入正式 HomePage**，等待用户明确确认截图。PR #103 保持 Draft；未合并、上传或发布。

实现使用各端独立的本机偏好，不随账号、房源备份或导入内容切换。微信写入失败保留提示并显示现有错误提示；读取失败不阻塞房源列表。iOS 尊重减少动态效果设置，并在辅助功能大字号下改为纵向布局。

## 证据位置

本机证据根目录：`/Volumes/mac2/projects/git_repo/run_self/rent_room/outputs/house-long-press-hint-20261030/`。截图、日志及 xcresult 不进入业务包。

- iOS 证据 SHA：`5f1d8516aa6abaa627bfd7150d7cc1c1ce04e6ef`。
- 当前执行代码 SHA：`a5ce11a871e8ed6f50cb4f1f2be7a93af7168858`。
- 二者之间仅修改微信 E2E 的观察与原生点击协作流程；iOS 源码、测试、主题、配置和依赖均未变化，复用 iOS 证据。
- 微信单测和编译在 `d424d777b740bbe56e9b8366d6f72658398f9c69` 完成；之后仅修改 E2E 脚本，生产源码、单测、构建输入及依赖相同，结果保持适用。
- 基线 `origin/main`：`9d37a6f0410ba074f40a8e5f6acf8e3a17db490b`，交付前 fetch 未发现前进。

## 定向验证

| 变更边界 | 用例与结果 |
| --- | --- |
| 本机关闭偏好及页面生命周期 | `tests/house-long-press-hint.test.js`：持久化/房源数据保留、账号切换、写失败、读失败，共 4 项通过 |
| 首页 guest 生命周期 | `tests/guest-runtime.test.js`：8 项通过 |
| 微信模板与样式 | 官方 wcc 20 文件、wcsc 22 文件，均 exit 0 |
| DEBUG 入口隔离 | `XunjuTests/HouseLongPressHintTests/testReviewRequiresExplicitKnownRoute` 通过 |
| iOS 关闭与重启 | `XunjuUITests/HouseLongPressHintUITests/testDismissCollapsesSpaceAndStaysDismissedAfterRelaunch` 通过 |
| iOS 空列表 | `XunjuUITests/HouseLongPressHintUITests/testEmptyListWaitsUntilThereIsAHouse` 通过 |
| 英文与辅助功能字号 | `XunjuUITests/HouseLongPressHintUITests/testEnglishLargeTextKeepsDismissAccessible` 通过 |

只运行上述 1 项 iOS 单测、3 项 XCUITest 和 12 项微信单测；未运行完整旧套件。iOS 通过 4 项、失败/跳过 0 项。设备为共享池 iPhone 14 Pro / iOS 18.3.1 模拟器，原始截图 1178×2556。这是组件评审证据，不是正式房源页或真机证据。

微信命令（工作目录 `apps/wechat`，Node 24.19.0）：

```sh
WECHAT_TEST_DATA_ROOT=xunju-test-house-hint-20261030 node scripts/build.mjs
npx vitest run tests/house-long-press-hint.test.js tests/guest-runtime.test.js
node scripts/check.mjs
```

iOS 完整命令和精确 selectors 保存在 `run-ios-03.sh`、`ios-plan-03.json`。使用统一 Simulator Management runner 和 XcodeGen；生成的 Xcode project 未提交。结果为 `ios-03.xcresult`，摘要 `ios-summary.json`，runner receipt 为 `ios-runner-receipt.json`。

| iOS 状态 | `ios-attachments/` 内文件 |
| --- | --- |
| 关闭前 | `51FEB201-667C-40EE-9C10-71FE62D753E1.png` |
| 关闭后 | `B5D10B54-AD51-462F-919E-3ED37CD89D29.png` |
| 重启后 | `5615485E-E1C1-4825-806F-AD6976BC8486.png` |
| 空列表 | `930B6DED-818B-4255-B884-91DB53E5A8D7.png` |
| 英文大字号 | `F13DE33F-2A6F-4791-828C-4419FE16AD99.png` |

主 agent 已查看全部截图：提示文本、按钮和图标完整可见，关闭后卡片填满原提示及其间距，重启后保持隐藏；英文辅助功能大字号下按钮可点。

## 环境失败记录

保留第一次微信 SDK Page 查询挂起（run `05eba54b9e19481ca7cf47659ead7654`）和工具池无可用槽（`bc294bdad7b24dbeb50559069be6d342`）的失败记录。后续 E2E 使用 App.evaluate 只观察布局/状态，由 CUA 点击真实按钮，不调用被测 handler。

用户明确授权恢复一个空闲隔离槽后，仅维护 1 号槽；期间该槽被其他任务领用再隔离，按同一授权和内核锁流程恢复，maintenance receipts 留存。我们的 `9ae116ed110242b9b956e85331c07561` 在 1 号槽健康检查失败，原生截图显示开发者工具欢迎页，未启动业务页；该次没有执行功能测试。

iOS 前两次尝试分别为 SwiftPM 全局 Git URL rewrite 导致 SSH 依赖拉取失败，以及冻结检查发现排队期间提交变化。采用进程级 HTTPS URL rewrite 并冻结 HEAD 后，第 3 次运行通过。没有修改全局 Git 配置，也没有覆盖原失败记录。

## 主 agent 审查

已检查差异、条件布局、偏好与房源存储分离、异常处理、DEBUG 路由隔离和截图。当前没有功能返工项。GitHub 对 `a5ce11a` 返回 status 与 workflow runs 为空，不能称 CI 通过。

待完成：用户视觉确认、批准后的 iOS 正式页集成与相应定向验证。当前不具备合并条件。

## 微信真实点击验收

最终通过 run：`1b949116098840a199d11bea6b876ca6`，源码 SHA `a5ce11a871e8ed6f50cb4f1f2be7a93af7168858`，sourceStatus 为空。DevTools 2.01.2510290，基础库 3.17.3，iPhone 12/13 (Pro) 390px 视口，页面截图 780×1342。正常队列接续 3 号槽，不重启其他任务；结束后数据清理和关闭项目通过，residentState 为 idle，常驻进程保留。

```sh
PATH=/Users/pc/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin:$PATH WECHAT_POOL_UI_REVIEW=1 python3 /Volumes/mac2/codex-builds/wechat-instance-pool/runner/pool.py --root /Volumes/mac2/codex-builds/wechat-instance-pool run --project /Users/pc/.codex/worktrees/house-long-press-hint/rent_room/apps/wechat/dist --wait 300 --timeout 240 -- node /Users/pc/.codex/worktrees/house-long-press-hint/rent_room/apps/wechat/tests/e2e/house-long-press-hint.cjs
```

CUA 在已核实属于本次租约的原生窗口中点击“我知道了”（AX button）。脚本只准备可丢弃房源、观察状态/布局和执行后续导航，没有调用关闭 handler。记录证明：

- 空房源列表不显示提示；存在房源时显示完整文案和按钮。
- 提示高 52px，底部间距 16px。点击后首张卡片 top 从 84px 变为 16px，正好上移 68px，提示节点消失。
- 房源 JSON 在点击前后一致。
- 切换“我的”再回房源、reLaunch 房源页后仍隐藏，卡片 top 保持 16px，storage 布尔值为 true。App 冷启动记忆另由 VM 单测覆盖，未声称微信客户端冷启动或真机结果。
- 主 agent 已检查关闭前/后、重进、空列表四张截图，无遮挡或残留间距。

证据位于上述根目录的 `wechat-1b949116098840a199d11bea6b876ca6/`：`house-hint-before.png`、`house-hint-after.png`、`house-hint-reopened.png`、`house-hint-empty.png`、`house-hint-assertions.json`、`test.log`、`receipt.json`。源码冻结哈希 `9989009d286a4b2a6eb8c23eaf5acb36be42724898b0a5bc73836fa2bfa4c18f`。

等待健康槽期间另一次 300 秒排队超时 `ec251eeaea58409b81e016ee9dc6e17c` 已保留；该次未运行测试。最后通过后只增加本验收文档，不影响生产、构建、测试或原始证据。
