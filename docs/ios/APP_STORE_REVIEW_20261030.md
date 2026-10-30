# 设置页 App Store 评价入口验收

状态：`INTEGRATED_VALIDATING`。用户已明确回复“确认通过”，批准入口与打开失败提示。正式 App ID 已核实并接入“我的”页“使用反馈”下方；等待集成验证结果。PR #88 尚未合并。

## 实现与应用身份

- App Store Connect：`6828695680`，`RentVisit: Viewing Checklist`，Bundle ID / SKU 均为 `com.keeline.xunju.ios`，主语言 `en-US`。2026-10-30 使用 `asc apps view --id 6828695680 --output json` 逐项回读确认。
- 实际评价链接：`https://apps.apple.com/app/id6828695680?action=write-review`。遵循 [Apple 请求 App Store 评价文档](https://developer.apple.com/documentation/storekit/requesting-app-store-reviews)，不固定用户商店地区。
- 入口文案为“在 App Store 中评价”，沿用现有设置项的 14 pt 字体、50 pt 最小行高、右箭头与分隔线。
- 通过 SwiftUI `openURL` 每次点击直接请求评价页面。缺少有效 ID 或系统拒绝打开时显示“无法打开 App Store / 暂时无法打开评价页面，请稍后重试。”，可关闭后重试。
- `AppStoreReview.url(appID:)` 仅接受非零开头的 ASCII 数字，避免无效配置生成其他 URL。
- DEBUG `--review-settings` 只在合法 UUID 的 `--business-test` 同时存在时启用：运行实际 `AppRoot`，从“我的”Tab 进入实际设置页，使用独立业务数据目录并拦截外部打开。正式运行的 `openURL` 环境不变；Release 不含该入口。
- DEBUG 隔离组件 `--component-review app-store-review` 继续用于缺少 ID 的边界测试；合成 ID `1234567890` 只存在于该 host，所有打开操作被拦截，不会用于正式设置项。

## 验证计划与影响映射

候选源码 SHA：`04e87db333e96d6b41b796c493e3de9b23d698f2`。仅影响评价组件、设置项集成及 DEBUG 验证路由，无业务模型、存储、依赖或工程配置变化。

| 层次与风险 | 精确 selector |
| --- | --- |
| UT：真实 App ID、HTTPS 商店域名、write-review 参数及不固定地区 | `XunjuTests/AppStoreReviewTests/testReviewURLTargetsWritingReviewWithoutPinningStorefront` |
| UT：缺失、非法字符、前导零及 URL 注入 ID 拒绝 | `XunjuTests/AppStoreReviewTests/testMissingOrInvalidAppIDCannotOpenAnUnrelatedDestination` |
| UT：新增 DEBUG 组件路由及原有显式路由解析 | `XunjuTests/ComponentLogicTests/testReviewHostRequiresExplicitKnownSurface` |
| UI 优先级 1：真实“我的”页面入口可达，反馈与分享入口保留，两次点击均发送正式评价链接 | `XunjuUITests/AppStoreReviewUITests/testReviewRowOpensWriteReviewURLOnEveryTap` |
| UI 优先级 2：真实设置页打开被拒绝后提示、关闭及重试 | `XunjuUITests/AppStoreReviewUITests/testOpenFailureShowsDismissibleErrorAndAllowsRetry` |
| UI 优先级 3：隔离组件缺失 ID 时提示且不请求外部 URL | `XunjuUITests/AppStoreReviewUITests/testMissingAppIDShowsErrorWithoutOpeningURL` |

3 个 UT 覆盖全部新增/修改单测。3 个 UI 方法为本 PR 全部新增用例，分别覆盖成功、系统拒绝、配置缺失三个独立风险；没有选择整个类或全量 UI suite。开发与最终候选的测试集合一致；若源码、测试、环境和选择不变，最终门禁复用同一 SHA 的结果，无需重复运行。

## 集成验证证据

- worktree：`/Volumes/mac2/projects/git_repo/run_self/rent_room/.worktrees/ios-app-store-review-20261030`。
- scheme / targets：`Xunju` / `XunjuTests` / `XunjuUITests`；XcodeGen `2.45.4`，未修改 `project.yml`，未提交生成工程。
- runner：`/Volumes/mac2/projects/git_repo/run_self/Simulator Management/bin/sim-test-run.mjs`；实时配置 `config/runner.json`，池 `/tmp/todo-ios-sim-pool`，最多 3 构建槽，最终最多 3 个 UI 方法。
- session：`01a1887c-6046-70f1-ba46-96184ed84449`。
- run：`rent-room-app-store-review-20261030-04`（重新冻结工作区后的完整选择）。
- runner 缓存：`/Volumes/mac2/codex-builds/time-fragment-dd-shared-447ba101091c0de61b22f3e8-simulator`。key 来自本 worktree 绝对路径及构建参数，受租约保护；名称前缀仅为共享基础设施历史命名。
- `.xcresult`：`/private/tmp/rent-room-app-store-review-20261030-04/review.xcresult`；构建结果 `review.build.xcresult` 同目录。
- 命令：`zsh artifacts/app-store-review-20261030/validate-04.sh` 然后 `zsh artifacts/app-store-review-20261030/run-04.sh`。完整命令、精确选择器、计划和日志在本 worktree `artifacts/app-store-review-20261030/`。
- 执行状态：等待结果。当前没有宣称集成测试通过。

## 主 agent 审查与验收边界

在更新 PR 后，主 agent 单独读取远程最终 diff，核对应用身份、路由、DEBUG 隔离、设置页位置与失败处理，未发现待修复的产品问题。GitHub 未返回 status checks 或 PR workflow runs，空结果不作为 CI 通过证据。当前远程 base 为 `eb75079b3e46726e5742cc4c861dc7a278d9dd31`，与任务起点一致。

UI 批准已获得，不重复要求相同组件批准。点击测试中的 URL opener 被截获，证明真实设置页发出的目的地址与失败处理，不证明 App Store 已加载评价界面或评价提交成功。新 App 尚需上架后验证公开商店页面；没有进行真机安装、上传、提审、发布或合并。

## 历史记录

- 初次组件源码 `05084214406a0fbab47617ea538a0e010b602aac`，run `rent-room-app-store-review-20261030-02`：3 UT + 3 UI 全通过，iPhone 16 / iOS 26.5，截图 1178 × 2556；证据为 `/private/tmp/rent-room-app-store-review-20261030-02/review.xcresult` 及 worktree 的 `artifacts/app-store-review-20261030/attachments/`。这批结果不替代正式设置页集成验证。
- run 01 因全局 Git HTTPS→SSH 改写导致 ZIPFoundation 下载失败，退出 74，未进入测试。run 02 仅对测试进程设置 `GIT_CONFIG_GLOBAL=/dev/null` 后成功；本次保留同一环境措施，没有修改全局 Git 配置。
- 创建过程曾受新版开发者协议限制，用户已接受；后续表单加载和点击超时，已保留失败记录并交用户完成创建。用户最后提供 `6828695680`，API 回读确认成功，没有重复创建或使用开发测试版 Bundle ID。

- 集成 run 03 构建通过，但主 agent 在模拟器排队期间更新了本验收文档，runner 检测到工作区 diff 变化，退出 2 并拒绝启动测试。未执行任何测试，不算单个测试失败。已保存文档后冻结全部工作区改动，run 04 重跑同一源码与同一 6 项选择；保留 `test-03.log`、receipt 和 `review.build.xcresult`。
