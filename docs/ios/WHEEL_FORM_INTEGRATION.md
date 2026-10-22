# 轮盘正式表单接入（2026-10-22）

用户已明确批准组件样式并授权继续正式业务集成，批准原文及组件证据见 [组件评审](WHEEL_COMPONENT_REVIEW.md)。本次进入普通 AppRoot，使用实际房源、清单、问题页和 NativeStore；不要求组件评审参数。

## 接入与状态保护

- `WorkspaceRoot` 持有全屏居中弹窗，清单和自动问题通过同一 `InspectionFieldRow` / `MPFieldRow` 打开，避免被列表裁剪或从底部弹出。
- `WheelInputPresentation` 只在确定时调用原有 `NativeStore.answer`，取消不保存。相同语义的旧格式不重写；保存只改 value，保留备注、问题标记、媒体和 otherText。
- 朝向确定其他后显示字段下方的输入框，改选、清空后保留补充内容，再选其他恢复。金额及网速保持手填；通勤仍保留查询入口。
- 打开时及确定时检查归档状态；确定时检查 store 身份，账号变化关闭旧弹窗。归档按钮只读，不能从问题卡片绕过。
- 17 项 JSON 策略及 `wheel-input.js` 与小程序分支逐字节一致。共享模型同步轮盘路由、连续天数记录统计及楼层 -1 校验；`XunjuCore.js` 由 56 个规范源重新生成（248857 字节），不是手改 bundle。
- XcodeGen 2.45.4 经本仓库包装脚本生成和校验，未提交生成的 `.xcodeproj`；独立组件宿主仅 Debug 显式参数启用，Release 不含该入口。

## 定向测试映射

全部方法用 `-only-testing:目标/类/方法` 精确选择。最终 UI 仅 3 个方法，按下表优先级覆盖正式入口、跨页面保护和通勤可读性；共享行手势另在开发批次验证。未运行全量旧 UT/UI。

| 边界 | 目标/类/精确方法 |
| --- | --- |
| 全部 17 项路由、转租许可前提、21 天新选项的已记录过滤、金额手填 | XunjuTests/WheelBusinessTests/testRealFormRoutesAllSeventeenWheelsAndKeepsMoneyManual |
| 确定保存、-1、空与 0、重载、备注/问题标记及其他说明保留 | XunjuTests/WheelBusinessTests/testConfirmedAnswersReloadKeepAnnotationsOtherAndEmptyZero |
| 取消、原值 220 不重写、归档及身份变化保护 | XunjuTests/WheelBusinessTests/testCancelUntouchedLegacyAndReadonlyIdentityGuards |
| 策略及手填例外 | XunjuTests/WheelInputTests/testPolicyRangesFixedOptionsAndManualExclusions |
| 草稿语义、空与 0、净变化 | XunjuTests/WheelInputTests/testDraftDistinguishesEmptyZeroAndNetChanges |
| 旧越界/精度及其他选项 | XunjuTests/WheelInputTests/testHistoricalValuesAndFormerOtherAreNeverClamped |
| 独立评审参数隔离 | XunjuTests/WheelInputTests/testReviewRequiresExplicitArgument |
| 共享表单层级与折叠不写答案 | XunjuTests/ChecklistPresentationTests/testEveryCategoryAndGroupFoldsOnlyItsDescendantsWithoutWritingAnswers |
| 原有多选、其他及问题标记 | XunjuTests/ChecklistPresentationTests/testSharedChoiceAdapterPreservesMultipleOtherAndFlagAcrossRelaunch |
| 原有字段类型与自定义费用 | XunjuTests/ChecklistPresentationTests/testDividersAndFieldTypesMatchRealFormIncludingDynamicCosts |
| 真正 JSON 桥接及空/0 持久化 | XunjuTests/NativeStoreTests/testCanonicalCatalogAndRoundTripRetainAnswersAndZero |
| 容量、归档及还原保护 | XunjuTests/NativeStoreTests/testCapacityArchiveReadOnlyRestoreAndDeleteProtection |
| 问题标记/过滤与折叠 | XunjuTests/NativeStoreTests/testIndependentIssueFlagFilteringAndCollapsedFormDoNotMutate |
| 既有单选命令和其他说明重启 | XunjuTests/BusinessIntegrationTests/testChoiceCommandRetainsMultipleValuesAndOtherDetailAcrossRelaunch |
| 共享行滑动跟手、反向、竖滚及单活动行 | XunjuTests/MiniProgramComponentTests/testSwipeFollowsFingerAndHandlesReverseAndVerticalScroll |
| 快速短划与边界夹紧 | XunjuTests/MiniProgramComponentTests/testSwipeFastShortFlickAndClampedTravel |
| 原生短划速度判定 | XunjuTests/MiniProgramComponentTests/testNativeShortFlickUsesRecognizedVelocity |
| 通勤轮盘全部选项、字体/箭头/间距/内边距的可读宽度 | XunjuTests/WheelBusinessTests/testCommuteWheelLabelHasSpaceForEveryMinuteOption |
| UI 优先 1：正式清单入口、遮罩/关闭、空与 0、其他输入、终止后重启恢复 | XunjuUITests/WheelBusinessUITests/testChecklistWheelOtherCancelAndRelaunchPersistence |
| UI 优先 2：固定后缀/半月/清空高度、问题页同值保存、金额输入和归档只读 | XunjuUITests/WheelBusinessUITests/testMonthsIssueEditingAndArchiveReadonly |
| 开发阶段共享行回归：非轮盘选项、横划、操作按钮、备注和保留标签页 | XunjuUITests/MiniProgramReviewTests/testChecklistSwipeNoteAndRetainedTabs |
| 开发阶段适配旧用例：朝向其他输入、运营商多选、自定义金额手填 | XunjuUITests/ChecklistFormatTests/testWrappedChoicesOtherAndDynamicCostFormats |
| UI 优先 3：通勤查询回填、文字可读/不与查询重叠、重启保留、归档地图只读 | XunjuUITests/UtilityBusinessTests/testRealGuidePlaceWorkplaceAndCommutePersistAfterRelaunch |

此前新增的 3 个组件 UI 已在组件阶段执行，`f87c903` / `xunju-wheel-components-20261022-07` 通过；此次组件、主题、宿主、策略及组件用例未改，正式页面以新的 2 个方法取证。17 个字段逐个选择仍属组件阶段证据，不能改称本轮逐项正式页面操作。真机滚动、中文输入法、系统返回手势及真实通勤服务没有在本轮验证。

## 执行与诊断记录

- `37d5c44` / `xunju-wheel-business-20261022-01`：14 UT 中 13 通过，2 UI 中清单/重启方法通过，月份/问题方法在归档菜单前失败。转租 UT 未先允许转租，导致两个受权限控制的字段不可见；测试已补前提。原生录屏显示回到首页后长按进入详情、未出现菜单，不把这部分当作归档通过。
- `708f561` 补齐转租许可及连续 21 天统计断言，在归档前明确等待详情退出和首页就绪，菜单及归档入口也有条件等待。生产代码与 `37d5c44` 相同，仅测试前提/观察变化。原批次有 2 个失败，因此重新提交完整定向 14 UT、2 UI，而非套用单例重跑豁免。
- `xunju-wheel-business-20261022-02` 的首次计划检查误写 phase=final，校验器退出 2、未构建/执行；更正为 `final-pr-head` 并写明 40 位 head 后 `--validate-only` 通过，再进入真实 runner。无额外用例执行。
- `708f561` / `...-02`：14 UT 与清单 UI 通过，另一 UI 保存 6 个月后第二次点击未打开。结果包录屏及 AX 表明按钮位于 (253.5,487.2,108,45)，浮动按钮在 y645 之后，不能归因于遮挡。`3b8db81` / `...-03` 只运行该失败方法，用现有 `--parity-trace` 观察行手势；确认后行仍收起，重复打开、半月、清空及遮罩取消通过，但之后长按未展开操作。完整快照只记录 close，无意外 pan；保留这一失败，不用通过重试掩盖不稳定。
- 下一步只移除整个 NavigationStack 的动态 allowsHitTesting 切换（`ceace05`），保留全屏遮罩及 accessibilityHidden，布局、组件和保存代码不变。依据是 [Apple 命中文档](https://developer.apple.com/documentation/swiftui/view/allowshittesting(_:)) 与 [UIKit 手势桥接文档](https://developer.apple.com/documentation/SwiftUI/UIGestureRecognizerRepresentable) 对两个交互层的区分；[iOS 26 发行说明](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-26-release-notes) 也记录手势优先级调整。它们支持减少全栈交互切换的实验，不证明本项目命中了某个已知系统 bug。`...-04` 重新选择 14 UT、2 UI，覆盖遮罩阻挡、取消、保存后重复打开和后续原生手势。
- `ceace05` / `...-04`：14 UT、清单 UI 通过，重复打开也通过，但月份 UI 的长按仍失败。`a85f828` / `...-05` 加入可观察的 reveal 跟踪后该单例通过，主 agent 认为跟踪可能改变页面时序，未据此关闭缺陷或作为最终通过证据。
- `673de14` / `...-06` 用仅日志的临时探针移除 AX 状态扰动，原生长按仍失败。结果包导出的 app 标准错误日志明确记录：13:17:15.711603 `reveal f113_2`，13:17:15.725950 `tap active=f113_2`，相隔 **14.347 毫秒**。长按展开后，同次交互的点击调用 consumeTap 再次收起，解释了操作按钮消失；不是用延长等待解决。原始日志在 `artifacts/ios-wheel-business-06/gesture-order.log`，对应 `.xcresult` 和完整 diagnostics 保留。
- `2d9afe7` 将行长按从 simultaneousGesture 改为 highPriorityGesture，阻止长按后又执行子点击；[Apple 优先级文档](https://developer.apple.com/documentation/swiftui/view/highprioritygesture(_:including:)) 和 [手势组合文档](https://developer.apple.com/documentation/SwiftUI/Composing-SwiftUI-Gestures) 支持这种互斥意图。临时日志、额外 AX 跟踪及诊断启动参数已全部移除。回归保持真实的 0.6 秒长按，没有增加时长、跳过按钮或改为直接调用 handler；最终 `...-07` 重新计算为 17 UT、3 UI，补共享行横划/按钮/备注验证。
- `...-07` / `2d9afe7`：17 UT、3 UI 同批通过。导出结果后发现共享池分配的是 **iPhone 14 Pro / iOS 18.3.1**（UDID `8F178971-C203-4690-A83B-253046EACBB1`），不能将其标成 iOS 26.5。`...-04` 原始结果也确认该设备为 18.3.1，因此同系统长按回归已有失败→通过；此前 26.5 上的原始失败仍需要对应验证。
- `...-08` 保持相同源码与精确 17 UT、3 UI，使用公开 `--config` 在任务 artifact 中复制实时配置，只将 devicePrefix 筛选为原有 `todo-pool-bicycle-20260717111352`，目标增加 `OS=26.5`。保留相同 poolRoot、3 槽/3 设备/3 UI 上限及共享租约；未修改共享配置、建立私有池、创建设备或抢占其他任务。不同目标系统属于必要补验，不将 18 的结果静默改称 26，也不通过重复执行同一请求凑绿色。
- `...-08` / `2d9afe7` 的完整结果确认 **iPhone 16 / iOS 26.5** 上 17 UT、3 UI 全部通过，两个真实长按分别保持 0.6/1 秒。原始截图 1178×2556；主 agent 逐图检查 13 张正式页面图片，确认其他输入、固定后缀、清空布局、问题页和归档状态，不用组件宿主图冒充业务页面。
- 收尾审查发现两个既有 UI 方法仍使用旧朝向按钮/通勤 TextField。`541a003` 仅适配这两个测试文件，App、共享 JS、资源、项目配置及已验证的三条 UI 方法不变；不留已知失效的回归脚本。`...-09` 使用相同 iOS 26.5 设备，在 **development** 阶段执行 17 UT、5 个精确 UI 方法，覆盖所有本轮新增/适配方法及共享行回归，不套用最终阶段的 3 方法上限。通勤方法使用 `--utility-network-fixture`，只证明页面查询回填、保存与重启，不能证明真实地图后端。
- `...-09` 17 UT、5 UI 全部通过，但主 agent 读原始通勤截图发现“24 分钟”被截成“24…”，未仅凭绿色测试结束工作。`0fcf855` / `...-10-red` 将原有 76 点宽度提取为实际使用的组件常量，新增回归根据同一策略所有分钟标签的真实 UIFont、符号尺寸、间距和内边距计算所需宽度；修复前精确失败于 **76 < 96**，不是编译或环境失败。
- `dbc8876` 保留查询入口，将该分支最小宽度加至 100 点；其他轮盘、弹窗、字体与文案不变。既有通勤 UI 方法增加实际按钮宽度及与查询按钮不重叠断言。`...-11` 重新计算为 **18 UT、5 UI（development）**。最终阶段的 3 条 UI 优先级改为正式清单、月份/问题/只读、通勤可读性，理由是新发现的通勤显示缺陷与最新 diff 直接相关；共享行及其他说明/自定义金额仍在开发批次执行。

原始 iOS 18.3.1 的通过记录保留其 `2d9afe7` 来源，不将其改称最新通勤宽度的验证。最新宽度与查询并排效果以 iOS 26.5 的后续结果为准。小程序对应通勤排版尚无原生截图，未将 App 的裁切观察直接冒称为小程序已复现；后续真实交互优先核对 0/120 分钟与查询并排显示。
- 共享 JS 影响范围 `npm test -- tests/model.test.js tests/inspection-wording.test.js`：23 通过、1 个措辞用例超出默认 5 秒（实测 6.936 秒），没有断言不等。仅诊断该精确用例，`--maxWorkers=1 --testTimeout=20000` 后通过（测试进程实测 real 7.12、user 1.24、sys 0.31 秒）。保留最初超时和单例通过日志；共享负载是根据墙钟/CPU 的推断，不称一次全部通过，也不视作页面性能证据。

计划、命令、源码 SHA、日志、原始 `.xcresult` 和导出附件均在本 worktree 的忽略目录 `artifacts/ios-wheel-business-01/` 至 `artifacts/ios-wheel-business-11/`（修复前为 `10-red`）。使用共享 runner 的实时 3 槽配置；本 worktree 注册的专属构建缓存名含历史 `time-fragment` 前缀，未借用其他任务设备或工作区。

## 最终结果与原图复核

- 冻结的可执行源码为 `dbc887647958bd4821bba5f27009094c1c9f9846`。`xunju-wheel-business-20261022-11` 在 development 阶段执行 **18 UT、5 个精确 UI，共 23 项全部通过**，0 失败、0 跳过。构建 PID 74701、测试 PID 74893；共享 runner 回执的 build/test 和最终退出码均为 0，任务已结束。
- 实际设备为 **iPhone 16 / iOS 26.5（23F77）模拟器**，UDID `5FC4A20B-AF44-4A92-BF91-B0096BEBF1D9`。结果包为 `artifacts/ios-wheel-business-11/result.xcresult`，完整命令、日志、附件、source-head/status 和 summary 在同一目录；不是物理 iPhone 证据。
- `final-plan.json` 确定最终 18 UT、3 UI，优先级依次为正式清单/其他/重启、月份/问题/只读、通勤可读性。公开 runner 的 `--validate-only` 校验通过，记录在 `final-selection-validation.log`。这些方法均复用同一源码、系统、配置、夹具及 11 号原始结果中的通过记录；**没有另跑一批最终测试**。`final-evidence.json` 列出来源和另两条已通过的开发阶段 UI；未改的组件阶段证据保留原 SHA，不计入本轮 23 项。
- 主 agent 检查了最新 16 张 App 原图（1178×2556），确认正式页面的其他输入框、12 层原值、放弃修改提醒、空值/0/重启恢复、6/0.5 个月与固定押金、清空高度、长按操作栏、问题页、金额手填及归档只读。对通勤图另看完整原图，**“24 分钟”完整显示，查询按钮不重叠**；该查询使用受控服务夹具，不证明真实地图接口。
- 两端原图保存在本会话本地交付目录 `wheel-form-review/`，含 16 张 App 与 12 张小程序有效原图、HTML 索引及两个 manifest。原图复制后逐张比较 SHA-256，并校验解码与尺寸；未裁剪、重绘或修改内容。小程序 3 张仅背景的帧已排除，完整边界见 `docs/wechat/WHEEL_INPUTS.md` 所在的小程序分支。
- 小程序已验证实际组件渲染及 59 项定向测试/官方编译；本轮两次原生交互请求因工具池无空闲槽位，回调未开始，**点击、滚动与保存的原生回归仍未验收**。未抢占其他任务。小程序通勤 0/120 分钟及查询并排效果也待原生核对，不能从 App 截图推断通过。

主 agent 已复查 PR #48 的最终业务 diff、共享字段策略与模型、屏幕根弹窗/身份保护、只确定写入、备注/其他说明保留、归档限制、共享行手势及测试选择。没有发现尚未处理的 App 代码问题；远程 commit statuses 为空，不称 CI 通过。共享行非轮盘交互及其他/自定义金额两条风险已在同头开发批次验证；折叠逻辑有 UT，本轮未另跑折叠 UI。真机、系统返回手势、中文输入法和真实通勤网络不在证据范围内。

绿色结果后只修改这份记录与组件审批记录，均为 Markdown；不改变源码、测试、脚本、资源、依赖或生成输入。文档提交后检查 `dbc8876..HEAD` 只含这两个文件，以同头测试作执行等价证据。分支基于 `codex/ios-parity-20261019`（4cabe5f），仍为独立 Draft PR #48；未合并、真机部署或发布。

## 用户批准合入与基线整合

用户收到本轮小程序手机预览码后明确回复“没问题，合入吧”，授权完成两端本次轮盘 PR 合入。App PR 保持原生开发分支目标，不连带合入其仍待独立验收的上游功能到 main。

首次整合原生基线 `8643bda` 时，共享 updateAnswer 同时保留楼层 -1 和顶楼答案变化时重置自身问题覆盖；Debug 路由保留 wheels、top-floor、corridor，生成包从规范源重建。冻结 `66031687c843b421927905b429d659cc06e12fe6` 后，`xunju-wheel-business-20261022-12-merge` 在 **final-pr-head** 阶段执行 22 UT、3 个精确 UI，共 **25 项通过，0 失败/跳过**。新增影响选择为 TopFloorTests 的 3 个方法及 ComponentLogicTests/testReviewHostRequiresExplicitKnownSurface；原 18 UT 及 UI 前三优先级不变。共享 JS 的 model、inspection-wording、top-floor 三文件 38 项通过。

12 号批次设备仍为 iPhone 16 / iOS 26.5（23F77），原 UDID；结果包、原始截图、完整日志和选择映射位于 `artifacts/ios-wheel-business-12-merge/`。构建 PID 87398、测试 PID 88117；runner receipt 构建/测试和最终退出均为 0，租约已释放。主 agent 从新结果导出原图，复核其他输入框、固定 6 个月/押金及完整 24 分钟与查询并排显示。

合入前最后核对发现基线在执行期间再次前进到 `840d529`（已合入的 #50 自动异常判定）。模拟合并仅生成 XunjuCore.js 发生真实冲突，原模型和 source-model 可自动合并。12 号记录保留其原基线来源，不作为后续组合包的最终证据；按最新影响重新生成 bundle 并选择验证，不能静默复用为新提交通过。公开文档移除本机绝对路径，完整本机路径仅留忽略目录中的原始证据。
