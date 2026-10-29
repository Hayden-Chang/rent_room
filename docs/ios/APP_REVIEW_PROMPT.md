# iOS 系统评分邀请

需求日期：2026-10-30。PR：[#93](https://github.com/Hayden-Chang/rent_room/pull/93)。

## 产品规则

- 停止首次返回首页时自动弹出“使用感受”问卷，设置里的“使用反馈”入口保留。
- 本机当前身份累计成功新建 3 套房源，或一次新购买经服务端确认到账后，满足系统评分请求条件。
- 创建计数与房源保存同事务，失败一起回滚；归档、删除不减，导入、归档恢复不增。计数只需保留到阈值 3。
- 旧版本没有累计创建记录，无法还原已删除或导入记录的来源，因此从本版本开始累计。
- 普通历史购买恢复、已有额度刷新、取消、未批准及退款不产生新评分邀请。本次新购买的待批准或待确认记录会持久化；重启后确认成功仍可满足条件。待批准订单仅接受发起购买后产生的已验证交易，历史订单恢复不能提前消耗资格。
- 两条条件共用一次 `requested` 标记，不以主动反馈内容筛选用户。游客登录时将计数和标记合并一次，沿用 `guestClaims` 防重复。注销后的新游客及其他账号仍是独立本机身份；没有跨设备同步。
- 在首页无导航/弹层，或独立购买页支付及感谢状态结束时，前台稳定 2 秒后调用 Apple `RequestReviewAction`。继续新建/恢复流程优先完成，评分推迟至首页。
- 请求前持久化标记；系统未显示或用户关闭都不立即重试。标记表示“已请求”，不表示已打分。

Apple 控制最终显示：[RequestReviewAction](https://developer.apple.com/documentation/storekit/requestreviewaction)。开发环境用于检查原生界面，TestFlight 不显示；开发截图不能证明正式版首次必弹。真实支付、正式商品及 App Store 线上评分另行验收。

## 实现范围

`ios/Core/app-review.js` 保存资格与请求状态；`bridge.js` 仅为 iOS 传入 `onHouseCreated`，让新建计数与保存同事务。小程序的默认回调不改变原有状态。原生购买控制器区分新购买及历史恢复，在服务端验证和容量保存成功后记录资格，评分记账失败不阻止交易完成。`AppReviewPrompt` 在 Home/Capacity 的安全显示点消费一次资格。

## 定向验证映射

| 生产边界 | 测试 |
| --- | --- |
| 创建阈值、删除、重启、保存失败、导入、游客迁移及消费幂等 | `node --test ios/tests/app-review.test.mjs`，6 项 |
| 小程序默认存储契约 | `tests/model.test.js` 的持久化、失败重试、损坏阻止写入、归档只读、归档删除，5 项 |
| 新购买成功、取消/待批准/验证失败/退款、历史恢复、延迟确认跨重启、评分保存失败 | `XunjuTests/AppReviewTests`，7 个精确方法 |
| StoreKit 验证交易保留实际购买时间，避免历史交易匹配待批准新订单 | `NativeStorefrontTests`，1 个修改方法 |
| 前后台重复确认、确认中切账号、容量保存失败与恢复、fixture 参数隔离 | `CapacityBusinessTests`，7 个精确方法 |
| NativeStore 创建/保存回滚与现有状态保护 | `NativeStoreTests`，3 个精确方法 |
| 游客迁移、重试、设置媒体及重复 ID 保护 | `IdentityScopeTests`，4 个精确方法 |
| 第三次创建及购买后原生评分、关闭和重启不重复、手动反馈保留 | `AppReviewUITests`，2 个方法 |
| 原首次返回问卷改为设置主动进入、保留草稿和后续容量流程 | `InspectionBusinessUITests`，2 个修改方法 |
| 首次返回无问卷后继续 Apple 登录流程 | `AppleLoginUITests`，1 个修改方法 |

开发阶段执行全部 5 个新增/修改 UI 方法；最终 head 只选系统评分两条入口及首次使用流程 3 个方法，其他结果按源码等价复用，不跑完整 UI 套件。准确选择器在本机计划 `/private/tmp/rent-room-rating-20261030/dev-plan-e.json`。

## 当前证据

- Node 24.19.0：6 项核心测试、5 项小程序相关测试通过；其余 15 个无关用例由精确过滤排除。
- XcodeGen 工程编译通过；工程真源仍是 `ios/project.yml`。
- 代码 `885472c59d403be215536f86b846050272a3b580` 的 `development-e.xcresult`：iOS 26.5，21 UT 通过，1 StoreKit UT 因未启用本地商品配置失败；5 UI 中 Apple 登录通过，其余 4 项失败。
- StoreKit 精确补验 `storekit-f.xcresult`：现有 `XunjuStoreKitTests` scheme，iOS 18.3.1，1 UT 通过，实际本地 StoreKit 交易保留购买时间。环境与 scheme 均和 e 不同，不混为同一次运行。
- 26.5 的第三创建实际状态 `created=3, requested=true`，storekitd 已收到 requestReview 并生成 token；录像最后仍为房源页，没有可见评分内容。独立 `purchase-g.xcresult` 已点击购买并确认 `0 / 11 套`，仍没有评分弹窗。不能把这些结果当作原生界面通过。
- 首次反馈回归的失败是切换 tab 后立即使用分支查询误选 `home.first`，改成等待确定的 `home.add`；详细清单的数字键盘 AX 有数字键但录像没有软件键盘，改用聚焦字段的标准 `typeText` 输入，保留小数键类型及持久化值断言。
- 对照运行 h（`c427cb6`）：iOS 18.3.1，21 UT 通过；首次使用/手动反馈 UI 通过，两个评分 UI 的真实系统弹窗已出现，但旧查询错误地将其当作 `Alert`，导致断言失败。按实际 AX 的标题、评分星级和“以后”按钮修正查询，未改变产品代码。
- 最终运行 i（`9d465c93a0d30d3be354a5e0684b13e454ec9fc2`）：iPhone 14 Pro / iOS 18.3.1（22D8075），21 UT + 3 UI 全部通过，0 失败/跳过。两条评分入口均验证真实 StoreKit 界面、关闭后不重复；创建路径额外验证重启幂等和手动反馈。购买 UI 使用业务 fixture 模拟到账，不能当作线上真实支付通过。
- i 仍用共享 runner、相同 poolRoot 和 3 并发上限，仅在临时配置中将设备前缀收窄为池内现有 iOS 18 兼容设备。没有改共享基础设施或强占其他设备。[精确计划](evidence/app-review-20261030/final-plan.json)与[退出 0 的执行回执](evidence/app-review-20261030/final-receipt.json)已保留。
- 证据复用：`885472c` 至最终测试 head 的产品代码未变，f 的 StoreKit 方法及配置未变，e 的 Apple 登录方法未变；Node 核心及小程序源码自 Node 通过后未变。i 后提交仅补文档和原始截图，不改变构建输入中的产品/测试源码。不是全套测试通过。
- **未通过项保留**：h 的详细清单/模板/归档 UI 在 `templates.edit.simple` 后仍停留于模板列表，失败于 `setup.toggle.周边与小区`；后续模板修改及旧房源归档断言未执行。该模板产品源码相对基线无改动，另一独立性能任务也复现同一导航失败，但本 PR 不据此把该用例标记通过。全部 5 个新增/修改 UI 方法已执行，其中该长流程仍未通过，因此 PR 保持草稿，不可称为全部回归完成。
- 全部日志、计划、录像和 `.xcresult` 在 `/private/tmp/rent-room-rating-20261030/`。主 agent 已复核最终产品和测试差异；未合并、安装真机、提交审核或发布。
- 历次预执行记录：a/b 排队前取消修正测试前置条件及延迟购买资格；c 因排队期间新增文档触发快照校验而退出；d 在依赖解析时受全局 Git SSH 重写影响退出 74。后续进程级 `GIT_CONFIG_GLOBAL=/dev/null` 已解决依赖读取。

## 原生界面证据

以下为运行 i 的原始 XCUITest 截图，非自绘评分框。开发模拟器的系统弹窗显示占位图标；不代表 App Store 正式图标验收。

第三次成功创建后（此前两套已归档，证明使用累计创建数）：

![第三次创建后的系统评分](evidence/app-review-20261030/after-third-creation.png)

购买确认、感谢状态结束后：

![购买后的系统评分](evidence/app-review-20261030/after-verified-purchase.png)

[仍可从设置主动打开反馈](evidence/app-review-20261030/manual-feedback-retained.png)。
