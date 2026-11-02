# 点击外部结束输入（2026-11-02）

## 交互契约

- 点当前输入框之外的空白、标题或普通控件，结束当前输入并收起键盘，保留输入内容。
- 点其他按钮时同一次点击继续执行按钮原动作。
- 点另一个可编辑输入框时交由原生焦点切换，不额外隐藏新输入框的键盘。
- 当前输入框内部、光标选择、键盘与键盘附件不触发外部结束输入。
- 不改变轮盘选择或带明确取消/保存按钮的弹窗提交规则。

## 本次可审查范围

iOS `OutsideInputTap` 以不取消/延迟目标触摸的窗口手势观察器实现，现阶段仅挂载在 DEBUG `outside-input` 组件评审入口，尚未接入 `AppRoot` 或业务页面。评审页复用 `MPFieldRow` 和 `SummaryInput`，使用每次测试独立的 UserDefaults suite 验证重新打开保留；这不是生产 NativeStore 端到端保存证据。

微信 `field-row` 的 blur/confirm 先提交原生事件中的最终 value/otherText，复用原来的 answer/store 路径；blur 不调用 hideKeyboard，避免打断新输入框；confirm 结束输入并收起键盘。输入范围覆盖数值、文本、其他补充、费用、手填测速和通勤。

## 影响与测试映射

| 改动边界 | 验证入口 |
| --- | --- |
| iOS 外部目标、输入内部、附件及焦点转移 | `XunjuTests/OutsideInputTapTests` 四个精确方法 |
| iOS 真键盘、标题/按钮点击、字段切换及重开 | `XunjuUITests/OutsideInputReviewTests/testOutsideTitleButtonAndFocusTransferRetainValuesAfterRelaunch` |
| iOS 其他文字、多行输入、完成及重开 | `XunjuUITests/OutsideInputReviewTests/testOtherTextMultilineAndDoneKeepContent` |
| 微信最终文字、清空、只读、落盘重读 | `tests/field-row-finish-input.test.js` |
| 微信占位、焦点同步、问题列表、左滑保护 | `field-row-placeholder.test.js`、`missing-items-runtime.test.js`、`field-row-swipe.test.js` |
| 微信真实渲染、输入和外部按钮、存储重载 | 共享池执行 `tests/e2e/finish-input.cjs` |

## 已有证据与边界

基线 `4f9ca32`；新增微信回归在修复前 4 失败 / 1 通过，均为最终事件值未写入，旧值仍在持久化存储。修复后 31 个相关用例通过。

Node 24.22.2 定向 campaign 30 通过 / 1 超时；仅重跑超时的 `f54_1 (缺少的家电 / 冰箱) retains bound input text on blur, edits, clearing and reload in 清单`，单 worker 下通过，无改动测试超时限制。保留原始失败，不能把这一重跑当成未发生过超时。

Node 24 官方编译通过：21 个 WXML、23 个 WXSS；独立测试数据目录构建为 2,097,074 bytes，小于 2 MiB（余量 78 bytes）。普通发行配置另行构建/检查通过，为 2,097,048 bytes（余量 104 bytes）；未上传或发行。

本地证据根：`/private/tmp/rent-room-input-evidence-20261102/`。原始微信失败：`/private/tmp/tap-outside-wechat-before.log`。真实设备的中文输入法、键盘收起和 iOS/Android 差异仍须验收；DevTools SDK 输入不等于手机系统键盘。

微信共享池两次均在 health-before 的 App/页面就绪阶段超时，回调没有执行，因此新增 E2E 尚未验收，不能声称微信真实渲染或系统键盘验证通过。原始 run ID 为 `5b2333992d0e4b85ae2d3537324f1e5b`、`7ce5a701961249c6a512ad90be033742`，receipt 保留在 `/Volumes/mac2/codex-builds/wechat-instance-pool/runs/`。

## iOS 组件实测

- 证据提交：`f5f179f0b4b28613b7dca5bdd8269d2fffbf870e`，运行时工作树干净。
- 共享 runner run ID：`rent-room-outside-input-20261102-d`；build/test exit code 均为 0；4 个单元测试和上述 2 个精确 XCUITest 全部通过，无跳过。未运行全量测试。
- 设备：iPhone 14 Pro，iOS Simulator 18.3.1，UDID `8F178971-C203-4690-A83B-253046EACBB1`；截图均为 1178 × 2556 px。
- 计划及完整选择器：`/private/tmp/rent-room-input-evidence-20261102/plan-d.json`；日志：同目录 `ios-d.log`。
- 结果包：`/Volumes/mac2/codex-builds/rent-room-outside-input-d.xcresult`；runner receipt：`/tmp/todo-ios-sim-pool/run-receipts/rent-room-outside-input-20261102-d.json`。
- 实际附件：`/private/tmp/rent-room-input-evidence-20261102/attachments/manifest.json`（保留原始 PNG 与测试名称映射）。

| 附件 | 直接验证内容 |
| --- | --- |
| `outside-01-editing-rent` | 租金 2800，光标与数字键盘可见，完成按钮位于键盘上方 |
| `outside-02-title-saved` | 点击“基本信息”后键盘、光标消失，租金仍为 2800，行位置不变 |
| `outside-03-button-and-saved` | 再次切换输入并编辑后，点按钮一次，标记关注变为 1，键盘收起，两个字段保留 |
| `outside-04-reopened` | 重启评审页后租金与家具文字保留；临时按钮计数按预期重置 |
| `outside-05-multiline-saved` | 其他补充文字及两行备注保留，键盘收起；同一用例另断言重开后仍保留 |

主 agent 已检查全部 5 张原始截图：白色输入卡片、标签对齐及按钮位置正常，没有观察到收起键盘导致字段消失或内容清空。数字测试在重新点击后的原生光标位置插入 0，因此最后显示 02800；此用例验证焦点转移和保留，不验证金额格式化。证据限于评审夹具、模拟器和英文/数字输入，未覆盖生产保存链路、中文组合输入或实体设备。

PR 创建后已另行复核最终代码、测试映射和证据；未发现新的可操作代码问题。GitHub combined status 返回空列表，不视为远程 CI 通过。本次证据补充只修改 Markdown，未改变源码、测试、生成输入、配置或选择器，因此复用 `f5f179f` 的组件运行证据，不将截图宣称为后续文档提交产生。

当前状态：组件 `REVIEW_READY`，整项任务 `not merge-ready`。尚需用户批准实际组件效果，之后才能接入 iOS 业务页面并验证真实保存；微信 E2E 和受影响平台真机效果仍待验收。未合并、部署或发布。
