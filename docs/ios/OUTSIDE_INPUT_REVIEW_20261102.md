# 点击外部结束输入（2026-11-02）

## 交互契约

- 点当前输入框之外的空白、标题或普通控件，结束当前输入并收起键盘，保留输入内容。
- 点其他按钮时同一次点击继续执行按钮原动作。
- 点另一个可编辑输入框时交由原生焦点切换，不额外隐藏新输入框的键盘。
- 当前输入框内部、光标选择、键盘与键盘附件不触发外部结束输入。
- 不改变轮盘选择或带明确取消/保存按钮的弹窗提交规则。

## 本次可审查范围

iOS `OutsideInputTap` 以不取消/延迟目标触摸的窗口手势观察器实现，组件经用户批准后已在 `AppRoot` 接入。DEBUG `outside-input` 评审页复用 `MPFieldRow` 和 `SummaryInput`，使用独立 UserDefaults suite 验证组件保留；另以真实房源、清单及总结流程验证生产 NativeStore 保存，最终结果见文末。

微信 `field-row` 的 blur/confirm 先提交原生事件中的最终 value/otherText，复用原来的 answer/store 路径；blur 不调用 hideKeyboard，避免打断新输入框；confirm 结束输入并收起键盘。输入范围覆盖数值、文本、其他补充、费用、手填测速和通勤。

## 影响与测试映射

| 改动边界 | 验证入口 |
| --- | --- |
| iOS 外部目标、输入内部、附件及焦点转移 | `XunjuTests/OutsideInputTapTests` 四个精确方法 |
| iOS 真键盘、标题/按钮点击、字段切换及重开 | `XunjuUITests/OutsideInputReviewTests/testOutsideTitleButtonAndFocusTransferRetainValuesAfterRelaunch` |
| iOS 其他文字、多行输入、完成及重开 | `XunjuUITests/OutsideInputReviewTests/testOtherTextMultilineAndDoneKeepContent` |
| iOS 真实清单/总结中文内容、按钮及 NativeStore 重启保存 | `XunjuUITests/OutsideInputBusinessTests/testChecklistAndSummarySaveOnOutsideTapAfterRelaunch` |
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

## 用户批准后的业务接入

2026-11-02 用户在查看组件截图及微信验收缺口后明确回复“没问题，合入”，组件状态为 `APPROVED`，授权继续业务接入及 PR 合并。`AppRoot` 统一挂载已批准的观察器，沿用清单、问题及总结已有的即时持久化路径；没有改动显式取消/保存弹窗的提交规则。

新增 `OutsideInputBusinessTests/testChecklistAndSummarySaveOnOutsideTapAfterRelaunch`：独立 business-test 数据目录，经过真实新增房源、清单中文输入、点击字段标题、总结多行备注、点击意向按钮，再启动后核对 NativeStore 保存内容。没有用评审 UserDefaults 代替业务保存。

接入后的最终验证选择原 4 个单元测试和 3 个精确 UI 方法（上述业务方法及原 2 个组件方法），覆盖生产挂载与持久化、外部按钮/焦点转移、完成/多行边界。微信实例池再次检查仍三槽不可用，真实页面与实体设备效果仍待验收，不能描述为已通过；用户已知该缺口并授权合入。

`9c72d2b1633a175561e36fcbc4b037021291ea77` 的 e 轮（iPhone 16 / iOS 26.5，UDID `759E28A9-21EB-4AA1-9F4F-EF1850989C56`）为 6 通过 / 1 失败：真实房源清单及总结中文输入、外部点击和 NativeStore 重启保存通过；组件多行用例输入到 `qu` 后键盘消失，未到主动外部点击步骤。保留 `ios-e.log`、`attachments-e` 中失败录像及 `keyboard-e.log`，系统 InputUI 同期记录键盘状态异常，但不能据此确定根因。

f 轮按单失败恢复规则，保持同 SHA、同设备、同超时和断言，仅精确复跑 `testOtherTextMultilineAndDoneKeepContent`，22.494 秒通过；没有代码修复，保留偶发异常限制。结果包分别为 `/Volumes/mac2/codex-builds/rent-room-outside-input-e.xcresult`、`/Volumes/mac2/codex-builds/rent-room-outside-input-f.xcresult`；本地证据根中的 `plan-e.json`/`plan-f.json` 和 `run-e.sh`/`run-f.sh` 记录完整命令。

准备合并时主线前进至 `4293b686f0e12f231f4d28c4c59c17731a6dbd22`，新增 store/credit-storage/bridge 保存优化，不能直接判定旧验证等价。合并模拟树 `208d9e2ba8d690b1d6f3c39ee17db14e573124b8` 无冲突；已在任务分支合入该主线，随后使用相同 4 单元 + 3 UI 方法以及微信保存相关用例重新验证组合结果。未操作主工作区。


## 合并前最终验证

- 已验证提交：`f2ac67dfd203cb4f50bc10228d2a69e3f2e2c588`，包含主线 `4293b686f0e12f231f4d28c4c59c17731a6dbd22`；运行期间工作树干净且冻结。
- iOS g 轮：4 个单元测试 + 3 个精确 UI 方法全部通过，0 失败、0 跳过，本轮无重试。iPhone 16 / iOS Simulator 26.5（23F77），UDID `759E28A9-21EB-4AA1-9F4F-EF1850989C56`。业务用例 45.957 秒，多行用例 25.012 秒，标题/按钮/切换用例 34.294 秒。
- 计划、命令、日志：证据根中的 `plan-g.json`、`run-g.sh`、`validate-g.sh`、`ios-g.log`。结果包 `/Volumes/mac2/codex-builds/rent-room-outside-input-g.xcresult`；receipt `/tmp/todo-ios-sim-pool/run-receipts/rent-room-outside-input-20261102-g.json`，build/test exit code 均为 0。
- 原始截图在证据根 `attachments-g/manifest.json` 对应目录，9 张均为 1178 × 2556 px；主 agent 逐张检查。真实业务截图显示“衣柜、书桌”在点击标题后保留、键盘收起；总结“采光好 / 入住时间待确认”和“考虑租住”在一次外部按钮点击后及重启后保留。组件截图覆盖数字键盘、标题、按钮、重开和多行输入，未观察到布局异常。
- 微信在 Node 24.22.2、`--maxWorkers=1` 下运行上述 4 个测试文件，31/31 通过；`npm run build && npm run check` 通过，官方 WXML/WXSS 编译 21/23 个文件，普通配置 2,091,723 bytes。日志 `wechat-g.log`。本轮结果不抹去前文保留的早期超时。
- 证据提交之后只补充本 Markdown，源码、测试、生成输入、构建配置及测试选择器均未改变；最终文档提交复用 g 轮证据，不宣称截图来自后续文档提交。PR 发布后另行复核最终 diff、范围和验证映射，无新增可操作代码问题。GitHub combined status 空列表，不等同远程 CI 通过。
- e 轮键盘偶发异常仍按原记录保留，根因未定；同设备精确恢复及最新主线完整定向验证通过。微信 DevTools 实际页面、手机系统键盘和中文组合输入仍未验收；用户已知验收缺口并批准合并。未执行部署、上传或发布。
