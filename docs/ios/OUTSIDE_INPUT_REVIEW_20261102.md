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

官方编译通过：21 个 WXML、23 个 WXSS；独立测试数据目录构建为 2,097,074 bytes，小于 2 MiB（余量 78 bytes）。普通发行配置须独立检查，不把测试构建用于发行。

本地证据根：`/private/tmp/rent-room-input-evidence-20261102/`。原始微信失败：`/private/tmp/tap-outside-wechat-before.log`。真实设备的中文输入法、键盘收起和 iOS/Android 差异仍须验收；DevTools SDK 输入不等于手机系统键盘。

当前 iOS 组件运行证据待补充；未获视觉批准，未接入业务、合并或发布。
