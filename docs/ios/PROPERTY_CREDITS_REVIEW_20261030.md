# 房源点数：组件评审与待接入规则

状态：iOS `REVIEW_READY`，小程序实际渲染 `BLOCKED`。本 PR 是展示组件预审；正式容量页、扣点逻辑、用户数据和线上商品均未改动，不能当作点数业务已经上线。

## 已确认的产品规则

- 小程序 ¥1.99 / 10 个房源点数；iOS 中国大陆 ¥9.90 / 10 个，美国 $1.99 / 10 个。
- 只有通过“新建房源”成功保存一套新房源才消耗 1 点；取消和保存失败不扣点。
- 导入和从归档恢复不扣点，也不受零点数限制；归档、删除不返还已使用点数。
- 小程序既有用户的剩余容量一次性转换为点数：`max(0, 当前免费容量 + 已购包数 × 10 - 当前未归档房源数)`。转换保留既有房源、答案、问题、备注和媒体。
- 用户已明确选择继续本机方案，不新增跨设备同步；换机、重装不保证恢复消费记录。同一份本机数据内重复刷新、恢复购买仍不得重复发点。

## 实时只读核实

2026-10-30 通过 `asc iap pricing summary --iap-id 6828697996 --territory USA|CHN` 核实商品 `com.keeline.xunju.ios.capacity10` 为 CONSUMABLE，美国 1.99 USD、中国 9.9 CNY。现有参考名仍为 `10 Property Slots`，尚未写入 ASC。正式 UI 继续使用 `Product.displayPrice`；组件截图中的价格来自明确标记的测试夹具。

现网小程序 v2 `/catalog` 返回 `capacity:{version:2,freeLimit:2}`、`product:{id:room_capacity_10,price:199,size:10}`，`available` 和 `iosAvailable` 均为 true。订单、账号与购买权益在服务端；房源和当前占用保存在本机。因此剩余容量转换必须由新版读取本机记录完成，不能靠服务器批量计算当前余额。

## 组件范围

- iOS `PropertyCreditsSurface` 接收余额、可选迁移提示、Apple 本地化价格、等待/错误状态和回调。独立 `--component-review property-credits` 路由只在 DEBUG 编译，不创建 AppWorkspace、不读取真实记录、不调用 StoreKit 或网络。
- 小程序 `components/property-credits` 是相同文案的展示组件。独立工程在 `tests/fixtures/property-credits`，由 `node tests/e2e/build-property-credits-review.mjs` 生成到忽略目录 `artifacts/property-credits-review`。正式 app.json 不注册测试页面。
- 保留小饼干购买样式，摘要改为“剩余房源点数”；展示新建、导入/恢复、归档/删除三条规则。正式首页、我的页、购买页及小搭感谢文案仍待批准后统一接入。

## 验证与证据

iOS 证据源码：`14861891199e11c7abdbbc4c6dbdfdaa409d25cb`。共享 runner `rent-room-property-credits-20261030-01` 完成 2 UT + 2 UI，全部通过、无失败或跳过；仅验证展示/按钮回调，不是扣点、迁移、支付或恢复的端到端证据。

- UT：`UtilityComponentTests/testReviewRoutesRequireExplicitKnownDebugArgument`、`ComponentLogicTests/testReviewHostRequiresExplicitKnownSurface`。
- UI：`PropertyCreditsReviewTests/testLocalizedPricesRulesAndPurchaseCancellationPreserveBalance`（中国价格、英文美国价格、购买等待/取消、零余额）；`testUnavailablePendingAndRestoreFailureDoNotGrantCredits`（不可售、待确认、恢复失败）。所有新增 UI 方法已执行，未跑全套。
- 设备：iPhone 14 Pro / iOS 18.3.1，UDID `8F178971-C203-4690-A83B-253046EACBB1`，截图 1178×2556。
- `.xcresult`：`/Volumes/mac2/codex-builds/rent-room-property-credits-20261030-01.xcresult`。
- 计划/命令/日志：`/private/tmp/property-credits-evidence/plan-01.json`、`run-01.sh`、`run-01.log`。
- 持久原图、来源 SHA/测试/附件名/尺寸/哈希、汇总和目录回读：`/Users/pc/.codex/visualizations/2026/10/30/01a18c24-c384-7503-aa95-42333779ae5e/property-credits/`。
- XcodeGen 2.45.4 通过确定性校验；`project.yml` 未改，生成工程未提交。runner 使用自身按工作树隔离的缓存目录，未手动复用或操作其他设备。

主 agent 已逐张查看 7 张原图，中英文文案和按钮均完整可见，忙碌/等待状态禁用购买，错误状态保留余额。标题右侧“评审状态”和底部回调次数均为 DEBUG 宿主，不进入正式页面。

小程序官方 `wcc` 和 `wcsc` 对组件及测试页面编译通过；展示回调的 3 条 Vitest 边界用例另存于 `tests/property-credits-component.test.js`。真实渲染任务 `f10f66a83e1e4258b178a5bce4c8af71` 使用共享入口排队，三个槽位实时均为 `quarantined`，未获得槽位、未执行回调、未取得截图。不能用编译/VM 或 iOS 图替代微信实机/工具渲染；未重启、解锁或抢占其他任务实例。E2E 脚本保留待可用槽位执行。

## 待批准后完成

依据 [ios-ui-component-review-gate](/Users/pc/.codex/skills/ios-ui-component-review-gate/SKILL.md)：

> Do not integrate it into the complete page or continue the downstream business flow before approval.

需用户确认点数组件后再接入完整页面与业务。后续必须覆盖一次性旧余额迁移（含免费/已购/超额/离线）、新建成功恰好扣一点、失败回滚、零点导入/恢复、归档/删除不返点、重启保留、购买/恢复/退款幂等、账号目录切换及备份不能覆盖消费账本等边界。消费记录需要与房源持久化的提交结果协调，不能靠页面按钮点击计数。

还需补微信实际截图与用户确认；正式业务接入后重新按最终 diff 选择测试和审查 PR。迁移真实用户数据、部署、合并、上传、商品本地化/参考名变更及发布均尚未执行。
