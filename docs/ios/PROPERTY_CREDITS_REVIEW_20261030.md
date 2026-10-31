# 房源点数：正式页面、兼容迁移与消费记录

状态：用户已以“可以”明确批准第 4 版布局，iOS UI 门禁为 `APPROVED`。两端正式页面已接入。2026-10-31 用户确认小程序登录后联网扣点，新增服务端兼容迁移；iOS 继续本机方案。最新兼容验证见下文。新增“小搭点数不足提醒”为独立组件预览，尚未获视觉批准或接入正式入口。微信正式页已实际渲染并截图；自动化工具 Page 查询超时，真实购买/刷新点击仍为 `BLOCKED`。PR #105 保持草稿，未合并、部署、上传或发布。

## 小搭点数不足提醒：组件待确认（2026-10-31）

- 用户新增文案：“你的房源点数不够啦～”。iOS 与小程序点数组件增加默认关闭的 `fromCreation` 输入，仅在来源为新建且余额为 0 时显示现有小搭 think 形象与横向气泡，位于余额上方；普通购买页及点数充足时隐藏。无小饼干、无额外购买外框。
- 当前为 `REVIEW_READY` 组件阶段。正式 iOS `CapacityPage` 和小程序 capacity 页尚未传入该标记，因此不会让未批准的提醒进入正式流程。用户确认布局后，再按新建 intent 接入，并验证从首页新建和设置两个实际入口。原第 4 版点数布局批准不冒充本次新增小搭区的批准。
- 用户认为初版 expect 表情不合适，当前改为睁眼、托腮的 think 表情；文案、位置及显示条件不变。新版仍待视觉确认。源码 `a46b7c87f06c272ac538b963183f8612e616ed9b`，共享 runner `rent-room-credit-reminder-20261031-02` 精确复验 `PropertyCreditsReviewTests/testXiaodaReminderOnlyForCreationWithNoCredits`，1 项通过、无失败/跳过。`.xcresult` 为 `/Volumes/mac2/codex-builds/rent-room-credit-reminder-20261031-02.xcresult`；设备同下，2 张原图均为 1178×2556。主 agent 已查看新的不足点数截图，确认使用 think 资源。最新原图、来源清单、日志和收据在下述证据目录的 `think-v2/` 子目录。
- 第二版只改两端提醒的 pose 值；其余组件 JS、样式、测试、购买及状态逻辑不变，因此复用第一版其他 2 个 UI 方法及 4 项微信组件测试。微信构建与官方 wcc 21 / wcsc 23 再次通过。没有再次占用已隔离的微信实例，新版微信实际渲染仍缺失。初版截图只保留为历史证据，不代表用户认可的表情。
- 代码/截图 SHA：`0a74d02e138010ef52b812e6480c7254c3e2a852`，工作树干净。共享 runner `rent-room-credit-reminder-20261031-01` 开发批次 3 个精确 UI 方法全部通过、无失败或跳过：新增 `PropertyCreditsReviewTests/testXiaodaReminderOnlyForCreationWithNoCredits`，以及该类既有 `testLocalizedPricesRulesAndPurchaseCancellationPreserveBalance` 和 `testUnavailablePendingAndRestoreFailureDoNotGrantCredits`。未跑全套。
- 新用例确认气泡文案、打字完成、位于余额上方、购买按钮可触达；购买中/取消后仍显示；点数到账后隐藏；设置零余额不出现。既有两例验证共享组件的中英文价格、取消、不可售、待确认与恢复错误未受影响。iOS 英文新提醒为展示文本，未单独截图验收。
- `.xcresult`：`/Volumes/mac2/codex-builds/rent-room-credit-reminder-20261031-01.xcresult`；iPhone 14 Pro / iOS 18.3.1，UDID `8F178971-C203-4690-A83B-253046EACBB1`；9 张原始附件均为 1178×2556。主 agent 查看新增提醒、到账后隐藏、普通零余额三个关键状态，文字完整、购买按钮可见。截图中的状态菜单和底部计数仅属 DEBUG 预览，不是正式页面。
- 微信组件 4 项 Vitest 通过，新增零余额提醒不阻断购买/恢复回调；正常构建与官方 wcc 21 / wcsc 23 通过。独立预览工程复用真实 xiaoda 组件、资源及打字器，未制作替代截图。
- 微信共享池 run `7d37fb068ce34c65bc2f6d445bd8c1db` 在预览工程健康检查报 `App service health timeout`，回调尚未启动，无新增截图/点击证据。槽位 3 被 runner 隔离并保留进程，未重启或清理其他任务。该失败不认定为小搭业务逻辑缺陷，也不以单测代替渲染验收。
- 日志、计划、命令、去令牌 iOS receipt、微信失败收据和截图清单：`/Users/pc/.codex/visualizations/2026/10/30/01a18c24-c384-7503-aa95-42333779ae5e/property-credits/xiaoda-reminder-20261031/`；关键截图 `credits-xiaoda-shortage.png`。iOS runner PID 83092 已结束并释放租约。远端 main 仍为 `1f26f8e04088fa8865431e5c590dd1179ab98c84`。
- 本轮未改正式路由、支付、扣点、迁移、生成工程或 project.yml。后续仅文档更新，不影响上述证据。PR 继续草稿，尚未合并、部署或发布。

## 新建房源不足点数购买入口（2026-10-31）

- 用户要求该入口也删除小饼干。源码核实：正式 `HomePage.home.add → CapacityPage → PropertyCreditsSurface` 已使用批准的第 4 版；小程序 `beginHouseAction → capacity?intent=1` 同样使用统一点数组件。本次未增加新布局或更改扣点、购买、恢复逻辑。
- 删除废弃的 iOS 小饼干容量组件实现；旧 `capacity` 评审路由和无需账号的购买预览改为复用 `PropertyCreditsSurface`，移除投喂话术及人物区域。原显式 DEBUG 路由仍可访问，不进入正式用户流程。历史本地化字典不影响显示，已无调用方使用小饼干条目。
- 代码证据 SHA `aff017bc48bfaa7cc6f0b5b1879a5eab15a82e10`；运行时工作树干净。共享 runner `rent-room-shortage-ui-20261031-01` 通过 **2 UT + 4 UI**，无失败、跳过。这是开发批次，执行了本次全部新增/修改的 UI 方法；未跑全套。
- UT 精确选择 `LegalResourcesTests/testLocalReviewRequiresExplicitKnownRoute` 与 `ComponentLogicTests/testReviewHostRequiresExplicitKnownSurface`，验证原调试入口仍须显式启用。
- 新增 `CapacityBusinessUITests/testNewPropertyAtZeroCreditsShowsPointPurchaseAndCanReturn` 实际点击首页新建：余额 0、购买按钮“¥9.90 购买 10 点”、规则、无小饼干/迁移提示/先等等；返回保留原记录且不创建房源，再次进入仍是 0 点。此用例增加既有正式流程的验收，未将原已正确的正式入口描述为新修复缺陷。
- 修改并通过的 UI 用例为 `CapacityReviewTests/testPurchaseBusyAndCancellationKeepCreditsWithoutAccountControls`、`testUnavailablePendingRestoreFailureAndZeroCredits`、`LocalSettingsReviewTests/testAccountFreePurchasePendingAndNetworkFailurePreserveDisplayedCredits`，覆盖两条旧预览路由共用新组件后的购买中/取消、不可售、待确认、恢复失败、零余额，无账号要求。
- iOS 最终选择按风险排序为上述正式入口、旧路由不可售/待确认、无需账号预览共 **3 个 UI 方法**；直接复用同 SHA 开发批次的通过结果，不重复启动最终测试。第四个开发方法保留为补充证据。前轮 21 UT、支付恢复/重启/原表单续接 UI 的业务输入仍等价：`cdcef579..aff017bc` 无支付、store、桥接、迁移、正式页面或 `PropertyCreditsSurface` 变化；仅预览组件替换与测试变动，旧业务测试的启动参数、动作和断言默认分支不变。
- 微信新增 `capacity-navigation` 用例验证耗尽免费点数后新建进入同一购买页、保留记录和原生返回栈。组件回调与导航共 9 项最终通过：第一批 8 项通过，新增项最初因夹具写死免费 2 点（当前访客为 1 点）在前置创建处失败；改为读取实际初始点数后该精确用例通过，5 项未选择。保留失败日志，该失败不属于业务缺陷复现。首批其他 8 项输入未改变，因此复用结果。小程序正式源码与构建输入未改，前轮编译/渲染证据不受影响；真实购买/刷新点击仍待验收。
- `.xcresult`：`/Volumes/mac2/codex-builds/rent-room-shortage-ui-20261031-01.xcresult`；设备 iPhone 14 Pro / iOS 18.3.1，UDID `8F178971-C203-4690-A83B-253046EACBB1`；6 张原始截图均为 1178×2556，主 agent 已逐张检查。正式入口无卡片外框、人物、迁移说明、调试字样；剩余点数、规则及购买按钮均可见。截图中的价格与余额使用隔离 fixture，不是真实支付证据。
- 完整命令、计划、日志、附件清单及去令牌 receipt：`/Users/pc/.codex/visualizations/2026/10/30/01a18c24-c384-7503-aa95-42333779ae5e/property-credits/shortage-entry-20261031/`。正式入口原图为 `new-property-zero-credits-purchase.png`。runner PID 38589 正常结束，租约与 slot 已释放；receipt 记录排队 0.831 秒，构建约 28.4 秒，测试阶段约 56.2 秒。
- 构建继续通过共享 runner 与仓库 wrapper；XcodeGen 2.45.4，`project.yml` 未改，未提交生成工程。远端 main 仍为 `1f26f8e04088fa8865431e5c590dd1179ab98c84`。后续只补文档，不改变测试输入。仍未合并或发布。

## 已确认的产品规则

- 小程序 ¥1.99 / 10 个房源点数；iOS 中国大陆 ¥9.90 / 10 个，美国 $1.99 / 10 个。
- 只有通过“新建房源”成功保存一套新房源才消耗 1 点；取消和保存失败不扣点。
- 导入和从归档恢复不扣点，也不受零点数限制；归档、删除不返还已使用点数。
- 小程序既有用户的剩余容量一次性转换为点数：`max(0, 当前免费容量 + 已购包数 × 10 - 当前未归档房源数)`。转换保留既有房源、答案、问题、备注和媒体。
- iOS 已明确选择继续本机方案，换机、重装不保证恢复消费记录；小程序登录后使用账号共享钱包，未登录免费使用仍在本机。重复刷新、恢复购买不得重复发点。

## 兼容迁移与联网扣点（2026-10-31）

- 后端先部署兼容协议，再发布新版小程序。不批量迁移。旧版继续容量；同一微信账号首次进入新版后按当时本机未归档房源数迁移一次；新版新增用户从免费点数开始。旧版新注册仍使用旧协议。
- 新版请求 v3，需后端 `creditVersion:1` 和合法 credits 响应；旧后端不能让新版静默恢复到容量计费。旧订单保持容量身份，新订单保持点数身份，跨版本重试同一订单不能改变种类。
- 房源数在访客关联之前冻结，访客关联与导入不扣点。后端核实购买数量，但没有房源内容，无法验证本机占用；不同旧设备保存不同记录时，以首次成功迁移设备为基数。旧设备后续创建不会扣新钱包，这是容量与点数过渡并行的边界。
- 登录后新建使用持久化请求日志、预留、原子保存、确认。网络结果不明沿用原请求号；保存失败释放；保存成功即使确认回包丢失也不重复扣点。保存凭据保留在本机，删除或恢复上一版房源不能返还点数。
- 已登录会话内编辑、导入、归档恢复仍可离线；冷启动仍沿用原有微信身份验证，不放宽账号目录访问。未登录免费使用与 iOS 均保持本机规则。
- 预留不会自动过期释放，以免把已保存房源退点。本机数据被清除后丢失未完成日志，需要人工核对，不能承诺自动找回。
- 小程序账户不再使用本地 property-credits 文件作为余额真源；该文件仍服务于访客和 iOS。房源 ZIP 不携带钱包或扣点请求日志。
- 上线与回滚细节见配套 model_server 的 `business_api/docs/rent-room-credits-rollout.md`：已有点数订单后不得回滚到会把所有 paid 订单当容量的旧后端。

配套后端：[model_server PR #99](https://github.com/Hayden-Chang/model_server/pull/99)，客户端：[rent_room PR #105](https://github.com/Hayden-Chang/rent_room/pull/105)。未操作真实用户数据、真实支付或生产发布。

本轮验证：

- 客户端业务代码候选 `6b534ea10922c57be1fb11109d11231cd71f21bb`：19 个定向 Vitest 文件共 305 项通过。范围覆盖全部本次修改的单测，以及共享 store、迁移/支付、身份隔离、导航、访客关联、导入/媒体和首页引导的受影响用例。
- `0974d7e1b61652137b4a4ab94a8a4e9ac262b2d1` 仅为页面组件增加稳定 ID 并修正 E2E 注入回调；305 项的其他源码、测试、构建输入相同，复用前项证据。受影响组件、容量页面和导航 3 文件 21 项再次通过；官方 wcc 21 / wcsc 23 通过。
- iOS 共享 runner `rent-room-credit-compat-20261031-08`：21 UT + 3 UI 全部通过，源码 `fd5083d67ecacd9d45d490c2e432be330cef5700`，之后仅微信独有模块、微信测试和标记变化，iOS 源码、共享 store、生成 bundle、测试与配置等价。`.xcresult` 位于 `/Volumes/mac2/codex-builds/rent-room-credit-compat-20261031-08.xcresult`；iPhone 14 Pro / iOS 18.3.1，UDID `8F178971-C203-4690-A83B-253046EACBB1`。租约正常结束，6 张原始截图已导出，确认已购与零点数页面维持批准的布局。
- Node native bridge：`app-review`、`bridge-performance`、`quiet-guidance` 共 18 项，加 `currency-review` 中精确选择的创建回滚用例 1 项，共 19 项通过。
- 后端代码候选 `c5f778419db2c09bd862dd771aad00326c267811`：87 项定向测试通过，包括旧库和旧客户端协议、退款、迟到订单、并发、幂等、限流及 Apple 身份隔离。之后仅文档变化。
- 审查发现已保存房源删除后，同名重试可能返回已删除 ID。隔离副本在修复前实际返回该 ID 而非报点数不足；修复后包含此用例的 305 项通过。失败与通过日志保留。
- 第一轮导航测试因构建未配置测试 API 无法登录；夹具改为显式构建测试 API，并等待异步创建。一次检查与构建同时操作 dist 导致文件缺失，此运行不计业务失败；后续串行重建和完整定向集合通过。
- 微信共享池最终 run `f5197c6b17114f709aca786c5c339633`，源码 `0974d7e`：隔离微信身份/余额夹具进入正式点数页成功，真实截图显示 7 点、¥1.99 购买 10 点、刷新点数；无小饼干、卡片外框或转换提示。随后 `page.$('#property-credits')` 超时，未执行购买/刷新点击，因此只确认渲染，不宣称交互或真实支付通过。SDK 0.12.1、DevTools 2.01.2510290、基础库 3.17.3。槽位 3 已正常归还、常驻实例保留。
- 前四轮失败日志全部保留：前两轮注入异常，第三轮拿到精确堆栈，异常在测试脚本复制夹具时进入 WASubContext 的 Proxy.parse；去除非必要复制后登录成功。第四轮标签选择器未定位组件，加入稳定 ID 后组件及截图通道通过，第五轮受 Page 查询超时阻塞。调试仅改测试回调和组件 ID，未更改业务逻辑或共享工具。MDN [instanceof 异常说明](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Errors/invalid_right_hand_side_instanceof_operand)辅助区分构造函数检查错误；具体定位以现场堆栈为准。
- 当前 GitHub 未提供 statuses/workflow runs，不能声称远端 CI 通过。主 agent 在 PR 推送后独立审查了最终文件范围、兼容协议、迁移基数、扣点提交/取消、账号切换与恢复，未发现剩余阻断性业务代码问题。

完整计划、命令、日志、脱敏收据和截图集中在 `/Users/pc/.codex/visualizations/2026/10/30/01a18c24-c384-7503-aa95-42333779ae5e/property-credits/compatibility-20261031/`。

## 实时只读核实

2026-10-30 通过 `asc iap pricing summary --iap-id 6828697996 --territory USA|CHN` 核实商品 `com.keeline.xunju.ios.capacity10` 为 CONSUMABLE，美国 1.99 USD、中国 9.9 CNY。现有参考名仍为 `10 Property Slots`，尚未写入 ASC。正式 UI 继续使用 `Product.displayPrice`；组件截图中的价格来自明确标记的测试夹具。

现网小程序 v2 `/catalog` 返回 `capacity:{version:2,freeLimit:2}`、`product:{id:room_capacity_10,price:199,size:10}`，`available` 和 `iosAvailable` 均为 true。订单、账号与购买权益在服务端；房源和当前占用保存在本机。因此剩余容量转换必须由新版读取本机记录完成，不能靠服务器批量计算当前余额。

## 组件范围

- iOS `PropertyCreditsSurface` 接收余额、Apple 本地化价格、等待/错误状态和回调。独立 `--component-review property-credits` 路由只在 DEBUG 编译，不创建 AppWorkspace、不读取真实记录、不调用 StoreKit 或网络。
- 小程序 `components/property-credits` 是相同文案的展示组件。独立工程在 `tests/fixtures/property-credits`，由 `node tests/e2e/build-property-credits-review.mjs` 生成到忽略目录 `artifacts/property-credits-review`。正式 app.json 不注册测试页面。
- 当前文案按用户最新标注：余额下方居中显示“1 点 = 1 套新增房源”，商品卡片的外框、背景、标题和旧说明全部删除，只保留购买按钮；恢复购买仍为次要入口。无小饼干或容量转换提示。用户批准后已接入正式页面，以下历史截图仍保留原始来源。

## 正式实现与最终验证（2026-10-30）

- 代码候选 `0f3d9b436a85f0d4213fd11c72cfc3bfc94c2541`，基线 `abc042ea3c8cecc39be32a891ea3a47cd667deda`。整合主线后，两个 DEBUG 组件路由均保留，首页长按提示未丢失。后续仅更新本文，可复用该代码候选的执行证据。
- 共享 `property-credits.js` 记录免费点数和购买身份对应的消费数；历史活跃房源仅在首次迁移时计入已用额度。导入、替换、访客关联、归档与恢复不改消费数；只有 `store.add` 成功保存扣 1 点。旧的超过容量状态转换为 0 点，不产生历史欠账。
- `property-credits.json` 不随房源 ZIP 导出。它与房源文件通过提交标记协调：准备日志失败或房源写入失败会回滚；房源已提交而日志收尾失败时视为创建成功，后续编辑保留提交标记，重启可完成收尾。恢复上一版房源仍保留当前消费数。
- iOS 继续只用本机 StoreKit 购买记录、余额缓存及消费文件；首次绑定和切换 Apple 购买身份保留各自的已用点数。购买产品 ID、价格及服务器协议未改变。新版页面使用 Apple `displayPrice`，没有小饼干、商品卡外框、迁移提示或购买后感谢动画。

验证映射与结果：

- 共享存储、迁移、导入/媒体、账号目录、支付及主线首页组合：17 个定向 Vitest 文件，287 项通过；构建及官方编译通过（wcc 21 / wcsc 23）。没有跑全量应用单测。
- iOS JavaScript 桥接、币种创建和评分计数：15 项 Node 测试通过。
- 最终共享模拟器 run `rent-room-property-credits-20261030-07`：21 个精确 UT + 3 个 UI 方法通过。UT 覆盖本机恢复/退款/账号切换与消费幂等、损坏文件恢复、零点数导入/归档恢复、原生桥接及冲突后的组件路由；UI 覆盖购买待确认与重启恢复幂等、购买后续接原新建表单、零点数禁止新建但允许归档恢复并保留编辑。
- 最终 `.xcresult`：`/Volumes/mac2/codex-builds/rent-room-property-credits-20261030-07.xcresult`；计划、完整命令、日志、脱敏 runner receipt、原始附件与来源清单集中在 `/Users/pc/.codex/visualizations/2026/10/30/01a18c24-c384-7503-aa95-42333779ae5e/property-credits/integration/`。设备为 iPhone 14 Pro / iOS 18.3.1，UDID `8F178971-C203-4690-A83B-253046EACBB1`，截图 1178×2556。
- 最终 6 张原始截图已逐张检查：正式购买页无卡片、迁移提示或调试入口；等待购买不发点，确认及重启后均为 12 点；零点数页面和归档恢复结果与断言一致。
- 开发 run 05（`39f0f1ffbd0eb7bcc4352047c2c13ce4fca5d29c`）四个正式页面 UI 方法全部通过；退款/取消/商品不可用截图属于该 SHA 的补充证据。其 19 个 UT 曾有 2 项失败：一个测试 ID 不符合 Apple 数字 ID 格式，另一个发现损坏 JSON 提前阻断恢复；均已修复并在最终候选验证通过。
- 主 agent 推送后复查发现日志收尾失败时，后续普通编辑可能丢失提交标记。新增回归在修复前实际重启得到 1 点（期望 0），修复后全部 12 个点数存储用例通过；失败和成功日志均保留。该修复触发最终 run 07，未把 run 06 的绿色结果冒充最终代码证据。
- 微信最终批次曾有一个 Node worker 在 `capacity-policy.test.js` 执行时 SIGSEGV。保留原日志后将进程并发限为 2，原 17 文件完整通过；最终候选再次通过同一集合。
- 微信池 run `84d37f2e999e48be8e21674c772e9fd5` 在启动健康检查时失败（`App service health timeout`），业务回调未开始、没有新截图或点击证据；池已自动隔离槽位 3，另两槽同样不可领用。未手工重启、退出、抢占或清理共享实例。当前源码的官方编译和 VM 用例不等于实际渲染验收。

主 agent 已单独检查远端 PR 文件范围、扣点提交/回滚路径、导入边界、身份切换、备份及组件正式接线，修复上述提交标记问题后未发现新的阻断性代码问题。GitHub 对验证候选未返回远端 statuses 或 workflow runs，不能声称远端 CI 通过。微信可视验收尚缺，PR 不能据此合并或发布。

本次未操作真实用户数据、App Store Connect 商品本地化/参考名、微信商品后台、真实支付或发布后台。后续商品后台展示名可改为“10 个房源点数” / “10 Property Credits”，原商品 ID 保持兼容；当前 ASC 参考名仍是前述只读核实结果。iOS 换机/重装消费记录恢复不保证，按用户已确认的本机方案执行。

## 已批准的第 4 版组件证据（历史）

- 证据源码：`27cb379afe3878ff17c46c4dc3ab46657bd8e050`，测试时工作树干净。后续仅修改本文，不改变截图来源。
- 精确运行两个 `PropertyCreditsReviewTests` 方法，均通过、无跳过。中英文新说明均位于余额下方、购买按钮上方；商品标题不存在，购买按钮大小和回调状态正常。两条既有路由 UT 及三条微信组件回调测试沿用 `f9aad34` 通过证据：本轮未改路由、宿主、微信 JS 或这些 UT；布局由新一轮 UI 证据验证。
- `.xcresult`：`/Volumes/mac2/codex-builds/rent-room-property-credits-20261030-04.xcresult`。
- iPhone 14 Pro / iOS 18.3.1，1178×2556。7 张原始截图已逐张检查，主界面无卡片外框和旧标题；中英文、零余额、购买中、待确认、不可售及恢复失败均显示新布局。测试状态菜单仅属 DEBUG 宿主。
- 原图、来源 SHA/尺寸/哈希、计划、命令、日志和脱敏收据：`/Users/pc/.codex/visualizations/2026/10/30/01a18c24-c384-7503-aa95-42333779ae5e/property-credits/layout-v4/`。
- 微信 `npm run build`、`npm run check` 通过（wcc 21 / wcsc 23）；共享池状态仍为三个 `busy-or-quarantined`，没有新一轮实际渲染。未重启或抢占共享实例。
- 本机 Git 只读传输检查超时，因此第 4 版代码保存在本地任务分支，PR #105 远端仍为 `f9aad34`；未宣称已同步。需传输恢复后补推，再审查新远端 head。
- 主 agent 已审查本轮差异，范围仅为两端布局、受影响的 UI 断言与本文。正式页面、支付、扣点和迁移尚未接入；仍需用户确认。最大字号、iPad、真机及真实支付未验证。

## 第 3 版历史布局与证据

按用户反馈重新布局：取消余额卡边框，将剩余点数居中放大；购买卡保留“10 个房源点数”和一行规则，按钮横向铺满；删除“先等等”，恢复购买记录作为下方次要入口。使用现有主题色，正文采用系统字体样式；购买按钮至少 52 pt，恢复按钮至少 44 pt。

- 证据源码：`f9aad34208954788cb4b8d6d5ac921113a61e695`，执行时工作树干净。其后仅更新本文验证记录，组件、主题、宿主、测试、构建配置无变化，可复用该 SHA 的截图。
- iOS 共享 runner `rent-room-property-credits-20261030-03`：2 UT + 2 UI 全部通过，无失败、跳过；验证中国/美国英文、购买回调与取消、零点数、不可售、等待支付、恢复失败，并检查购买按钮宽度和高度。
- `.xcresult`：`/Volumes/mac2/codex-builds/rent-room-property-credits-20261030-03.xcresult`。
- iPhone 14 Pro / iOS 18.3.1，UDID `8F178971-C203-4690-A83B-253046EACBB1`。7 张原图均为 1178×2556，已由主 agent 逐张检查，无文字遮挡或截断；页面底部回调信息和导航栏“评审状态”仅属 DEBUG 宿主。
- 原图、来源清单、计划、命令、日志和脱敏 runner 收据：`/Users/pc/.codex/visualizations/2026/10/30/01a18c24-c384-7503-aa95-42333779ae5e/property-credits/layout-v3/`。
- 小程序 `npm run build`、`npm run check` 和 3 条组件 Vitest 测试通过；独立测试工程已重建。池 run `fcf28f534956450db98a35bbe4ef2959` 未取得槽位，返回 `No free slot; active/orphan instances were not stopped`，因此没有新布局的微信实际截图或真实点击证据。未操作其他任务进程。
- 本轮没有验证最大字号、375 pt 真机、iPad、深色系统设置或真实支付。iPhone 项目配置仅支持竖屏。组件采用动态字体和可滚动宿主不等于以上场景均已验收。
- 主 agent 源码审查：差异仅为展示组件、DEBUG/隔离测试宿主、精确回归测试和说明；没有正式页面接线、记账、迁移或商品配置写入。草稿 PR 不可据此合并/发布。

## 历史验证与证据

以下为被用户要求修订的第一版证据，不代表修订版已通过：

iOS 证据源码：`14861891199e11c7abdbbc4c6dbdfdaa409d25cb`。共享 runner `rent-room-property-credits-20261030-01` 完成 2 UT + 2 UI，全部通过、无失败或跳过；仅验证展示/按钮回调，不是扣点、迁移、支付或恢复的端到端证据。

- UT：`UtilityComponentTests/testReviewRoutesRequireExplicitKnownDebugArgument`、`ComponentLogicTests/testReviewHostRequiresExplicitKnownSurface`。
- UI：`PropertyCreditsReviewTests/testLocalizedPricesRulesAndPurchaseCancellationPreserveBalance`（中国价格、英文美国价格、购买等待/取消、零余额）；`testUnavailablePendingAndRestoreFailureDoNotGrantCredits`（不可售、待确认、恢复失败）。所有新增 UI 方法已执行，未跑全套。
- 设备：iPhone 14 Pro / iOS 18.3.1，UDID `8F178971-C203-4690-A83B-253046EACBB1`，截图 1178×2556。
- `.xcresult`：`/Volumes/mac2/codex-builds/rent-room-property-credits-20261030-01.xcresult`。
- 计划/命令/日志：`/private/tmp/property-credits-evidence/plan-01.json`、`run-01.sh`、`run-01.log`。
- 持久原图、来源 SHA/测试/附件名/尺寸/哈希、汇总和目录回读：`/Users/pc/.codex/visualizations/2026/10/30/01a18c24-c384-7503-aa95-42333779ae5e/property-credits/`。
- XcodeGen 2.45.4 通过确定性校验；`project.yml` 未改，生成工程未提交。runner 使用自身按工作树隔离的缓存目录，未手动复用或操作其他设备。

主 agent 已逐张查看 7 张原图，中英文文案和按钮均完整可见，忙碌/等待状态禁用购买，错误状态保留余额。标题右侧“评审状态”和底部回调次数均为 DEBUG 宿主，不进入正式页面。

小程序官方 `wcc` 和 `wcsc` 对组件及测试页面编译通过；展示回调的 3 条 Vitest 边界用例另存于 `tests/property-credits-component.test.js`。第一轮 `f10f66a83e1e4258b178a5bce4c8af71` 排队后取得槽位，但 Page 协议在 90 秒内未响应。第二轮 `ba1fbdf034bc4950b3d08385ab85bbb2` 改用 evaluate + screenshot，已完成旧版组件四种状态的实际渲染，真实点击不计作通过。用户已要求修改这些文案，因此旧图不作为当前版验收。未手工重启、解锁或抢占其他任务实例。

## 早期组件阶段的待办（历史）

以下保留组件阶段的原始门禁记录；当前状态以本文开头为准，用户已批准并已完成正式接入。

依据 [ios-ui-component-review-gate](/Users/pc/.codex/skills/ios-ui-component-review-gate/SKILL.md)：

> Do not integrate it into the complete page or continue the downstream business flow before approval.

需用户确认点数组件后再接入完整页面与业务。后续必须覆盖一次性旧余额迁移（含免费/已购/超额/离线）、新建成功恰好扣一点、失败回滚、零点导入/恢复、归档/删除不返点、重启保留、购买/恢复/退款幂等、账号目录切换及备份不能覆盖消费账本等边界。消费记录需要与房源持久化的提交结果协调，不能靠页面按钮点击计数。

还需补新版微信实际截图与真实点击，以及用户对当前布局的确认；正式业务接入后重新按最终 diff 选择测试和审查 PR。迁移真实用户数据、部署、合并、上传、商品本地化/参考名变更及发布均尚未执行。
