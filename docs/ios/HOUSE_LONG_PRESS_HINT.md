# 房源长按提示验收（2026-10-30）

## 范围与状态

需求：iOS 与微信房源列表上方显示“长按支持更多操作 / 我知道了”；点击后移除提示和占用空间，本机以后不再显示。没有房源时不显示，不修改房源记录。

用户于 2026-10-30 明确回复“可以的，合入”，完成视觉审批并授权合并。微信和 iOS 均已接入正式房源首页，点击后移除提示和间距；iOS 正式页定向验收通过。PR #103 已具备合并条件，本记录随最终 PR 提交；合并结果以 GitHub PR 为准。没有上传或发布。

实现使用各端独立的本机偏好，不随账号、房源备份或导入内容切换。微信写入失败保留提示并显示现有错误提示；读取失败不阻塞房源列表。iOS 尊重减少动态效果设置，并在辅助功能大字号下改为纵向布局。

## 证据位置

本机证据根目录：`/Volumes/mac2/projects/git_repo/run_self/rent_room/outputs/house-long-press-hint-20261030/`。截图、日志及 xcresult 不进入业务包。

- 首次 iOS 组件评审证据 SHA：`5f1d8516aa6abaa627bfd7150d7cc1c1ce04e6ef`。
- 微信真实点击验收 SHA：`a5ce11a871e8ed6f50cb4f1f2be7a93af7168858`。
- 上述两次初始验收之间仅修改微信 E2E 的观察与原生点击协作流程。审批后 iOS 正式页接入及测试变化已重新运行，最终证据见下文。
- 微信单测和编译在 `d424d777b740bbe56e9b8366d6f72658398f9c69` 完成；之后仅修改 E2E 脚本，生产源码、单测、构建输入及依赖相同，结果保持适用。
- 原验证基线：`9d37a6f0410ba074f40a8e5f6acf8e3a17db490b`。最终 fetch 发现 main 前进到 `5dbe378d4aa6b4f935d333d6130e97b59646e769`（PR #102，仅微信详情页同阶段引导）。对候选 `cedcf6b493bc96d6431698398f38625a9adeb165` 执行 `git merge-tree --write-tree` 无冲突，模拟合并后相对新基线的 iOS/微信业务与测试 diff 与验证版本逐字一致；记录为 `main-advance-equivalence.json`。上游仅在详情页引入 onboarding 行为变化，首页未导入该 presenter，iOS 未变；房源提示的测试选择及环境保持适用，按等价规则复用证据。本次后续提交仍仅更新文档。

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

只运行上述 1 项 iOS 单测、3 项 XCUITest 和 12 项微信单测；未运行完整旧套件。iOS 通过 4 项、失败/跳过 0 项。设备为共享池 iPhone 14 Pro / iOS 18.3.1 模拟器，原始截图 1178×2556。最初的 `ios-03` 是组件评审；审批后的 `ios-05` 覆盖正式房源页，仍属于模拟器验证，不是真机证据。

微信命令（工作目录 `apps/wechat`，Node 24.19.0）：

```sh
WECHAT_TEST_DATA_ROOT=xunju-test-house-hint-20261030 node scripts/build.mjs
npx vitest run tests/house-long-press-hint.test.js tests/guest-runtime.test.js
node scripts/check.mjs
```

初始组件评审的 iOS 完整命令和精确 selectors 保存在 `run-ios-03.sh`、`ios-plan-03.json`。使用统一 Simulator Management runner 和 XcodeGen；生成的 Xcode project 未提交。结果为 `ios-03.xcresult`，摘要 `ios-summary.json`，runner receipt 为 `ios-runner-receipt.json`。

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

已检查最终差异、正式页条件布局、偏好与房源存储分离、异常处理、DEBUG 路由隔离和全部截图。当前没有功能返工项。GitHub 状态与 workflow runs 为空，验证结论来自上述本机定向检查，不能称远端 CI 通过。

用户视觉确认、iOS 正式页集成与相应定向验证均已完成。最终代码 SHA 为 `bb011ef31e6e6d44d27c1fbdf7cbfa2c2a1b4044`；后续只更新本验收文档，生产源码、测试和构建输入不变。

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

等待健康槽期间另一次 300 秒排队超时 `ec251eeaea58409b81e016ee9dc6e17c` 已保留；该次未运行测试。该次通过后的微信目录没有变化；后续变更仅涉及 iOS 与本验收文档，因此复用此微信真实点击证据、单测及模板样式编译结果。

## 审批后的 iOS 正式页验收

- 最终代码及证据 SHA：`bb011ef31e6e6d44d27c1fbdf7cbfa2c2a1b4044`。
- `HomePage` 非空房源分支在网格之前使用 `HouseLongPressHint()`；组件默认沿用应用的 `defaultAppStorage`，生产为标准本机偏好，DEBUG 业务测试使用既有 UUID 隔离套件。
- run：`rent-room-house-hint-20261030-05`，共享池 iPhone 14 Pro / iOS 18.3.1，UDID `8F178971-C203-4690-A83B-253046EACBB1`。1 项单测、3 项 XCUITest 全部通过，失败和跳过均为 0。
- 正式页测试先通过真实货币选择按钮，再从空列表真实创建房源；空列表不显示提示，新增后出现提示。点击关闭后卡片上移 68pt（容差 1pt），房源标签不变；切换“我的”再返回、终止并重新启动应用后保持关闭。随后验证房源长按菜单和点击进入详情正常。
- 另外保留独立评审入口的空列表及英文辅助功能大字号测试。主 agent 已检查本轮 6 张截图，正式页关闭后无残留间距，英文文案和按钮完整可见。
- 完整命令：`run-ios-05.sh`；精确 selectors：`ios-plan-05.json`；日志：`ios-05.log`；结果：`ios-05.xcresult` / `ios-05.build.xcresult`；摘要：`ios-05-summary.json`；runner receipt：`ios-05-runner-receipt.json`。构建与测试均 exit 0，租约及运行槽已释放。

| 状态 | `ios-05-attachments/` 内文件 |
| --- | --- |
| 正式房源页关闭前 | `DE3A0313-A02F-4C4F-985E-71178324EFBB.png` |
| 正式房源页关闭后 | `07F66691-6A97-4FD7-A032-7FD326135F9C.png` |
| 正式房源页重启后 | `EB718382-F111-41B9-9715-45300B0D780D.png` |
| 正式房源页空列表 | `1EC7847F-1406-48EB-BF0F-83C09DC54206.png` |
| 独立评审空列表 | `FCCFEF39-49E3-4133-819A-BF43EB8CE8D7.png` |
| 英文辅助功能大字号 | `DC06407E-1520-4342-AD34-6798CFD966B5.png` |

前一轮 `ios-04` 在 SHA `1644e592d6abc82442c7e1803252a6c2e1df9dc1` 有 2 项 UI 失败：首次货币弹窗挡住点击，原像素评审三房源 fixture 还触发系统评分弹窗。截图与层级确认页面和提示本身已出现。仅调整测试前置步骤为真实选择货币和创建一个房源后，重新运行全部 4 项选定测试通过。`ios-04` 的失败日志、结果和截图原样保留，不计作通过证据。
