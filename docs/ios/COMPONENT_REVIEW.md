> 用户已明确批准本批：“确认通过，继续完整业务开发”。状态：APPROVED。后续完整业务验收另行记录。

# 首批原生组件验收证据

2026-10-19，首批状态 `APPROVED`，用户已明确确认。对应 [Draft PR #39](https://github.com/Hayden-Chang/rent_room/pull/39)。这是第一批组件的证据，不是完整 iOS 应用的交付或发布证明。

## 源码与环境

- 小程序基准：远程 main `6a07ecd97fe639e594a8cc5690196921cbe5574e`，Connector 与 Git 传输均实时核实。
- 证据源码：`e70ce5062b1db70b9d8469ba3aa6ed95f40afbf2`；任务分支 `codex/ios-parity-20261019`。
- worktree：`/Volumes/mac2/projects/git_repo/run_self/rent_room/.worktrees/ios-parity-20261019`；主检出的既有改动未动。
- Xcode 26.6（17F113）、Swift 6、固定 XcodeGen 2.45.4；项目生成两次哈希相同，生成 `.xcodeproj` 未跟踪。
- 实际设备：iPhone 16 / iOS Simulator 26.5（23F77），UDID `5FC4A20B-AF44-4A92-BF91-B0096BEBF1D9`；截图1178×2556。
- runner 配置：`/Volumes/mac2/projects/git_repo/run_self/Simulator Management/config/runner.json`，本轮run ID `xunju-ios-components-20261019-06`，Session `01a153f1-2c5b-7130-9ac8-1717a9eabf0c`。
- 构建命令 PID 47821，测试命令 PID 47938。退出码0，完成后本 run 的队列、slot 和设备lease均已释放。
- 实际 DerivedData：`/Volumes/mac2/codex-builds/time-fragment-dd-shared-57d1cd671f68343408c29f9f-simulator`。这是共享 runner 自动生成的名称；已核对注册表的 canonical workspace 唯一对应本 worktree，未借用其他项目缓存。

## 测试及交互结果

权威 `.xcresult` 摘要：9通过，0失败，0跳过；其中6项定向单测、3项精确XCUITest。按 [PARITY.md](PARITY.md) 的确定性边界映射执行，无未过滤的旧全套测试。

| 顺序 | XCUITest 方法 | 实际建立的证据 |
| --- | --- | --- |
| 1 | `testLoginEntriesAndPhoneFailureKeepsInput` | 三种登录入口存在；手机号表单原生点击/输入；格式不完整时禁用；未接通服务时报错且手机号/验证码保留；未假报发送成功；微信入口回调可达 |
| 2 | `testChecklistDisclosureSelectionAndSwipe` | 初始折叠、真实点击展开、“是/否/没有”文案与原内部值一致、点击选择、折叠再展开保留答案、真实左滑展示三个操作、备注回调可达 |
| 3 | `testHouseCardsAndEmptyState` | 两列卡片、租金/地址/面积/检查/问题显示、点击打开回调、空状态与添加回调 |

6项单测精确方法：`testPhoneRequiresElevenMainlandDigits`、`testCodeRequiresSixASCIIDigits`、`testChoiceCanClearAndSwitchWithoutCouplingProblemFlag`、`testReviewHostRequiresExplicitKnownSurface`、`testParityImagesAreAvailableToNativeViews`、`testParityIconRendersVisiblePixels`，target/class均为 `XunjuTests/ComponentLogicTests`。UI的target/class均为 `XunjuUITests/ComponentReviewTests`。

构建约8秒、测试执行阶段约41秒；测试工具报告UI方法合计31.69秒，其他为测试启动和收尾等，未再推断安装耗时。runner记录缓存等待0.004秒、构建与设备队列合计0.487秒。

## 文件与复现

- 计划、日志和命令副本：本 worktree 的忽略目录 `artifacts/ios-components-20261019-06/`。
- 构建结果：`/Volumes/mac2/codex-builds/xunju-ios-components-20261019-06.build.xcresult`。
- 测试结果：`/Volumes/mac2/codex-builds/xunju-ios-components-20261019-06.xcresult`。
- runner receipt：`/tmp/todo-ios-sim-pool/run-receipts/xunju-ios-components-20261019-06.json`，副本存入上述artifacts。
- 原始附件导出：`/tmp/xunju-ios-20261019/attachments-06/`；未改像素的持久截图副本位于 `/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-review/`。

截图分别为 `01-house-cards.png`、`02-house-empty.png`、`03-checklist-selection.png`、`04-checklist-swipe.png`、`05-login-entries.png`、`06-phone-empty.png`、`07-phone-service-error.png`。均来自本轮XCUITest附件；主 agent 已逐张检查：原图可见、卡片双列、选择态和左滑三个44pt操作、三个登录按钮对齐、表单禁用态及有键盘时的错误布局。导航栏的“空状态/房源卡片”和回调文字仅属于DEBUG评审宿主。

复现应通过共享runner，以 `review-plan-06.json` 与 `run-review.py` 为命令模板，更换唯一run ID及结果路径，不覆盖已有bundle。脚本最终调用仓库 `scripts/run-xcodebuild.sh`，project为 `ios/Xunju.xcodeproj`，scheme为 `Xunju`，仅执行计划中的6项单测和3项UI选择器。

## 失败与修正保留

1. 首轮 `...-01`：4UT通过、2UI通过、1UI失败。失败层级证明父级 `row.*` 标识覆盖按钮标识；添加原生accessibility container后原真实操作测试通过。
2. 图片诊断 `...-02`：UIImage可解码；进一步 `...-03` 的新增像素回归测试在修正前失败，原生图标可见像素为0，日志确认SwiftUI未在asset catalog找到原散装PNG。23个PNG无损迁入 `.xcassets`，与小程序原文件逐个SHA-256一致；同一回归测试修正后通过。
3. `...-04` 仅构建失败：资源编译器默认寻找尚不存在的发行AppIcon；测试未执行。明确此组件宿主暂不指定发行图标后，`...-05` 的6UT/3UI通过。
4. 之后将清单示例换成真实fieldView文案与内部值契约，重新执行 `...-06`，6UT/3UI全部通过。旧失败日志和bundle均保留，未以重跑抹去。

## 主 agent 审查与剩余门禁

PR创建后，主 agent 通过Connector读取实际PR完整patch，再对照本地最终diff、测试映射和7张原图进行独立审查。改动仅涉及新增iOS工程/组件/测试/文档及必要根忽略项和构建包装脚本；小程序业务、清单源、线上服务未修改。DEBUG宿主由显式参数启用并被Release条件编译排除；没有把fixture回调称为登录、保存或购买成功。组件、工程和测试保持在同一PR，使新工程可独立复现；源文件与资源配置使其超过400行建议值。

Connector返回该提交的远程statuses为空，未据此声称远程CI通过。本轮源码验证后只补充本文、PARITY状态文档、SOURCE_PARITY_AUDIT源码审计及根README的iOS入口；如后续HEAD仅包含这四个Markdown文件的非执行性变更，可依据逐文件diff复用证据，不把截图改称来自新SHA。

首批已获批准，允许保持现有外观继续业务集成；后续新增组件单独评审。首批证据不覆盖后续业务。后续业务核心、iOS认证协议与后端见 [BUSINESS_CORE.md](BUSINESS_CORE.md)，普通启动已接入的页面及第三批批准见 [BUSINESS_PAGES.md](BUSINESS_PAGES.md)，地点/通勤/测速/引导的新增独立组件见 [UTILITIES.md](UTILITIES.md)。真实Apple账号授权、短信收发、真实设备相机/GPS/键盘、完整媒体/文件交互、微信SDK及StoreKit等仍需完成或验收，不能发布。UI批准只允许继续集成，合并、真机安装和发布仍单独执行。
