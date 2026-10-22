# 居中轮盘组件评审（2026-10-22）

组件状态 `APPROVED`：用户在本会话明确表示“这版可以，继续接入 App 正式表单，小程序也继续验证，做完给我看两端的实际效果”。此前暂停的正式清单及问题页集成已经获得授权。下文保留独立组件阶段的原始证据与修复记录；正式页面及持久化验证另见 [正式表单接入记录](WHEEL_FORM_INTEGRATION.md)。

## 范围与真源

- 用户确认的 17 项规则在 `apps/wechat/src/lib/wheel-fields.json`；与本次小程序分支的文件逐字节一致。
- `WheelFieldSpec` 读取同一 JSON 资源，`WheelInputDraft` 区分未填写、0、半个月、净变化及原记录。
- `WheelInputDialog` 使用原生 Picker/wheel，居中展示，关闭、遮罩、清空、确定和放弃修改确认由组件处理；确认前不写业务 store。
- 弹窗不显示“滑动选择”或“原记录”前缀，打开即定位已有值；旧数字按数值顺序展示。扣押金的滚轮只滚动“数值 + 个月”，右侧“押金”固定，空值时隐藏并保留固定大小的占位。
- 评审宿主的朝向确定“其他”后，输入框紧跟该行下方；取消不应用选择，切换或清空后保留补充文字，再选其他恢复。
- 仅 Debug 显式 `--component-review wheels` 启用独立宿主。宿主的内存状态、手填金额/网速用于组件验证，不是业务保存证据。
- `ios/project.yml` 仅添加共享 JSON 资源。XcodeGen 2.45.4，经仓库包装脚本生成；生成的 Xunju.xcodeproj 不提交。

## 定向映射与结果

| 边界 | 精确方法 |
| --- | --- |
| 17 项范围、步长、固定选项、金额及网速例外 | XunjuTests/WheelInputTests/testPolicyRangesFixedOptionsAndManualExclusions |
| 空与 0、清空、相同语义及返回原值 | XunjuTests/WheelInputTests/testDraftDistinguishesEmptyZeroAndNetChanges |
| 旧越界值、旧精度及其他文字 | XunjuTests/WheelInputTests/testHistoricalValuesAndFormerOtherAreNeverClamped |
| 仅显式评审参数启用 | XunjuTests/WheelInputTests/testReviewRequiresExplicitArgument |
| 17 项逐项真实选择、固定床尺寸、朝向其他、手填例外 | XunjuUITests/WheelInputReviewTests/testAllSeventeenRulesAndManualExceptions |
| 草稿、确定、清空、继续编辑、放弃、净变化和遮罩取消 | XunjuUITests/WheelInputReviewTests/testDraftConfirmClearAndDiscard |
| 已有值初始定位、固定押金后缀、其他输入/恢复、清空前后高度与按钮对齐 | XunjuUITests/WheelInputReviewTests/testExistingValuesFixedSuffixAndOtherExplanation |

共享 runner 实时配置容量 3，开发计划显式声明 XunjuTests/XunjuUITests；没有全量运行旧套件。

1. `xunju-wheel-components-20261022-01`：依赖解析因全局 HTTPS→SSH 重写而失败，未执行测试。后续仅在本次构建环境跳过全局 Git 配置，未改系统设置。
2. `...-02` / `efe1c1c`：4 UT 全通过，17 项选择 UI 通过（128.667 秒），另一个 UI 在最后遮罩取消处失败。此前关闭、放弃、清空、0 和滚回原值均已执行；保留完整日志、录屏、触点与原始附件，不称一次全绿。
3. `0b4b3d2`：为 Picker 增加显式 contentShape 限制触摸区域；失败流程增加选择已生效断言及遮罩前后截图。`...-03` 仅重跑失败方法，88.583 秒通过；含选择落定前置断言、关闭/遮罩提示、继续编辑、放弃、清空、0、滚回原值及最终截图。复用上轮4 UT和17项选择UI，去重4 UT、2 UI均有通过证据；不是同一提交一次完整全绿。

`02` 与 `03` 的计划、命令、日志和 `.xcresult` 位于本 worktree 忽略目录 `artifacts/ios-wheel-02/`、`artifacts/ios-wheel-03/`。共享构建缓存注册到本 worktree，实际名称 `/Volumes/mac2/codex-builds/time-fragment-dd-shared-e3848fe0a88c9e75298b1629-simulator`；虽含历史前缀，未借用其他任务工作区。原截图为 1178×2556，设备 iPhone 16/iOS 26.5。

## 证据复用及后续边界

第二轮修订的最终证据为 `f87c903` / `xunju-wheel-components-20261022-07`：同一批 **4 UT、3 UI 全部通过**。原始日志、计划、命令、结果摘要及 `.xcresult` 在 `artifacts/ios-wheel-07/`，31 张 1178×2556 的实际截图由该结果包导出；仍是 iPhone 16 / iOS 26.5 模拟器与独立组件宿主，不是正式业务或真机证据。

- `...-04` / `c0b5a7e`：4 UT、1 UI 通过，2 UI 失败。选值后立即读取曾得到瞬时空值，改为原生轮盘值条件等待；隐藏的押金 Text 仍存在辅助功能树，改为空值时移除 Text。
- `...-05` / `fb74124`：原断言全部通过，但主 agent 导出读图时发现移除 Text 后的透明占位撑高弹窗，暂不用于最终视觉确认。
- `...-06-red` / `d8a5fdb`：增加清空前后弹窗高度及按钮对齐回归断言，修复前精确用例失败于 **852 != 368**。完整失败结果包与日志保留。
- `f87c903` 将该占位高度限制为 24；`...-07` 重新运行全部本次定向用例，验证清空前后弹窗仍为 368、按钮水平对齐，且其他输入、旧值定位、17 项选项及取消路径通过。不是仅凭测试计数判断视觉效果。

测试输入 `SE 15` 证明文本可编辑及切换/清空后恢复；没有将其当作中文输入法或业务持久化证据。共享 runner 按计划租约运行，构建/测试命令 PID 为 16447/16580，设备 UDID `5FC4A20B-AF44-4A92-BF91-B0096BEBF1D9`；执行回执退出 0，测试租约已释放。代码完成后只更新本文，不改变执行输入。

以下是第一轮证据的历史复用说明；第二轮当前效果以 `...-07` 为准。

从 `efe1c1c` 到 `0b4b3d2` 只调整轮盘触摸范围及失败方法的前置观察。字段 JSON、草稿模型、布局、文案、资源和 17 项选择用例不变。策略 UT 证据可复用；17 项选择均在轮盘内部，遮罩范围修正不改变这些选项的规则和绘制，保留其原 SHA 来源，不能改称新提交截图。

此后按用户批准接入正式 MPFieldRow/清单及问题的保存路径，并应用小程序同源的记录统计和楼层校验改动。这里的组件宿主证据不证明下游业务、真机滚动、中文输入或系统返回手势；正式集成另行取证。

独立分支 `codex/wheel-input-ios-20261022` 基于仍未合并的原生开发分支 `codex/ios-parity-20261019`（4cabe5f）。不混入地图等其他待审变更；未合并、真机部署或发布。
