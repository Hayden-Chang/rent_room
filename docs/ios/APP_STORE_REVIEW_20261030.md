# App Store 评价入口组件验收

状态：`REVIEW_READY`。入口组件已实现并通过定向验证；尚未取得用户 UI 批准、真实 App Store ID，尚未接入 `SettingsPage`，不能合并或称为功能交付完成。

## 实现与边界

- 文案：在 App Store 中评价。沿用设置项的 14 pt 字体、50 pt 最小行高、右箭头与分隔线。
- `AppStoreReview.url(appID:)` 只接受不以零开头的 ASCII 数字 ID，生成不固定商店地区的 `https://apps.apple.com/app/id<ID>?action=write-review`。
- 使用 SwiftUI `openURL`；缺少有效 ID 或系统拒绝打开时显示“无法打开 App Store / 暂时无法打开评价页面，请稍后重试。”，可关闭后重试。
- 链接格式依据 [Apple 请求 App Store 评价文档](https://developer.apple.com/documentation/storekit/requesting-app-store-reviews)。系统接受 URL 不代表商店页面加载或评价提交成功。
- DEBUG 评审入口 `--component-review app-store-review` 使用合成 ID `1234567890`，拦截所有 URL 打开操作。画面中的 URL 和次数仅为测试观察。评审 host 和路由均受 `#if DEBUG` 隔离。
- 不修改房源、账号或备份数据；本次没有真机安装、上传构建、提审或发布。

## Apple 后台实际阻碍

2026-10-30 通过现有 App Store Connect 账号查询 `com.keeline.xunju.ios`，没有应用记录；完整应用列表也没有看房搭子/寻居。用户随后明确授权创建应用。

已在已登录浏览器中准备新建表单：iOS、看房搭子、简体中文、SKU `com.keeline.xunju.ios`。正式 Bundle ID 不在可选列表中，不能使用现有的 `.dev.iosparity20261019` 开发副本身份代替。

`asc bundle-ids list --identifier com.keeline.xunju.ios --output json --fields name,identifier,platform` 返回 `PLA Update available`，明确要求账号持有人接受新版 Program License Agreement。网页也显示同一提示。未执行创建提交，未代用户接受法律协议。

下一步由用户处理该协议后重新读取 Bundle ID 状态，必要时注册正式 ID，完成 App 创建并通过 API 核对 Apple ID；公开评价页面要等 App 上架后才能实测。

## 验证证据

- 代码证据 SHA：`05084214406a0fbab47617ea538a0e010b602aac`。
- worktree：`/Volumes/mac2/projects/git_repo/run_self/rent_room/.worktrees/ios-app-store-review-20261030`。
- scheme / targets：`Xunju` / `XunjuTests` / `XunjuUITests`；XcodeGen `2.45.4` 确定性检查通过。未改 `project.yml`，未跟踪或提交生成工程。
- runner：`/Volumes/mac2/projects/git_repo/run_self/Simulator Management/bin/sim-test-run.mjs`；配置 `config/runner.json`，池 `/tmp/todo-ios-sim-pool`。
- session：`01a1887c-6046-70f1-ba46-96184ed84449`。
- run `rent-room-app-store-review-20261030-02`，runner PID `68969`，退出码 0。设备 `5FC4A20B-AF44-4A92-BF91-B0096BEBF1D9` / iPhone 16 / iOS 26.5 (23F77)，截图 1178 × 2556。执行槽和设备租约已释放。
- runner 实际选择的缓存 `/Volumes/mac2/codex-builds/time-fragment-dd-shared-447ba101091c0de61b22f3e8-simulator` 按本 worktree 绝对路径及构建参数生成 key，并受租约保护；名称前缀是共享基础设施的历史命名，并非另一个项目的缓存。
- `.xcresult`：`/private/tmp/rent-room-app-store-review-20261030-02/review.xcresult`；构建结果 `review.build.xcresult` 同目录。
- 日志、计划、可重复命令、runner receipt 和原始导出截图：本 worktree `artifacts/app-store-review-20261030/`。执行命令：`zsh artifacts/app-store-review-20261030/run-02.sh`；其中仅给测试进程设置 `GIT_CONFIG_GLOBAL=/dev/null`，避免全局 HTTPS→SSH 改写。
- 结果：3 UT + 3 UI = 6 passed，0 failed，0 skipped；没有运行全量测试。

| 边界 | 精确 selector |
| --- | --- |
| 正确商店域名、应用路径、write-review 参数，无固定地区 | `XunjuTests/AppStoreReviewTests/testReviewURLTargetsWritingReviewWithoutPinningStorefront` |
| 缺失、非数字、前导零及 URL 注入 ID 拒绝 | `XunjuTests/AppStoreReviewTests/testMissingOrInvalidAppIDCannotOpenAnUnrelatedDestination` |
| DEBUG 评审路由必须显式选择 | `XunjuTests/ComponentLogicTests/testReviewHostRequiresExplicitKnownSurface` |
| 真实点击入口、两次发出评价 URL | `XunjuUITests/AppStoreReviewUITests/testReviewRowOpensWriteReviewURLOnEveryTap` |
| 系统拒绝后的提示、关闭、再次点击 | `XunjuUITests/AppStoreReviewUITests/testOpenFailureShowsDismissibleErrorAndAllowsRetry` |
| 缺少 App ID 时提示且不调用 URL opener | `XunjuUITests/AppStoreReviewUITests/testMissingAppIDShowsErrorWithoutOpeningURL` |

UI 选择覆盖独立的成功、系统拒绝和配置缺失边界，精确 3 个方法。尚未接入设置页，因此现有业务页测试不受影响；集成时重新计算影响范围和最终门禁。

首次 run `rent-room-app-store-review-20261030-01` 因本机 Git 把 GitHub HTTPS 地址改写为不可认证的 SSH，ZIPFoundation 解析失败，退出 74，未执行测试。保留 `test.log`、`runner-receipt-01.json` 和 `/private/tmp/rent-room-app-store-review-20261030-01/review.build.xcresult`。第二次仅修复该进程环境，源码未变。

`xcresulttool` 初次导出因系统 TestReport 缓存写权限失败；提升该导出命令权限后成功，没有重跑测试或改写结果。

## 主 agent 审查

PR #88 创建后单独读取远程 diff，并核对范围、最终代码 SHA 和全部定向测试。组件范围内没有发现待修复问题；GitHub 未返回 status checks 或 PR workflow runs，不将空结果称为 CI 通过。

四张原始截图均已检查：入口文案完整、箭头对齐、分隔线正常；两种失败均显示可关闭提示；成功截图记录两次相同评价 URL。截图和请求拦截证明组件行为，不证明真实 App Store 跳转、商店可用性或评价提交。无真实设备或额外尺寸验证。

本记录是测试后的纯文档补充，不改变已验证源码、测试、配置或测试选择。合并仍等待 UI 明确批准、真实应用身份接入、设置页集成证据和用户合并授权。
