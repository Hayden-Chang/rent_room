# 居中轮盘组件评审（2026-10-22）

本次是独立原生组件，状态 `REVIEW_READY`，等待用户视觉确认。未接入正式清单或问题页面，普通 AppRoot 不变。

## 范围与真源

- 用户确认的 17 项规则在 `apps/wechat/src/lib/wheel-fields.json`；与本次小程序分支的文件逐字节一致。
- `WheelFieldSpec` 读取同一 JSON 资源，`WheelInputDraft` 区分未填写、0、半个月、净变化及原记录。
- `WheelInputDialog` 使用原生 Picker/wheel，居中展示，关闭、遮罩、清空、确定和放弃修改确认由组件处理；确认前不写业务 store。
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

共享 runner 实时配置容量 3，开发计划显式声明 XunjuTests/XunjuUITests；没有全量运行旧套件。

1. `xunju-wheel-components-20261022-01`：依赖解析因全局 HTTPS→SSH 重写而失败，未执行测试。后续仅在本次构建环境跳过全局 Git 配置，未改系统设置。
2. `...-02` / `efe1c1c`：4 UT 全通过，17 项选择 UI 通过（128.667 秒），另一个 UI 在最后遮罩取消处失败。此前关闭、放弃、清空、0 和滚回原值均已执行；保留完整日志、录屏、触点与原始附件，不称一次全绿。
3. `0b4b3d2`：为 Picker 增加显式 contentShape 限制触摸区域；失败流程增加选择已生效断言及遮罩前后截图。`...-03` 仅重跑失败方法，88.583 秒通过；含选择落定前置断言、关闭/遮罩提示、继续编辑、放弃、清空、0、滚回原值及最终截图。复用上轮4 UT和17项选择UI，去重4 UT、2 UI均有通过证据；不是同一提交一次完整全绿。

`02` 与 `03` 的计划、命令、日志和 `.xcresult` 位于本 worktree 忽略目录 `artifacts/ios-wheel-02/`、`artifacts/ios-wheel-03/`。共享构建缓存注册到本 worktree，实际名称 `/Volumes/mac2/codex-builds/time-fragment-dd-shared-e3848fe0a88c9e75298b1629-simulator`；虽含历史前缀，未借用其他任务工作区。原截图为 1178×2556，设备 iPhone 16/iOS 26.5。

## 证据复用及后续边界

从 `efe1c1c` 到 `0b4b3d2` 只调整轮盘触摸范围及失败方法的前置观察。字段 JSON、草稿模型、布局、文案、资源和 17 项选择用例不变。策略 UT 证据可复用；17 项选择均在轮盘内部，遮罩范围修正不改变这些选项的规则和绘制，保留其原 SHA 来源，不能改称新提交截图。

视觉批准后再接入正式 MPFieldRow/清单及问题的保存路径，并应用小程序同源的记录统计和楼层校验改动，再按实际业务 diff 验证持久化、重启和归档只读。当前组件宿主不证明这些下游业务，也不证明真机滚动、中文输入或系统返回手势。

独立分支 `codex/wheel-input-ios-20261022` 基于仍未合并的原生开发分支 `codex/ios-parity-20261019`（4cabe5f）。不混入地图等其他待审变更；未合并、真机部署或发布。
