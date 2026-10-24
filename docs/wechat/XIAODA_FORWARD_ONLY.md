# 小搭只向后引导（2026-10-24）

用户确认的规则：A 未填完，B 完成后引导 C；C 完成后引导 D；D 部分填写后，用户回到 B 修改并写完，跳过已完成 C，引导 D。前面的 A 由用户主动返回。

## 实现

- `xiaoda-flow.js` 从当前类别在房源清单中的位置之后查找第一个未完成类别，不按最近活动或阶段优先级回头。
- 后面已全部完成但前面有遗漏时，结束本次提示；全屋完成提示仍要求所有有效项完成。现场有前置遗漏时不宣称“现场记录好啦”。
- 实际结果修改后类别处于完成状态即可重新引导。提示带上本次完成来源，动画和输入取消校验使用本次来源，不误用首次完成历史的最后一项。
- 答案、备注、媒体、模板顺序、首次完成历史与关闭小搭的作用域保留。

## 定向验证映射

基线：`591f135`。Node 24.19.0，Vitest 5.0.3。

| 边界 | 选择器 / 证据 |
| --- | --- |
| 只向后、跳过已完成、最近活动不抢先、重新填写 B、末尾不回绕、跨阶段及关闭/重进 | `tests/xiaoda.test.js` 的 `completion recommendations`，修复前 7 项按预期失败，修改后 12 项通过 |
| 生产页面延迟、输入结束、接受引导、取消/切页/服务变化保护 | `tests/onboarding.test.js` |
| 向后引导后的“再等等”位置、保存失败、重进、重复填写来源及撤销 | `tests/onboarding-wait-position.test.js` |
| 渲染夹具的旧回头预期 | `node tests/e2e/xiaoda-filling-fixtures.mjs`，所有夹具构造断言通过；不作为 UI 点击证据 |
| 实际 B→C→D、修改 B→D、末尾不回 A、重开保存 | `tests/e2e/xiaoda-forward-native.cjs`，由原生 UI 点击驱动，夹具仅准备前置数据 |
| 原有“再等等”真实位置回归 | `tests/e2e/xiaoda-wait-native.cjs`，预期目标同步为 C |

已执行：上述三个 Vitest 文件共 74 项通过。`npm run build` 通过；`npm run check` 的官方 wcc 20 个 WXML、wcsc 22 个 WXSS 全部通过。没有执行全量单测或全量 UI 套件。

本地日志：任务 worktree 的 `apps/wechat/artifacts/forward-only/{red,logic-green,focused,build,check}.log`。真实 UI 的结果单独记录，不以 VM 或编译替代。

## 当前提交的实际点击证据

生产与测试提交：`7da997dbfcb8ec2be771ff74a128a1696657d990`，工作区干净。开发者工具 Stable 2.01.2510290、基础库 3.17.3，使用三槽池的可丢弃测试工程。不是物理手机验证。

`xiaoda-forward-native.cjs` 的 run `ef137a11aebb4113a3c603bf7a52fd6d` 通过，receipt 状态 `passed`、槽位归还 `idle`。实际通过 CUA 的原生可访问性按钮执行填写和接受/取消，未直接调用被测 handler：

- A 1/2，B 完成 → 提示 C。
- 接受 C、完成 C → 提示 D。
- 接受 D、仅填第一项，再将 B 最后一项改为“否” → 跳过已完成 C，提示 D，完成来源确认为 B。
- 选择“再等等”，完成 D → 没有提示返回未完成 A，也没有错误宣称全屋完成。
- 重新进入详情，答案和 A 的备注保留，没有重播提示。

截图及状态：`apps/wechat/artifacts/forward-only/native/`，重点为 `02-B-to-C.png`、`04-B-skips-C-to-D.png`、`05-no-backtracking.png`、`assertions.json` 与 `receipt.json`。构建快照 hash：`ac88e146a14d28c3b60c523416f28e9cc5dd4838af0c14b2e11b55d83ce1b463`。

基础设施记录：首次 run `d9467fe6f480421db5ddd5db967846f8` 仅排队超时，没有执行点击；后续正常获得槽位。CUA 坐标点击出现 `noWindowsAvailable`，使用同一已租用窗口的原生可访问性按钮成功操作，没有替换为 handler 调用。

主 agent 已在 PR 创建后独立检查远程最终 diff、9 个文件范围、失败/通过日志和上述原生证据，未发现需要返工的问题。核对时 main 仍为 `591f135d3216a60efe53124069bdb14a8225787d`，GitHub 可合并，未返回 workflow runs 或 commit statuses；不将空列表称为 CI 通过。PR #76 保持草稿，UI 效果等待用户确认，未合并、未发布。
