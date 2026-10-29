# 第八批购买业务接入（2026-10-20）

用户已明确批准第八批 UI：“确认通过，继续购买业务接入”。组件状态为 **APPROVED**；本轮复用批准的 CapacitySurface，接入我的→房源容量、现有登录入口、StoreKit 客户端与独立服务端交易账本。**业务及页面定向验证有效通过，本地 StoreKit 系统交易测试仍失败，完整支付未验收，PR 保持 Draft。** 不重复请求组件批准。

## 实现

- 游客免费记录与两套限制保持原规则，容量页购买/恢复打开已有登录页，可进入手机号表单；不会因点击或登录增加容量，也不自动扣款。正式客户端从后端读取商品编号和账号专属 UUID，再以 Product.displayPrice 显示商店价格，不使用夹具价格回退。
- 购买带 appAccountToken，客户端只处理 StoreKit 本地已验证交易。交易编号发往服务端，服务端向 Apple 查询并通过官方 SDK 验证证书链、签名、Bundle/商品/环境、数量、购买归属及账号绑定，再在独立 SQLite 表落账。每笔已确认消耗型交易增加10套，生产拒绝 Xcode/LocalTesting 环境。配套 [后端 Draft PR #87](https://github.com/Hayden-Chang/model_server/pull/87)。
- 服务端落账和本机 Keychain 容量缓存都成功后才 finish；确认失败保留未完成交易并禁止重复购买，恢复可重试。前后台重复通知共享确认任务，退款降低容量但保留已有全部房源，旧版本结果不覆盖新余额；更新缓存不延长会话、不替换房源 store。
- 切换账号或会话后丢弃旧结果，不结束原账号未确认交易；不按邮箱合并账号。恢复需要购买时的寻居账号，只恢复权益，不同步房源内容。AppStore.sync 仅由用户明确点击恢复触发；正常加载只读未完成交易和服务器账本。
- iOS17 依赖未完成交易及已落账的服务端交易编号恢复；iOS18+启用已完成消耗型历史。实际构建检查发现自动生成 plist 未写入自定义键，已改为明确的 Info.plist；布尔开关、显示名及三项原有隐私说明均在实际 App 的测试中通过。

## 本地验证及失败记录

有效 **14项 UT、3条 UI 场景通过**，另 **1项本地 StoreKit SDK UT 两次失败**，没有跳过、删除失败测试或称整体全绿。四轮共22次UT执行（20通过/2失败），4次UI执行全过；不同轮次的重叠方法不相加作为总覆盖。

| Run ID 后缀 | 源码 | 结果 |
| --- | --- | --- |
| `capacity-integration-20261020-01` | `f479aebdb4aa87e28501605733e4ec74c8f0f5ca` | 12UT/3UI通过，1个StoreKit系统UT失败，退出65 |
| `capacity-integration-20261020-02` | `ceeb5220b7d229f9a4720168e38101a996469a70` | 独立 XunjuStoreKitTests Scheme 选择商品配置、测试 Bundle 提供 .storekit 后，仅复验失败SDK方法，仍失败，退出65 |
| `capacity-integration-20261020-03` | 同 `ceeb522` | 下架恢复清除旧价格及Keychain保存失败补测：7UT/1UI全过，退出0 |
| `capacity-integration-20261020-04` | `81c29ea` | 明确plist后验证实际构建的历史开关、显示名、相机/麦克风/定位说明：1UT通过，退出0 |

01/02 原始日志均出现 `SKTestSession` 保存配置、设置选项、清空交易的 `SKInternalErrorDomain Code=3`，随后 Product.products 无商品。该错误与 [Apple 开发者论坛的同类报告](https://developer.apple.com/forums/thread/826971) 相符；论坛还记录新版本修复及继续复现的反馈，不能据此断言本机 SDK 实现正确或宣称交易成功。本机为 Xcode26.6 / iOS26.5，独立Scheme校准后仍复现，未继续重复同一试验。测试保留为失败，仍需可工作的测试环境、正式商品及沙箱/真机验证。

14个有效UT为 CapacityBusinessTests 全部7方法、CapacityAPITests全部2方法、NativeStorefrontTests/testFinishedConsumableHistoryAndExistingPrivacyKeysReachBuiltApp，以及受影响的 NativeStoreTests/testCapacityArchiveReadOnlyRestoreAndDeleteProtection、IdentityScopeTests/testGuestClaimIsIdempotentAndLogoutStartsFreshGuest、testClaimPreservesOverCapacityRecordsWithoutGrantingCapacity、AuthenticationAPITests/testSMSChallengeAndSessionKeepServerIdentityContract。覆盖服务失败后重启恢复唯一到账、取消/待批准、缓存写失败不finish、重复前后台确认、切换账号保护、退款超额保留、旧版本及伪造响应、显式UUID测试入口和既有免费/身份规则。

失败方法为 NativeStorefrontTests/testRealStoreKitConsumableUsesAccountTokenAndStaysUnfinishedUntilAcknowledged，预期实际 SDK 商品读取、账号UUID、未完成/结束和再次购买；该方法未通过，不以 mock 替代其结果。

3条实际页面方法（XunjuUITests/CapacityBusinessUITests）：

- testGuestCapacityOpensExistingLoginAndSMSFormWithoutRequestingCode：真实容量导航→登录→短信表单；未请求真实验证码。
- testPendingPurchaseDoesNotGrantAndRestoresOnceAcrossProcessRelaunch：外部确认失败显示0/2且禁止重复→恢复0/12→进程重启及再次恢复仍0/12。
- testCancellationRefundAndUnavailableProductPreserveOverCapacityHouses：取消保留3/12→退款3/2→重启商品未开放→返回首页三套仍可见。

UI仅以 DEBUG + 合法UUID + 明确mode替换外部HTTP和StoreKit服务，保留真实 CapacityAPI 编解码、购买协调器、账号目录、JSCore容量、保存、导航与视图。**图中¥1.99是夹具价，页面结果是受控业务测试，不能当成 Apple 商品定价、实际收费或实际退款。** 普通Debug/Release不启用夹具；测试价格及文件不进入正常购买路径。

03重新覆盖修改过的协调器全部方法；API、既有桥接与身份方法源码未改，复用01。正常App Scheme未启用本地商品，02独立测试Scheme不改变普通运行。04仅修正plist及其新增构建测试，业务Swift、桥接、UI和夹具未变，复用01与03的业务及图像证据。03第一次声明校验漏列 changedUITests，未取得租约或执行测试；补齐计划后才运行，留存校验日志，不算第五轮执行。未运行全量UT、旧UI全套或最终PR head合并门禁。

## 原始证据

计划与日志、去除租约令牌的receipt、xcresult摘要、附件和脚本在忽略目录 `artifacts/ios-capacity-integration-20261020/`。完整包 `/Volumes/mac2/codex-builds/xunju-ios-capacity-integration-20261020-01|02|03|04.xcresult`，各轮另存同名 `.build.xcresult`。入口 `/tmp/xunju-ios-20261019/run-review.py`；02为 run-storekit.py；均先通过validate-only。四轮均已结束并释放本任务租约，实际设备UDID `5FC4A20B-AF44-4A92-BF91-B0096BEBF1D9`，iPhone16 / iOS26.5。

普通 Xunju Scheme 的workspace专用缓存 `/Volumes/mac2/codex-builds/time-fragment-dd-shared-57d1cd671f68343408c29f9f-simulator`；独立 StoreKit Scheme 为 `time-fragment-dd-shared-406987797fb8b6a9edf1350a-simulator`。哈希均由基础设施按本任务workspace和Scheme决定，未复用其他项目缓存。XcodeGen2.45.4真源与确定性检查通过，不提交生成工程。

6张1178×2556 PNG未经改图，主agent逐张查看；94–97来自01，98–99来自03。SHA/测试方法/设备/原附件/尺寸/SHA256在图目录provenance.json。

![待确认不发放容量](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-capacity-integration/95-capacity-unconfirmed-no-grant.png)

![服务替身确认后恢复](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-capacity-integration/96-capacity-server-confirmed.png)

![退款仍保留原房源](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-capacity-integration/98-capacity-refund-retains-houses.png)

后端实现 `6608d9c` 的 StoreKit/容量/原生认证3个相关文件114项通过，文档提交 `09511fa` 不改业务或测试；官方SDK签名链验证使用本地证书和HTTP替身，未访问真实Apple交易。首次隔离环境缺PyYAML的既有Compose失败、补依赖后单项通过及固定源码114项全过均保留，见后端docs/rent-room-capacity.md。

正式商品、服务密钥、回调配置、真实短信/Apple/微信与StoreKit沙箱/购买/退款/换机/真机仍未验收。全清单左滑协调、影像视频时长、永久删除/恢复副本文件回收等原任务事项继续待完成。本批未新增天地图请求，未合并、生产部署、真机安装或发布，不宣称完整iOS交付。
