# iOS 公开页面、隐私清单与免登录组件（2026-10-30）

## 当前状态：合入最新本机 StoreKit 与价格主线

用户明确要求把价格和购买方式更新后的主线合入本任务分支。已获取并整合远程 `main` 的 `46f6ff384d1fe549883bcf4cc1ecf3c271087681`，包含本机支付 #100 与语言/币种 #95。支付控制器、身份、账本、策略、设置、隐私清单及冲突测试均采用核实后的主线版本；生产源码、资源、工程配置及脚本与该主线逐文件一致。保留本任务历史证据，以及 App Store 评价 UI 测试的正确选择器和先滚动到 Tab 栏上方的修正。

当前购买契约以 [本机支付说明](LOCAL_PURCHASES_20261030.md) 为准：最低 iOS 18，免费 2 套，每个消耗型商品永久增加 10 套，页面使用 `Product.displayPrice`；Apple 已验证交易在本机账本去重/恢复，落盘后才 finish，不再请求自有购买接口。此前 model_server #98 不再是该 iOS 版本的支付前置条件。语言和币种保留主线实现；本次不改 ASC 商品配置或公开站点。

重新验证计划 `xunju-offline-main-sync-20261030-01`：31 项定向单测（本机支付/账本/策略/离线迁移/清单/原生 StoreKitTest 28 项，加评价链接与 DEBUG 路由 3 项），3 项 UI 按风险选择价格和待确认/重启恢复、退款保留超额房源/不可售、评价入口两次点击。既往服务端方案的通过结果不能证明本机支付，本次不复用它作为支付验证。脚本与计划位于 `/private/tmp/xunju-offline-main-sync-20261030/`。原有公共页面仍在线，后续发布前需复核其购买说明与 App Privacy 标签；真实 Apple 沙盒扣款仍须独立验收。

run-01（`46f5bb5`、iPhone 14 Pro / iOS 18.3.1）30 UT 通过、1 UT 与 3 UI 失败。包内名称已按主线本地化为“寻居”/“Xunju”，旧测试仍断言“看房搭子”；三个 UI 均在首次币种提示未处理时尝试进入设置，截图、层级和完整流程确认未到购买或评价断言。真实 StoreKitTest 的购买、finish 前后历史及重复购买已通过。保留原始失败结果，测试维护只改包内中英文名称校验、真实点击“使用美元”并等待提示消失，重启断言选择仍保留；不改生产代码、支付断言或延长原有业务超时。run-02 在新提交上完整复验同一 31 UT + 3 UI 选择，不复用本次失败批次作为最终通过。

run-02 已在 `5bce3ee4a6ba5bc66f5408eff8d3539e5726b431` 完成：**31 UT + 3 UI 全部通过，0 失败、0 跳过，runner 退出 0**。设备 iPhone 14 Pro / iOS 18.3.1，UDID `8F178971-C203-4690-A83B-253046EACBB1`。评价入口用例 18.647 秒、退款/不可售 41.503 秒、待确认/重启恢复 42.442 秒；本任务租约与执行槽已释放。

证据包括 `/private/tmp/xunju-offline-main-sync-20261030/{plan,run,summary}-02.*`、`/Volumes/mac2/codex-builds/xunju-offline-main-sync-20261030-02.xcresult`，以及 `/Users/pc/.codex/visualizations/2026/10/29/01a18886-1bc3-7922-9396-c73515b59cbf/ios-offline-main-sync/` 的 7 张未修改截图、逐图 SHA256/测试/源码/设备来源、去令牌 runner receipt、整合一致性证明。主 agent 已逐张查看：待确认保持 0/2、确认和重启恢复均为 0/12、退款及不可售保持 3/2；评价行可见并连续请求同一正式 URL 两次。待确认/不可售状态的底部说明与法律链接仍需滚动，评价 URL/次数为 DEBUG 回显。截图 ¥9.90 来自受控 storefront 夹具，SDK 测试使用真实 StoreKitTest；均不证明 Apple Sandbox 扣款或当前商店售价。

主 agent 在推送后另行复核最终差异及证据：相对主线仅剩本历史文档和三个测试文件，生产源码、资源、工程配置、依赖及脚本完全一致；本次没有重新引入旧支付接口或登录流程。31 项定向单测的精确映射保留在 plan-02；UI 只选上述三个最高风险方法，未全量复跑其他使用启动辅助方法的 UI 用例或语言/币种流程。GitHub 对该验证提交返回 0 check-runs、0 commit statuses，不能称远程 CI 通过。后续提交仅补本文档，不改变执行输入。PR #92 继续为草稿，本次授权的主线合入已完成，未合并回 main 或部署。

下方均为此前服务端购买方案的历史记录，保留原始失败、修复与截图来源，不代表当前购买实现。

## 前一版本定向验证结果（历史）

**41 UT + 3 UI 分批通过**。生产源码为 `6c57f510f04db44c25a323042fdff23282a3ab5f`（已整合 main `b5a3b4d`）；复验提交为 `e29e58e951cdd6926ecb0f35c55149d5d3a6f920`。两者差异只有下面记录的一个 UI 方法增加滚动前提与文档，App 源码、资源、依赖、配置及其他测试不变。

| 批次 | 精确结果 | 环境与复用依据 |
| --- | --- | --- |
| run-13 / `6c57f51` | 41 UT 通过；离线记录 UI 175.660 秒、购买恢复 UI 58.439 秒通过；评价 UI 失败，原结果保留 | iPhone 14 Pro / iOS 18.3.1，UDID `8F178971-C203-4690-A83B-253046EACBB1` |
| run-14 / `e29e58e` | 仅复跑评价 UI，30.127 秒通过，0 失败、0 跳过、runner 退出 0 | 同一池设备和系统。按单失败恢复规则与 run-13 通过项合并；未重新运行已通过项 |

41 项单测映射：OfflineWorkspace 5（启动不联网、原目录、身份分离）；BusinessIntegration 4 + IdentityScope 2（既有调用方、迁移、损坏恢复和目录保护）；CapacityBusiness 7 + CapacityAPI 2 + CapacityPolicy 1（交易确认、签名证明、缓存和幂等）；AppReview 7 + TouchTrail 2（保留主线评分及本机偏好）；LegalResources 3（URL、包内清单和显式路由）；UtilityFlow 5（主动查询、手填地点及持久化）；AppStoreReview 2 + ComponentLogic 1（正式评价 URL、非法配置及调试路由）。精确 selector 均在计划文件，不以整个 target 或全量 suite 代替映射。

最终三个 UI 方法为 OfflineBusinessUITests 的记录/设置/地址/法律入口、CapacityBusinessUITests 的待确认/到账/重启去重、AppStoreReviewUITests 的评价入口两次点击。首次定位修复和退款保留超额房源为先前独立证据；主线真实评分窗口展示有 run-08 证据。容量 UI 使用显式 DEBUG 交易/服务夹具，并隔离平台评分窗口，仅证明业务与持久化流程。未验证真实 Apple 付款、实体设备 GPS、飞行模式实机或地图瓦片内容。仅同步选择器的其他历史 UI 长流程未全量重跑，不能据此声称完整 UI 门禁或支付发布验收。

原始计划、命令、日志、汇总和附件：`/private/tmp/xunju-offline-privacy-20261030/{plan,run,summary}-13.*`、同目录 `*-14.*` 与 `attachments-{13,14}/`。结果包：`/Volumes/mac2/codex-builds/xunju-offline-business-20261030-{13,14}.xcresult`。共享 runner 已退出并释放本任务资源。

持久原图及逐图 SHA256/源码/设备来源：`/Users/pc/.codex/visualizations/2026/10/29/01a18886-1bc3-7922-9396-c73515b59cbf/ios-offline-final/`。主 agent 已查看当前设置、法律入口、购买重启恢复和评价两次打开截图。`settings-current.png`、`legal-links-current.png`、`purchase-restored-once.png` 来自 run-13；`settings-review-row.png`、`settings-review-url.png` 来自 run-14。评价 URL/次数为 DEBUG 宿主的可见回显，不是正式界面；¥1.99 与交易是夹具。目录还保留未修改的失败图、summary、去除令牌的 runner receipt、ASC 当前回读和历史定位/退款证据。

最终生产差异已由主 agent 在 PR 创建及更新后复核：旧数据迁移不切空目录，购买证明不进入房源备份或日志，先持久化再 finish，沙盒与正式环境隔离，主线评价入口及隐私理由保留。后续提交仅更新本验收文档，不改变执行输入。没有云端 check-run/status 通过记录，不能把空检查列表称为 CI 通过。iOS #92 和后端 #98 继续保留草稿，未合并/部署；真实支付、商品资料与 App Privacy 标签为独立发布前事项。

## 最新评价入口整合与最终复验

run-13（`6c57f510f04db44c25a323042fdff23282a3ab5f`、iPhone 14 Pro / iOS 18.3.1）41 UT 与离线记录、购买恢复两项 UI 通过，仅评价入口 UI 失败。原始截图 `6F3B907A-2082-43C0-B148-46A2F42557A6.png` 显示评价行尚在屏幕下方；AX hierarchy 给出评价行 y=810.3、高50，而 Tab 栏顶部 y=768；合成 tap 实际落在 (196.5, 835.33)。`isHittable` 错误地让测试跳过滚动，未真正点击评价行。修正只在该失败方法里先滚动并断言行底部位于 Tab 栏之上，保留两次点击、正式 URL 和计数断言，不改生产代码或延长超时。run-14 仅复跑这一个方法；41 UT 和另外两项 UI 按单失败恢复规则复用，原失败保留。

run-12（`2696c0f`）构建通过后等待共享执行槽；期间主线合入 `b5a3b4d40d6476dffd17fcf30721d3b6383d4788`，新增已批准的 App Store 评价入口并记录正式 App ID。为避免继续验证旧基线，向本任务 runner 发送 SIGTERM；它恰已取得设备并进入测试命令准备，但尚无 Test Case 执行记录，退出 143 并清理本任务资源。该批不计为通过或测试失败。

在本任务分支解决设置页冲突，将主线原有 `AppStoreReviewRow` 保留在“使用反馈”与“分享看房搭子”之间；保持主线 DEBUG 评价路由，只同步其测试中的反馈/分享选择器。未重新引入登录。ASC 只读回查确认 App ID `6828695680` 与商品 `6828697996` 已存在，后者为 `MISSING_METADATA`，未执行任何 ASC 写操作。证据 `ios-offline-final/asc-app-current.json` 和 `asc-iap-current.json` 替代早先空列表结论。

由于冲突需要手工整合，run-13 重新执行合并后候选上的 41 项定向单测：run-11 的 28 项、run-12 新补的 10 项直接消费者、主线评价链接和 DEBUG 路由的 3 项。最终 UI 风险重新排序为本机记录/免登录设置/法律入口、容量确认与重启恢复、整合后的评价入口实际点击；恰好 3 个方法。首次定位修复由 run-09 失败/run-11 通过提供补充证据，退款由 run-09 提供补充证据；未运行全量 UI 套件。完整精确选择器与命令在 `plan-13.json`、`run-13.sh`。

## 此前服务端方案交付状态（历史）

2026-10-30：用户已批准设置/扩容组件接入和公开页面发布，三个公开页面已上线。正式 iOS 页面的无登录与离线接入、独立 Apple 购买身份与后端账本已实现，已完成下文列出的定向业务回归。后端草稿 PR 为 https://github.com/Hayden-Chang/model_server/pull/98 （137 项回归通过，未部署）。最新只读回查已确认 App ID `6828695680`（`RentVisit: Viewing Checklist`、Bundle ID `com.keeline.xunju.ios`），及消耗型商品 `com.keeline.xunju.ios.capacity10`（IAP ID `6828697996`，状态 `MISSING_METADATA`）。早先空查询已过时；真实沙盒付款仍需补齐商品资料并配置、部署服务端。App Privacy 标签仍需单独填写。

以下“组件预审”记录为批准前的历史证据，不代表当前仍在等待同一次 UI 批准。

## 组件预审范围（历史记录）

用户要求先补公开页面和隐私清单，再移除 iOS 登录入口；已明确保留付费扩容，另做免登录购买，并保留仅由用户主动触发的地图、测速及反馈。核心记录应完全离线。

本批完成材料及独立组件，尚未接入生产 SettingsPage、AppWorkspace 或购买协调器。生产登录、启动时联网和账号目录行为尚未改变，不能以此文档作为离线版本已完成的证据。组件须按 `ios-ui-component-review-gate` 在实际 XCUITest 截图展示后取得用户批准，才能继续业务接入。

- iOS 草稿：[rent_room PR #92](https://github.com/Hayden-Chang/rent_room/pull/92)。
- 公开页面草稿：[support PR #14](https://github.com/Hayden-Chang/support/pull/14)，源码 `b9d7d234b5246b963683a6cc68a520dd19f03fa5`。
- 支持仓库沿用 TimeFragment 的静态 GitHub Pages 托管方式，新增看房搭子专属路径，不复用其他 App 的政策正文。
- 页面注明适用于免登录 iOS 版本，随该版本发布生效，不适用于微信小程序；目前未合并发布，不能将目标 URL 视作已上线。

## 公开页面

| 内容 | 目标 URL |
| --- | --- |
| 隐私政策（中英双语） | https://hayden-chang.github.io/support/privacy-policies/kanfangdazi/privacy-policy.html |
| 使用条款（中英双语） | https://hayden-chang.github.io/support/terms-of-service/kanfangdazi/terms-of-service.html |
| 支持与 FAQ（中英双语） | https://hayden-chang.github.io/support/kanfangdazi/ |

页面说明本机记录、系统备份与主动 ZIP 导出、权限、地图/路线/测速、反馈内容与保存、扩容交易、删除及联系渠道。操作方与公开联系邮箱沿用 support 仓库现有资料。政策和条款均保留 Markdown 正文，便于后续与 HTML 同步审查。页面不加载脚本、统计或第三方资源；访问第三方外链才离开页面。

源码 `2eb9eca` 的三个页面共 24 个链接检查通过：站内目标文件存在、外链均为 HTTPS 或 mailto。隐私/条款 Markdown 正文与 HTML 一致，无 script、iframe、form、外部样式或图片加载。通过本地浏览器查看三个页面并点击导航与 FAQ。`b9d7d23` 只在 HTML 标签及 CSS 规则间加入换行，去掉空白后的源码完全相同，复用内容与视觉证据。该结果不证明公网部署，也未覆盖所有手机宽度。原始输出及预览图位于 `/private/tmp/xunju-offline-privacy-20261030/`。

## 隐私清单的源码依据

`ios/Xunju/Resources/PrivacyInfo.xcprivacy` 由 XcodeGen 的 `Xunju` 源目录自动纳入 App 资源，无须提交生成工程。

| 项目 | 声明及依据 |
| --- | --- |
| 跟踪 | `NSPrivacyTracking = false`，跟踪域名为空；当前没有广告/跨 App 跟踪 SDK |
| 系统运行时间 | `NSPrivacyAccessedAPICategorySystemBootTime` / `35F9.1`；`NativeSpeedTest.swift` 测量持续时间，`MPChecklist.swift` 计算手势时间间隔 |
| 客户支持 | `CustomerSupport`，App 功能，不跟踪、不关联购买身份；用户主动提交评价及自由文本，后端保存正文、随机请求编号与时间 |
| 购买历史与标识 | `PurchaseHistory`、`UserID`，App 功能，不跟踪；交易与购买标识用于持久容量账本，因此标记关联身份，免登录并不代表不存在购买标识 |
| 精确位置 | `PreciseLocation`，App 功能，不跟踪、不关联购买身份；用户主动地图/路线请求可向服务方发送坐标 |
| ZIPFoundation 0.9.20 | SDK 自带 `PrivacyInfo.xcprivacy`，声明 FileTimestamp / `0A2A.1`；随其资源 Bundle 打包，不把 SDK 的包装库理由复制到 App 清单 |

直接源码扫描未发现 `UserDefaults` / `@AppStorage`、磁盘空间或文件时间戳读取。媒体代码读取 `fileSizeKey` 和 `isRegularFileKey`。新增 API 或依赖时须重新检查；本次扫描不代替 Apple 对最终提交包的验证。

系统运行时间原因依据 [Apple required-reason API 文档](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)。上述收集类型针对目标免登录版本；完整接入后须按实际传输与保留情况复核，包括购买标识、地图服务及反馈的关联性。App Store Connect 的 App Privacy 标签需单独填写，本文件不会同步后台标签。

## 组件验收边界

- `LocalSettingsSurface` 顶部保留容量入口，移除头像、昵称、登录和退出登录控件；保留其他设置，增加隐私、条款、帮助入口。
- `AccountFreeCapacitySurface` 复用容量卡片，显示免 App 登录购买/恢复文案及法律链接。价格由调用者提供，不能在生产中回退到夹具价。
- `LocalSettingsReviewHost` 只在 DEBUG 且参数 `--local-settings-review settings|capacity` 完整匹配时启用。它不启动 workspace、Keychain、网络或 StoreKit。
- 测试点击购买仅驱动“等待购买结果”，点击恢复仅驱动网络错误；这些证据只证明呈现与交互，不证明实际交易、退款、容量到账或数据持久化。

## 后续业务接入的验收条件

1. 用户批准组件截图后接入真实页面；普通启动及切回前台不自动请求容量策略/购买服务，核心新增、修改、媒体及导入导出离线可用。
2. 保留升级前当前本机记录及媒体，不因移除登录跳到空游客目录；购买身份与本机数据目录分离，不自动合并其他账号目录。
3. 实现免 App 登录的交易验证、重复到账保护、离线容量缓存、失败后重试、恢复和退款保留房源。当前服务端实现仍是 [model_server Draft PR #87](https://github.com/Hayden-Chang/model_server/pull/87)，未部署；不能仅隐藏登录或伪造 session 来声称完成免登录购买。
4. 现有商品是消耗型扩容，iOS 最低版本为 17。已完成消耗型交易在旧系统上的恢复不能假设与 iOS 18+ 历史 API 相同，需要在实现中明确持久恢复路径并验证。
5. 上线前合并并检查三个公网 URL、复核政策与最终代码、填写 App Privacy，完成真实沙箱购买/恢复及发布要求。本批没有合并、部署、真机安装或提交审核。

## 执行记录

首次 run `xunju-privacy-review-20261030-01` 在源码 `66917f6` 上编译通过，实际 App Bundle 同时包含 App 清单及 ZIPFoundation 清单。编译后等候测试槽位时，本任务新增此文档，runner 因工作区快照变化拒绝继续，退出 2，未执行测试。保留 `/Volumes/mac2/codex-builds/xunju-privacy-review-20261030-01.build.xcresult` 及 `/private/tmp/xunju-offline-privacy-20261030/run-01.log`，不计作通过或失败的测试用例。提交文档后使用新 run ID，在冻结工作区上复验相同的 3 项单测及 2 项 UI 测试。

第二次 run `xunju-privacy-review-20261030-02` 在干净源码 `4cfae1e3dc509fc6a0263788a6c6a615f4250bad` 上完成：**3 UT + 2 UI 全部通过，0 失败、0 跳过，runner 退出 0**。本任务队列、设备租约和 run slot 已释放。使用共享 runner、项目自有 `run-xcodebuild.sh` 和固定 XcodeGen 2.45.4，无裸 xcodebuild 或手动抢设备。

| 证据 | 位置 |
| --- | --- |
| 计划和命令 | `/private/tmp/xunju-offline-privacy-20261030/plan-02.json`、`run-02.sh` |
| 完整日志 | `/private/tmp/xunju-offline-privacy-20261030/run-02.log` |
| 结果包 | `/Volumes/mac2/codex-builds/xunju-privacy-review-20261030-02.xcresult` |
| 原始附件 | `/private/tmp/xunju-offline-privacy-20261030/attachments-02/` |
| 截图及来源清单 | `/Users/pc/.codex/visualizations/2026/10/29/01a18886-1bc3-7922-9396-c73515b59cbf/ios-offline-privacy/` 中的 PNG、`provenance.json` 及去除令牌的 `runner-receipt.json` |

三项 UT 为 `LegalResourcesTests` 的公开 URL、实际包内清单和显式调试路由校验。两项 UI 为 `LocalSettingsReviewTests` 的设置控件/隐私支持链接回调，以及扩容待确认/恢复网络错误显示。没有执行完整应用回归或真实 Apple 交易测试。

主 agent 已逐张查看并在会话展示 5 张未经修改的 XCUITest 截图。设备为 iPhone 16 / iOS 26.5，UDID `759E28A9-21EB-4AA1-9F4F-EF1850989C56`，每张 1178×2556。设置菜单对齐、法律入口和扩容文案清晰；待确认按钮禁用，错误提示出现后显示容量仍为 1/1。¥1.99 与 1/1 为测试数据；设置页底部“房源容量”为 DEBUG 宿主的动作回显。待确认及错误状态的底部法律链接需要滚动查看。本批没有验证其他屏幕尺寸或动态字体。

当时组件状态为 **REVIEW_READY**；该次 UI 批准已于 2026-10-30 获得。正文后续只追加验证结果，未改动 Swift、资源、配置或测试，截图继续归属 `4cfae1e`，不冒称来自文档提交后的 HEAD。PR 创建后已由主 agent 另行复核差异、范围和证据；GitHub check-runs/statuses 为空，不能称云端 CI 通过。

## 用户确认后的业务接入（2026-10-30）

用户回复“是的，没问题”，批准已展示的无登录设置/扩容页面接入，并批准三个公开页面发布。support PR #14 已合并（e74ddcfa9db08c6ac55479b7cbb380b560b4b7eb），三个 HTTPS 页面已逐一验证 HTTP 200。

本轮接入：正式设置页采用已批准组件，移除 Apple 登录、头像/昵称编辑、退出登录和登录准备请求；移除启动/回前台时的容量联网；购买观察器仅在扩容页面启用。首次离线启动固定当前本机记录目录，并保留历史账号目录、媒体及原缓存容量；后续启动不需要 Keychain 登录记录。切换 Apple 购买身份只替换容量缓存，不切换或删除房源目录。

免登录扩容使用本机 StoreKit 验证过的 AppTransaction 签名证明。服务端再次使用 Apple 官方库验证，按 bundle/environment/appTransactionID 派生独立购买身份；iOS 17 可用已回移植的 appTransactionID 属性。三条 POST 接口位于 `/api/rent-room/ios/purchases/{context,verify,restore}`，无 App 登录 Bearer token。消耗型订单只有在服务端持久化及本机容量保存完成后才 finish；失败保留 unfinished，下次主动恢复补发；服务端账本支持已 finish 的订单在重装后恢复。Sandbox 与 Production 分开。签名证明仅在内存及 TLS 请求中使用，不进入房源备份或日志。

后端实现位于 model_server 独立分支 `codex/rent-room-account-free-purchases-20261030`，默认不开启销售。真实 App Store 商品、App ID、服务端密钥、部署和 Apple 沙盒交易仍是独立验收项；下面的 HTTP/StoreKit 注入测试不能代替真实付款。此次确认不作为 iOS/后端合并或部署授权。

本轮验证计划：13 条业务/迁移/API 单测，实际包内隐私清单单测，3 条真实页面交互（本机记录重启/无登录设置/公开链接入口；未确认购买恢复且不重复发放；退款保留超额房源/商品不可用）。其他已有 UI 文件仅同步设置入口选择器，移除已废弃登录/账号资料 UI 测试，保留旧账号数据模型与迁移单测。

补充主动联网边界：保存过地址的清单地图以前会在 onAppear 查询，折叠但已创建的 MapKit 也可能加载地图。现改为仅回填本机地址文字，搜索/定位/展开地图才创建请求或 Map；归档房源同样先显示“展开地图”入口。用户仍可离线手填地址。这是本轮离线约束的必要修复，增加对应单测及重启后手填地址 UI 断言。

## 业务验证交付（2026-10-30）

主线整合前覆盖为 **17 条单测 + 3 条真实页面 UI 用例分批通过**，不是全量测试，也不是实际 Apple 付款：

| 批次 | 源码 | 设备 | 结果 |
| --- | --- | --- | --- |
| `xunju-offline-business-20261030-06` | `e270005a4f47c71efe74ea3ecba60e41941addbe` | iPhone 16 / iOS 26.5 | 16 UT + 2 UI 通过；另有 1 UT、1 UI 失败，见下文 |
| `xunju-offline-business-20261030-07` | `768ce05c2a79137a1aa9220389975d1e25eb286f` | iPhone 14 Pro / iOS 18.3.1 | 17 UT + 1 UI 通过，0 失败、0 跳过，runner 退出 0 |

07 与 06 只差文档及一个地图单测断言，App 源码、资源、配置与 UI 测试完全相同。因此复用 06 中已通过的“本机记录/手填地址重启保留及无登录法律入口”和“退款保留超额房源/商品不可用”两个 UI 结果；07 复跑未通过的“购买未确认不加额、恢复到账、重启再恢复不重复加额”用例并通过。没有为通过而修改业务导航代码或放宽 UI 断言。

失败保留：03 编译发现观察属性在 store 初始化前读取，已修复；04 编译成功后模拟器 inventory 命令失败，复查恢复后换 run 重试；05 目录 URL 的目录标志差异被误判为路径越界，改为比较规范化路径并保留 symlink 检查；06 地图单测错误地要求主动附近查询只有一次请求，而原实现并行请求逆地理编码和附近地点，现同时验证 appearance 不增加请求数、主动操作才增加。06 的扩容 UI 点击后仍停在设置页，未确认具体原因；07 同一 UI 测试在另一池设备通过，不能声称该瞬态交互问题已定位。原始日志、失败层级与录屏均保留，不改写失败结果。

计划、完整命令、日志和截图导出：`/private/tmp/xunju-offline-privacy-20261030/{plan,run,summary}-0{6,7}.*`；结果包：`/Volumes/mac2/codex-builds/xunju-offline-business-20261030-0{6,7}.xcresult`。主 agent 已逐张检查 8 张未修改原图；设置及法律入口对齐清晰，手填地址重启后保持折叠地图；购买待确认仍为 0/1，确认与重启恢复为 0/11，退款保留 3 套房源而总额度降为 1。待确认状态下恢复按钮和法律链接需要滚动；确认截图气泡处于逐字动画中，重启后截图为完整文案。

持久截图与逐图 SHA256 来源记录位于 `/Users/pc/.codex/visualizations/2026/10/29/01a18886-1bc3-7922-9396-c73515b59cbf/ios-offline-business/`：`settings.png`、`legal-links.png`、`offline-address.png`、`purchase-pending.png`、`purchase-confirmed.png`、`purchase-restored-once.png`、`refund-keeps-records.png`、`product-unavailable.png`。¥1.99、订单和容量为受控测试夹具，实际采用原生页面、持久文件和购买控制器；不证明真实 StoreKit 签名获取、Apple 扣款或服务器部署成功。

公开页面已于本轮按授权合并并验证 HTTP 200。App Store Connect 查询证据为上述目录 `asc-bundle-lookup.json`（当前凭据对 `com.keeline.xunju.ios` 返回 data=[]）；公开页回读为 `public-pages-live.json`。iOS PR #92 和后端 PR #98 仍为草稿，未合并、未部署、未上传或提交 App Review。真实 Apple 沙盒交易及 App Privacy 标签填写仍待具备对应 App/商品/服务配置后单独验收。

## 主线前进后的整合

最终远程回读发现 main 已前进到 `8a078ec6dcc0aab0681f3099e936acae77ff8b30`，包含性能优化、移除自动通勤入口、触摸轨迹与系统评分。此前 GitHub PR base 快照仍显示旧 SHA，但 mergeability 已为 dirty，因此没有把旧批次当作当前主线的合并证据。

在本任务分支合入该主线并解决冲突：保留免登录设置和主线触摸轨迹开关；购买确认继续保留评分资格、失败重试及待批准订单的购买时间判断；保留主线已删除的自动通勤入口与对应测试删除；保留模板重新打开的新增断言。旧 Apple 登录 UI 测试继续删除，现有评分和触摸轨迹测试改用无登录设置入口。

主线新增 `UserDefaults` / `@AppStorage` 存储触摸轨迹本机偏好，隐私清单随之补入 `NSPrivacyAccessedAPICategoryUserDefaults` / `CA92.1`，同步实际包内清单断言；依据 [Apple TN3183](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest)。此前“未使用 UserDefaults”仅属于旧基线扫描结果。

本次冲突使旧 iOS 证据不再覆盖整合后的代码。重新执行全部本批单测、评分相关单测与触摸偏好观察单测，以及三个最高风险 UI 方法：离线记录重启与无登录设置（包含触摸开关默认关闭及法律入口）；未确认订单恢复、系统评分与重启去重；退款保留超额记录与商品不可用。触摸手势和所有仅换选择器的历史长流程不在本次最终三项 UI 选择内，不能声称全量 UI 回归。

整合验证 run-08（`cd6506b`）：28 UT 全通过，离线记录 UI 与购买恢复/系统评分 UI 通过；退款 UI 在首次切换设置前失败。原始视频中仍显示房源首页，合成点击坐标落在“我的”按钮内；失败层级显示一个外部进程的空全屏 Window 位于 App 主窗口之上，但画面没有评分文字。退款夹具创建三套房源会满足系统评分条件，因此下一诊断批次只将该夹具设置为“历史记录已消费评分机会”，不改生产导航或断言，以排除非退款场景的系统窗口干扰；不把它与 run-06 的失败宣称为同一已定位原因。

同时新增首次直接定位必须显示地图的 UI 断言；先在未修复的地图代码上执行，验证 `interacted` 未更新的具体回归，再修复。不会通过放宽断言或增加盲目重试规避问题。

run-09（`9f6f79b`）证实退款夹具隔离后完整用例通过（115.145 秒）；首次定位用例在候选结果出现后，准确失败于“An explicit first location request must mount the map”（49.571 秒）。修复仅让用户点击定位时设置 `interacted = true` 并展开地图，页面出现仍不挂载地图或查询。最终 run-10 的三项 UI 按新风险排序为离线记录/设置、购买恢复/评分、首次定位/保存/重启；退款结果作为 run-09 的未受地图显示改动影响的补充证据保留。

run-10（`99649ca`、iOS 18.3.1）28 UT 通过，3 UI 未通过：容量已确认 0/11 后额外加入的评分文字等待失败；离线用例重开详情时发生 App event loop idle notification 缺失及可访问性快照超时，原因未定位；定位用例显示“定位权限未开启，请在设置中允许访问位置”，未到地图断言。保留结果包、完整日志及附件，不把该批当作最终通过。

依据 [Apple WWDC20 授权测试说明](https://developer.apple.com/videos/play/wwdc2020/10220/) 和 [XCUIApplication.resetAuthorizationStatus](https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/resetauthorizationstatus(for:))，首次定位测试在 app.launch 前仅重置本次租约中本测试 App 的 `.location` 权限。购买 UI 回归恢复“到账/持久化/幂等”原范围，移除本轮临时加入的系统评分弹窗必出现断言；生产评分代码不变，7 项评分单测、主线独立评分 UI 测试保留，run-08 已有实际评分展示证据。Apple [RequestReviewAction](https://developer.apple.com/documentation/storekit/requestreviewaction) 对开发环境描述为应显示，因此不将 run-10 未显示简单解释为生产评分频率限制，保留为未定位平台交互异常。下一批完整重跑 28 UT+3 UI，未扩大超时或删除任何容量、离线保存及地图断言。

run-11（`dc0988b`）28 UT 通过；离线记录 UI（124.266 秒）和定位授权/显示地图/保存/重启 UI（74.159 秒）通过，run-09 的首次定位回归已得到修复后证据。容量用例已完成 0/1→0/11，但重启后系统评分窗口再次干扰设置导航，仅这一 UI 方法失败（56.658 秒）。

单例恢复修正：容量 UI 的受控 StoreKit 场景新增显式 `--stub-system-review`，必须同时具备 DEBUG、有效 UUID 与已知 capacity fixture 才生效；评分资格/持久化仍走原业务，唯一隔离的是平台评分窗口的展示调用。正式版和主线独立 `AppReviewUITests` 不带该标记，仍调用真实 StoreKit。新增 guard 断言，保留 run-08 的真实评分窗口证据。run-12 重跑该一个失败 UI，并补查构造器直接消费者：既有记录/旧身份目录/错误恢复、容量策略离线缓存、工作地点保存及目录保护。旧损坏账号用例的“session 必须存在”断言按当前已明确的免登录契约改为 session 为空，其数据保留与恢复断言不变。App 源码与 run-11 的差异仅 DEBUG 评分展示隔离，离线/地图 UI 不带标记；其结果可复用，不增加第四个最终 UI 场景。
