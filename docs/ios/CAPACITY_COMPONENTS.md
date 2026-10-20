# 第八批：房源扩容与恢复组件独立评审（2026-10-20）

状态 **REVIEW_READY，等待用户确认**。前七批均已批准，第七批业务9项定向UT/8条UI有效通过，见 [RELATED_MEDIA_INTEGRATION.md](RELATED_MEDIA_INTEGRATION.md)，不重复请求批准。

依据 [ios-ui-component-review-gate](/Users/pc/.agents/skills/ios-ui-component-review-gate/SKILL.md)：

> Do not integrate it into the complete page or continue the downstream business flow before approval.

本批只通过DEBUG显式 `--component-review capacity` 使用真实SwiftUI栈。`CapacityReviewHost`不创建AppWorkspace、不读房源/Keychain，不调用StoreKit、认证或网络，也不授予容量。普通业务仍没有扩容页面接线；Release没有评审路由。测试价格“¥1.99”与回调次数在宿主中明确标注，不能视为App Store商品定价、登录、购买或恢复成功。

## 与原版对齐

基准仍为main `6a07ecd` 的 `pages/capacity/index.wxml/.wxss`、`app.wxss`：容量卡24pt内边距、38pt已用数量/16pt上限、房源包卡20pt内边距、24pt价格、“增加10套”、整行购买按钮及恢复入口。配色、圆角、字号沿用小程序。新增的手机号/Apple登录与iOS支付使入口采用“登录后购买/登录并恢复容量”，恢复使用“恢复已购容量”。

组件只接收已用数、上限、登录状态、调用方提供的本地化价格、等待/错误状态和回调。未登录点击进入登录回调；购买或恢复等待时两入口禁用；待确认禁止重复购买但可恢复；取消后保留容量数且不显示成功/失败；商品不可用时不显示虚假价格或允许购买；失败后可重新发起；历史已用数超过容量仍照常显示。

## 验证

有效 **2项定向UT、2条UI场景通过**，两轮共3次UI执行，无测试失败。源码 `0e28a1774b89e145bbefaa02f6f97fa8bd0edc52`，截图校准 `7bdc934f6796c3c4c76e97bb1450418acd50306d`。

| 运行ID | 范围及结果 |
| --- | --- |
| `xunju-ios-capacity-components-20261020-01` | 2UT/2UI全过，退出0。主agent审图发现恢复等待截图含切换中的旧文字残影，未把过渡帧作为最终证据 |
| `xunju-ios-capacity-components-20261020-02` | 仅重跑第二条UI，增加实际“正在恢复容量”按钮文案条件校验后再取图，完整通过，退出0；产品代码未改 |

精确方法：

- `XunjuTests/UtilityComponentTests/testReviewRoutesRequireExplicitKnownDebugArgument`：新增capacity路由只由显式已知DEBUG参数识别；缺失/未知参数忽略。
- `XunjuTests/ComponentLogicTests/testReviewHostRequiresExplicitKnownSurface`：既有宿主守卫兼容。
- `XunjuUITests/CapacityReviewTests/testGuestLoginPurchaseBusyAndCancelKeepCapacity`：游客购买/恢复均只调用登录；切换登录态、价格、购买等待禁用、防重复、取消保留2/2且无错误。01通过。
- `XunjuUITests/CapacityReviewTests/testUnavailablePendingRestoreFailureAndOverCapacityKeepRecords`：加载、未开放、待确认、恢复等待与禁用、错误后重试回调、12/2历史数量保留。02完整通过。

复用依据：`0e28a17..7bdc934`仅为第二条UI加入等待状态文案断言，组件、宿主、路由、两项UT和第一条UI均未改；复用01的2UT/第一条UI与85–87三张图，其余六张来自02。该批新组件只由显式capacity评审路由引用，既有业务与第七批测试源码未改，业务证据仍等价。后续纯文档更新不改变验证源码。未运行全量UT、旧UI套件或最终PR head门禁。

## 结果与原图

入口 `/tmp/xunju-ios-20261019/run-review.py`，计划 `capacity-components-plan-01|02.json`，先validate-only再执行。结果 `/Volumes/mac2/codex-builds/xunju-ios-capacity-components-20261020-01|02.xcresult`，构建另存同名 `.build.xcresult`。Xcode26.6 / iOS26.5 / XcodeGen2.45.4，project.yml未改，不提交生成工程。共享租约UDID `5FC4A20B-AF44-4A92-BF91-B0096BEBF1D9`，workspace专用缓存沿用本任务既有哈希目录；本任务两轮均完成并归还租约，不操作其他任务槽位。

计划、日志、两轮原始附件与receipt、收集脚本和所读Apple官方文档存入忽略目录 `artifacts/ios-capacity-components-20261020/`。9张1178×2556 PNG直接复制原图，没有拼接或改图，主agent逐张查看。来源SHA/测试/原附件/尺寸/SHA256在图目录 `provenance.json`。

| 状态 | 实际截图 |
| --- | --- |
| 游客登录入口 | ![游客容量页](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-capacity-components/85-capacity-guest.png) |
| 已登录购买与恢复入口 | ![已登录容量页](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-capacity-components/86-capacity-ready.png) |
| 购买等待 | ![购买等待](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-capacity-components/87-capacity-purchase-waiting.png) |
| 商品加载 | ![商品加载](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-capacity-components/88-capacity-product-loading.png) |
| 商品未开放 | ![商品不可用](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-capacity-components/89-capacity-product-unavailable.png) |
| 待确认与恢复入口 | ![等待购买确认](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-capacity-components/90-capacity-purchase-pending.png) |
| 恢复等待 | ![恢复等待](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-capacity-components/91-capacity-restore-waiting.png) |
| 恢复失败与重试 | ![恢复失败](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-capacity-components/92-capacity-restore-error.png) |
| 已有数量超过上限 | ![历史数量保留](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-capacity-components/93-capacity-existing-over-limit.png) |

## 后续真实支付边界

正式价格将使用Apple [`Product.displayPrice`](https://developer.apple.com/documentation/storekit/product/displayprice) 的商店本地化字符串，API可用于iOS15及以后，覆盖本项目最低iOS17；没有正式商品时不回退到示例价格。实际商品配置、客户端交易、服务端验签/幂等授予、退款/撤销与恢复仍未实现或验收，本次不创建App Store商品、不发起支付。

已读官方 [`AppStore.sync()`](https://developer.apple.com/documentation/storekit/appstore/sync())：该调用可能出现App Store认证提示，只由明确用户操作触发。重复购买房源包的历史与恢复不能仅依赖当前设备：[`SKIncludeConsumableInAppPurchaseHistory`](https://developer.apple.com/documentation/bundleresources/information-property-list/skincludeconsumableinapppurchasehistory) 从iOS18提供已完成消耗型交易历史，启用前需服务端对账防重复授予，不能据此覆盖最低iOS17；服务端 [`Get Transaction History`](https://developer.apple.com/documentation/appstoreserverapi/get-transaction-history) 可返回各产品类型及退款/撤销状态。后续接线需要交易账本，不能将本组件点击回调当成权益。

上述页面由web工具发现；正文Markdown因工具不支持内容类型，使用Python仅向Apple官方对应.md地址只读下载核对，未访问任何账号或交易接口。尚无真实短信/Apple/微信/StoreKit、真机或发布验收；未合并、部署、安装真机或发布。
