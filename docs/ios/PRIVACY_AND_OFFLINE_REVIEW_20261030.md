# iOS 公开页面、隐私清单与免登录组件（2026-10-30）

## 当前交付状态

2026-10-30：用户已批准设置/扩容组件接入和公开页面发布，三个公开页面已上线。正式 iOS 页面的无登录与离线接入、独立 Apple 购买身份与后端账本已实现，已完成下文列出的定向业务回归。后端草稿 PR 为 https://github.com/Hayden-Chang/model_server/pull/98 （137 项回归通过，未部署）。本地 App 的 Bundle ID `com.keeline.xunju.ios` 在当前 App Store Connect 凭据下查询结果为空，真实沙盒付款需先建立对应 App 与内购商品并配置服务端。App Privacy 标签仍需单独填写。

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

最终覆盖为 **17 条单测 + 3 条真实页面 UI 用例分批通过**，不是全量测试，也不是实际 Apple 付款：

| 批次 | 源码 | 设备 | 结果 |
| --- | --- | --- | --- |
| `xunju-offline-business-20261030-06` | `e270005a4f47c71efe74ea3ecba60e41941addbe` | iPhone 16 / iOS 26.5 | 16 UT + 2 UI 通过；另有 1 UT、1 UI 失败，见下文 |
| `xunju-offline-business-20261030-07` | `768ce05c2a79137a1aa9220389975d1e25eb286f` | iPhone 14 Pro / iOS 18.3.1 | 17 UT + 1 UI 通过，0 失败、0 跳过，runner 退出 0 |

07 与 06 只差文档及一个地图单测断言，App 源码、资源、配置与 UI 测试完全相同。因此复用 06 中已通过的“本机记录/手填地址重启保留及无登录法律入口”和“退款保留超额房源/商品不可用”两个 UI 结果；07 复跑未通过的“购买未确认不加额、恢复到账、重启再恢复不重复加额”用例并通过。没有为通过而修改业务导航代码或放宽 UI 断言。

失败保留：03 编译发现观察属性在 store 初始化前读取，已修复；04 编译成功后模拟器 inventory 命令失败，复查恢复后换 run 重试；05 目录 URL 的目录标志差异被误判为路径越界，改为比较规范化路径并保留 symlink 检查；06 地图单测错误地要求主动附近查询只有一次请求，而原实现并行请求逆地理编码和附近地点，现同时验证 appearance 不增加请求数、主动操作才增加。06 的扩容 UI 点击后仍停在设置页，未确认具体原因；07 同一 UI 测试在另一池设备通过，不能声称该瞬态交互问题已定位。原始日志、失败层级与录屏均保留，不改写失败结果。

计划、完整命令、日志和截图导出：`/private/tmp/xunju-offline-privacy-20261030/{plan,run,summary}-0{6,7}.*`；结果包：`/Volumes/mac2/codex-builds/xunju-offline-business-20261030-0{6,7}.xcresult`。主 agent 已逐张检查 8 张未修改原图；设置及法律入口对齐清晰，手填地址重启后保持折叠地图；购买待确认仍为 0/1，确认与重启恢复为 0/11，退款保留 3 套房源而总额度降为 1。待确认状态下恢复按钮和法律链接需要滚动；确认截图气泡处于逐字动画中，重启后截图为完整文案。

持久截图与逐图 SHA256 来源记录位于 `/Users/pc/.codex/visualizations/2026/10/29/01a18886-1bc3-7922-9396-c73515b59cbf/ios-offline-business/`：`settings.png`、`legal-links.png`、`offline-address.png`、`purchase-pending.png`、`purchase-confirmed.png`、`purchase-restored-once.png`、`refund-keeps-records.png`、`product-unavailable.png`。¥1.99、订单和容量为受控测试夹具，实际采用原生页面、持久文件和购买控制器；不证明真实 StoreKit 签名获取、Apple 扣款或服务器部署成功。

公开页面已于本轮按授权合并并验证 HTTP 200。App Store Connect 查询证据为上述目录 `asc-bundle-lookup.json`（当前凭据对 `com.keeline.xunju.ios` 返回 data=[]）；公开页回读为 `public-pages-live.json`。iOS PR #92 和后端 PR #98 仍为草稿，未合并、未部署、未上传或提交 App Review。真实 Apple 沙盒交易及 App Privacy 标签填写仍待具备对应 App/商品/服务配置后单独验收。
