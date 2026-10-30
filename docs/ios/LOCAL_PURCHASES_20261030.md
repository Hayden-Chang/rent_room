# iOS 18 本地支付与容量（2026-10-30）

用户确认：最低 iOS 18，支付验证、容量规则和已购容量不再依赖自有服务端。实现基于免登录改动 2696c0f，并整合 main b5a3b4d，保留已批准的设置/容量页面和 App Store 评价入口。PR #92 中的服务端购买方案在此被替换；model_server #98 不再是该 iOS 版本的支付上线前置条件。

## 规则与 Apple 配置

- 最低版本由 `ios/project.yml` 设置为 18.0，保留 `SKIncludeConsumableInAppPurchaseHistory = true`。XcodeGen 为工程真源，不提交生成工程。
- 实时核实原公开 v2 目录返回 `freeLimit = 2`，本机固定 `CapacityPolicy.initial.freeLimit = 2`；旧服务端策略缓存不再影响额度。保留已购包数迁移，不增加月费或无限房源方案。
- 商品 `com.keeline.xunju.ios.capacity10`，每包永久增加 10 套，可重复购买；归档释放占用，恢复需可用容量，退款超额仍保留房源、答案和媒体。
- App Store Connect App ID 6828695680，消耗型商品 ID 6828697996。先前已配置美国 $1.99、中国大陆 ¥9.90、其他地区 Apple 自动换算；本次未改变价格。界面读取 `Product.displayPrice`，没有硬编码正式售价。

## 本机处理边界

`NativeStorefront` 只向购买控制器返回 StoreKit `.verified` 交易。`AppTransaction` 验证应用归属，`appTransactionID`、Bundle ID 和环境派生本机购买身份；不需要 App 账号、设备随机账号、后台密钥或 HTTP 验证接口。旧交易没有 `appAccountToken` 仍能恢复。

容量页读取完整 `Transaction.all`，iOS 18 的 opt-in 包含已 finish 的消耗型交易。主动恢复另调用 `AppStore.sync()` 与 AppTransaction 刷新。订单按 ID 去重，计入购买数量，排除撤销交易；比较签名时间，旧更新不能覆盖较新的退款。完整历史与观察器并发时保留枚举开始后发生的新订单，较新退款仍优先。任一历史验证失败不接受部分结果。

`storekit-purchases.json` 和 `purchase-capacity.json` 在本机根目录原子保存，不放入房源 ZIP。账本和容量缓存成功落盘后才 finish；中途失败保留订单供后续恢复。重启优先从账本重建容量；仍可读取旧购买包数缓存和原有账号目录，房源目录不会随 Apple 购买身份切换。

普通启动使用上次本机容量，不触发购买服务或策略联网。打开容量页、购买和恢复仍与 Apple 通信，离线不能立即获知其他设备购买或退款。退款/切换账号只改变可新增额度，已有房源不删除。地图、测速和用户主动反馈不属于购买或额度请求，保持原行为。

已删除 `CapacityAPI`、`CapacityPolicyAPI` 及其 HTTP 契约测试，以本地账本和恢复回归替代。App 隐私清单移除自有服务收集的购买历史/UserID，保留支持反馈、主动位置功能及 required-reason API 声明。公开隐私页第 4 节仍概括 Apple 购买、交易标识和本机缓存；发布前应明确本机验证方式并复核 ASC 隐私标签。

## 验证记录

所有业务测试均使用隔离目录；StoreKit 响应注入只证明业务处理，不代表真实 Apple 扣款。原生 StoreKitTest SDK 用例单独计数，不隐藏历史环境问题。

第一批 `rentvisit-local-billing-20261030-01` 在 422c381 进入共享 runner 后，构建前置检查因新 worktree 尚未安装 esbuild 退出 1，没有执行测试。保留原日志和 receipt。随后使用 Node.js 24.19.0，按锁文件 npm ci 安装依赖；没有安装或更新全局运行时。

第二批 `rentvisit-local-billing-20261030-02`：源码 c5576c7，构建依赖 ZIPFoundation 被本机 Git 全局 HTTPS→SSH 重写阻断，退出 74，没有执行测试。第三批 03 使用仅当前命令生效的 `GIT_CONFIG_GLOBAL=/dev/null`；在排队期间核实正式免费额度为 2 套后，主动 SIGTERM 取消，不计作测试失败或通过。

第四批 `rentvisit-local-billing-20261030-04`：源码 `95bfdef9ab237a4b0bca9695d4ff95999df99f2a`，**28 条精确单测 + 4 条修改过的页面测试全部通过，0 失败、0 跳过，runner 退出 0**。设备为 iPhone 14 Pro / iOS 18.3.1（22D8075），UDID `8F178971-C203-4690-A83B-253046EACBB1`。通过共享 runner 获取隔离资源；完成后无该 run ID 的活动租约或排队记录。

- 结果：`/Volumes/mac2/codex-builds/rentvisit-local-billing-20261030-04.xcresult`。
- 计划、完整命令和日志：`/private/tmp/rentvisit-local-billing/plan-04.json`、`run-04.sh`、`run-04.log`。
- 持久截图、来源/哈希、摘要、脱敏 receipt、计划和最终等价性记录：`/Users/pc/.codex/visualizations/2026/10/29/01a1887e-9289-7bd0-87dd-af12ef212465/local-storekit-20261030/`。
- Node.js 24.19.0；XcodeGen 2.45.4 两次生成结果一致，生成工程未纳入 Git。
- `NativeStorefrontTests` 实际调用 StoreKitTest SDK，重复购买、显式 finish 后消耗品仍可从历史读取均通过；构建产物中的最低 iOS 18 和 finished-consumable opt-in 也已断言。

影响映射：Billing/账本对应 CapacityBusinessTests（9）、PurchaseLedgerTests（4）、AppReviewTests（7）和 NativeStorefrontTests（2）；本地策略对应 CapacityPolicyTests（2）；免登录目录与离线迁移对应 OfflineWorkspaceTests（3）；隐私清单对应 LegalResourcesTests（1）。精确方法见计划，未执行全套测试。

最终定向验证选择以上 28 条单测，以及以下 3 条 UI 方法，按支付正确性、数据保全、创建流程排序：

1. `CapacityBusinessUITests/testPendingPurchaseDoesNotGrantAndRestoresOnceAcrossProcessRelaunch`：未批准不发放，恢复和重启不重复增加。
2. `CapacityBusinessUITests/testCancellationRefundAndUnavailableProductPreserveOverCapacityHouses`：取消、退款和不可售状态保留已有房源。
3. `CapacityBusinessUITests/testConfirmedRestoreContinuesInterruptedCreateWithoutAutoCreatingHouse`：免费 2 套用满后，扩容返回第 3 套创建流程，不自动创建。

开发批次额外通过 `OfflineBusinessUITests/testLocalRecordSurvivesRelaunchAndSettingsOffersLegalPagesWithoutLogin`，验证离线记录、地址、无登录设置与法律入口。全部 4 条本次修改的 UI 用例都已执行。最终仅增加本文及旧文档的历史标注，审查 `95bfdef..最终 HEAD` 确认只有文档差异后复用同批测试；源码、测试、资源、工程输入、依赖和执行环境未变，所选测试均包含在已通过的批次中，无需重复运行。精确两个 SHA 和检查结果保存在上述目录的 `final-evidence.json`。

11 张原始截图逐张检查，尺寸 1178 × 2556。恢复后 0/12、退款后 3/2、不可售禁用按钮、第 3 套创建和既有设置页面符合测试状态。页面中的 ¥9.90 为受控响应，正式价格仍读 Apple。`offline-business-app-store-review.png` 是返回设置后的上半页，评价入口的可见证据为 `offline-business-legal.png`。未将这些截图扩展为全语言、iPad 或真实沙盒验证。

主 agent 已审查本次账本、控制器、身份隔离、恢复、退款与数据迁移差异，并修复历史并发中的新退款覆盖风险、身份失效后旧请求恢复状态风险、旧退款清除待批准状态风险。定向测试后未发现本次范围内待修问题；Billing 和 AppWorkspace 静态扫描无购买 HTTP 客户端或远程策略调用。此记录不宣称继承自 PR #92 的所有无关功能已完成全量回归。

## 发布边界

没有合并、部署、真机安装、上传或提交审核。App Store 真正的沙盒购买、重装后恢复及退款仍需上线前验证；本地夹具或 StoreKitTest 不能替代该证据。ASC 内购仍需补审核资料并随首版提交。此版本不要求部署购买后端、配置 Server Notifications 或提供 App Store Server API 密钥。

Apple 依据：[WWDC24 StoreKit updates](https://developer.apple.com/videos/play/wwdc2024/10061/)、[Transaction.all](https://developer.apple.com/documentation/storekit/transaction/all)、[WWDC25 appTransactionID](https://developer.apple.com/videos/play/wwdc2025/241/)。
