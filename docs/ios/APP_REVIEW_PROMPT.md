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
- Swift 语法检查与 `git diff --check` 通过；工程真源仍是 `ios/project.yml`，没有修改或提交生成的 Xcode 工程。
- 待验证代码以本次冻结提交及 runner 工作区快照为准。
- 共享 runner：`rent-room-rating-dev-20261030-e`，22 UT / 5 UI；日志 `/private/tmp/rent-room-rating-20261030/development-e.log`。计划已冻结，尚无模拟器通过或截图结论。
- 先前 `a`、`b` 运行均在获得设备前取消，分别修正测试前置条件和补齐延迟购买资格；不是测试失败或通过。`c` 在取得执行机会时因排队期间新增本文档导致工作区快照变化而停止，未执行测试；`d` 在依赖解析时受全局 Git SSH 重写影响退出 74，未执行测试。已验证 HTTPS 可读取 ZIPFoundation 0.9.20，`e` 通过进程级 `GIT_CONFIG_GLOBAL=/dev/null` 避免重写，并补上待批准订单的购买时间匹配边界。
- 主 agent 已审查最终代码差异；无 PR GitHub Actions 运行记录。UI 和最终 head 验收仍待结果，不可合入。
