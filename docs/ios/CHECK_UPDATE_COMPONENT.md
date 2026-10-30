# 设置中的手动检查更新

本阶段为独立 SwiftUI 组件评审。入口是 Debug 显式参数 `--component-review app-update`，Release 不编译评审宿主。尚未替换完整设置页中的版本行、发起商店查询或增加自动检查。

## 评审范围

- 按用户标注合并为单行白色圆角卡片：左侧“版本”与安装包版本相邻，右侧“检查更新”；删除独立更新行和分隔线。
- 版本读取 `CFBundleShortVersionString`；缺失时显示“未知版本”，不使用 build number 或虚构的默认版本。
- 检查中显示进度并禁止重复点击；结果区分最新版本、新版、商店无结果、网络失败、系统要求和商店信息不可用。
- 新版系统弹窗提供“去更新”和“稍后”；稍后关闭弹窗且不触发跳转，原行右侧切换为“去更新”，再次点击直接调用商店跳转，不重复发起检查。打开商店失败在同一行提示并允许重新检查。
- 组件只处理呈现与回调，宿主以显式按钮交付测试响应，便于稳定捕获检查中。此等待由测试控制，不表示真实请求耗时。商店跳转回调在宿主中返回失败，不打开任意测试 App。

## 验证映射

| 变更边界 | 精确选择器 | 类型 / 原因 |
| --- | --- | --- |
| 安装包版本 | `XunjuTests/AppUpdateComponentTests/testDisplayedVersionUsesInstalledMarketingVersionInsteadOfBuildNumber` | 新增；独立 Bundle 验证 marketing version 与 build number 不混用 |
| 版本缺失 | `XunjuTests/AppUpdateComponentTests/testMissingOrBlankVersionDoesNotInventAReleaseNumber` | 新增；缺失、仅 build number、空白值 |
| 评审入口 | `XunjuTests/AppUpdateComponentTests/testUpdateReviewRequiresExplicitRoute` | 新增；普通启动或不完整参数不进入评审 |
| 既有评审路由 | `XunjuTests/ComponentLogicTests/testReviewHostRequiresExplicitKnownSurface` | 受影响既有；新增路由不改变原解析契约 |
| 检查中、新版、稍后、跳转回调与失败 | `XunjuUITests/AppUpdateComponentUITests/testCheckingNewVersionLaterAndStoreHandoffFailure` | 新增；最高风险，真实点击与系统弹窗；附件 01–05 |
| 最新、无结果、失败与重试 | `XunjuUITests/AppUpdateComponentUITests/testCurrentUnavailableAndNetworkFailureCanRetry` | 新增；错误结果不能误报最新；附件 06–08 |
| 系统要求、商店不可用 | `XunjuUITests/AppUpdateComponentUITests/testSystemRequirementAndMissingStorefrontDoNotOfferUpdate` | 新增；不提示不可执行的更新；附件 09–10 |

最终候选复用同一映射，4 项定向单测和 3 项 UI，未运行全量测试。

### 单行修订验证

用户确认的修订范围为：版本号紧跟“版本”，检查或更新按钮在同行右侧，移除第二行和分隔线。新增同一水平线与左侧间距断言，并验证“稍后”后直接点右侧“去更新”只触发商店回调、不重复检查；原有系统弹窗更新按钮仍验证真实点击。

3 项 UI 用例均受新布局影响，重新执行并导出 10 个状态。版本读取与路由相关的 4 项 UT 复用 `7d502ef` 的成功结果：已检查至本次源代码提交 `02f10ae` 的差异，相关函数、路由、单测、依赖和构建配置未变。

`-07` 在队列等待期间因本文档发生修改而被运行器的工作区快照保护终止，未构建、未执行测试；保留原日志与退出码 2 的收据。先提交文档并冻结工作区，再用新的 run ID 执行同一组测试。

### 首版双行布局验证（已被单行设计替代）

- 首版状态：用户提出排版修改，双行布局不再用于当前视觉验收。
- 证据提交：`7d502ef1af77ecfd2370167893a83408401c1339`。
- 批次：`rent-room-check-update-20261030-06`；构建通过，7 项测试通过（4 UT / 3 UI），0 失败、0 跳过。
- 设备：iPhone 14 Pro，iOS Simulator 18.3.1，arm64；截图 1178 × 2556 px，逻辑视口 393 × 852 pt。
- 结果包：`/Volumes/mac2/codex-builds/rent-room-check-update-20261030-06.xcresult`。
- 日志和收据：`/Volumes/mac2/projects/git_repo/run_self/rent_room/outputs/ios-check-update-20261030/development-06.log`、同目录 `receipt-06.json`、`summary-06.json`。
- 原始附件：同目录 `attachments-06/`；10 张按状态命名的无修改截图在 `screenshots/`，文件与来源哈希在 `screenshots.json`；用户评审图集为 `REVIEW.md`。
- 已逐张查看 10 张附件：版本行和更新行对齐，状态文案未截断，新版弹窗使用系统按钮，检查中禁用入口；稍后、更新回调、失败后重试均有实际 UI 点击断言。
- 此批截图只记录首版双行布局；单行修订改变视觉和按钮交互，必须使用新 UI 证据。版本读取与路由相关的 4 项 UT 可复用，相关源代码、测试及构建配置均未修改。
- 当前只在本地 `codex/ios-check-update` 分支。自动审批拒绝向 `Hayden-Chang/rent_room` 推送，等待用户对该仓库和分支的明确推送授权，尚未创建 PR。

### 开发失败与修正

首个有效测试批次 `rent-room-check-update-20261030-04` 在提交 `1f04717151abf169847e8c6a898eef517ef594f1` 上完成：4 UT 通过，3 UI 均在入口断言失败。导出的无障碍层级显示 `settings.checkUpdate` 位于 `Other` 容器，其内部真实 `Button` 无该标识；录屏确认卡片已实际呈现。移除 Button 上多余的 `.accessibilityElement(children: .ignore)`，让标签、值与标识直接属于原生按钮；保留原测试选择器与真实点击断言，重跑同一组用例。

此前 `-02` 在依赖准备阶段因缺少 esbuild 停止；按 lockfile 安装后，`-03` 被全局 Git HTTPS→SSH 改写阻塞，于依赖下载阶段主动终止。`-04` 仅通过进程环境覆盖下载协议，未改变全局配置。上述准备失败不计为业务测试。

`-05` 在修复后的提交上构建通过，但共享模拟器运行器枚举设备失败，尚未进入测试。只读复查设备枚举恢复后，`-06` 使用相同选择器全部通过；`-05` 日志、收据与构建结果保留，不计为业务测试失败。

## 接入前置条件

用户确认组件效果后，将卡片接到 `SettingsPage`，接入 Apple Lookup、数字分段版本比较、当前 storefront 和系统兼容性判断。只做手动检查，不引入 time_fragment 的自动检查及提醒冷却。

当前主线 Bundle ID 为 `com.keeline.xunju.ios`。2026-10-30 使用现有 App Store Connect 凭据按此 ID 查询无匹配记录；此结果不能证明其他账号没有该 App。正式 App ID 和 Bundle ID 需核对后用于商店查询和跳转，不能沿用 time_fragment 的标识。当前组件证据不能证明真实商店查询、地区可用性、上架版本或商店打开成功。
