# 首次使用免登录整改

基线：`45fc14b8546d65b44fe20f37af2b01988821083c`，2026-10-19 已重新从远端核实。

## 目标与结果边界

针对审核第一项“未体验功能即要求授权登录”，移除首页强制登录流程。此改动不处理第二项类目复核，不表示平台审核已通过。

- 首次进入无需微信身份验证，可使用2个有效房源的本机记录、检查、影像、对比、归档及备份功能。
- “我的”提供可选登录，未登录不显示头像和昵称授权控件。容量页先说明登录用途，再由用户点击登录；登录成功只刷新页面，由用户另行确认购买。
- 账号认证、支付签名、金额及服务端权益核验仍保留；未登录不会读取其他账号的记录或权益。
- 未登录目录关联至验证后的账号。先记录事务并保留来源，再复制媒体及原子合并状态；批次幂等、重复ID、复制及提交失败均有测试。来源目录保留为恢复副本，不由其他未登录会话复用。
- 合并后超出容量时保留所有记录，新增和恢复仍受容量限制。
- 自动恢复登录每次冷启动最多尝试一次；失败后使用免费本机记录，不因照片选择器返回反复开始认证。

## 回归与验证

新增 `guest-runtime.test.js` 首轮6项在修改前全部失败，首页为空service、未登录不能记录为直接失败原因；原始日志 `apps/wechat/artifacts/optional-login/before.log`。

新增“失败恢复后从照片选择器返回”用例在修复前失败：返回前台触发第二次验证，当前service变成null。原始日志 `picker-before.log`；修复后包含在最终通过集内。

按最终边界选择17个文件，共185项全部通过；没有执行全量测试。完整日志 `final-unit-v3.log`。

| 变化边界 | 精确选择的测试文件（相对 apps/wechat/tests） |
| --- | --- |
| 新增免登录、登录时机与首用入口 | guest-runtime.test.js |
| 未归属目录关联、媒体、原子失败及幂等 | guest-storage.test.js |
| 会话、账号隔离、过期、退出与异步回调 | account-runtime.test.js、account-storage.test.js、account-profile.test.js |
| 购买授权及容量页直接消费者 | billing.test.js、capacity-runtime.test.js |
| 共享App/service及路由守卫消费者 | runtime.test.js、detail-navigation.test.js、onboarding.test.js、root-group-runtime.test.js、unanswered-group-runtime.test.js、speed-test-page.test.js |
| 设置、文件选择器与导入导出 | settings-simplification.test.js、platform.test.js、transfer.test.js、transfer-page.test.js |

原来“必须拦截未登录路由、必须出现登录遮罩、移除遮罩后恢复tabBar”的4项测试已由新契约覆盖替换，不再要求不符合审核目标的旧行为。账号隔离、旧回调、资料持久化及错误路径继续保留。

最终命令（先在 apps/wechat 构建）：

```sh
WECHAT_API_URL=https://api.keeline.xyz/api/rent-room node scripts/build.mjs
node node_modules/vitest/vitest.mjs run tests/guest-runtime.test.js tests/guest-storage.test.js tests/account-runtime.test.js tests/account-storage.test.js tests/account-profile.test.js tests/billing.test.js tests/capacity-runtime.test.js tests/runtime.test.js tests/settings-simplification.test.js tests/platform.test.js tests/transfer.test.js tests/transfer-page.test.js tests/detail-navigation.test.js tests/onboarding.test.js tests/root-group-runtime.test.js tests/unanswered-group-runtime.test.js tests/speed-test-page.test.js --maxWorkers=2
node scripts/check.mjs
```

官方检查：12个页面，wcc和wcsc各14文件通过。正常构建配置连接现网API并加载本机地图Key，未放入测试数据根目录或身份夹具。

此前一轮182项仅一个旧详情页导航测试失败：夹具只更改isAuthenticated但未撤销旧service，而未登录现在允许使用。修正夹具以模拟真实账号转换后精确重跑通过。之后因修复照片选择器返回行为，重新执行完整受影响集，185项全部通过；不沿用失败轮作为最终结果。

## 真实渲染与未完成验收

固定池 `ce798e93a8f44af583dcebf15d1e76e3` 已确认初始未认证、页面可用、免费容量2，保存首页、设置及容量页真实截图。没有为此注入登录或账号结果。主agent已查看三张图。

SDK按钮元素协议超时，报告保留 `rendered:true, clicked:false`；没有用调用handler替代点击。另一次原生CUA尝试 `39653dd5a2274da68979eb598d2d5fcf` 因窗口读取超时未能完成点击，helper等待结束后失败。两次原始receipt保持失败。

`tests/e2e/optional-login.cjs` 的 `OPTIONAL_LOGIN_RENDER_ONLY=1` 为显式只渲染模式，只证明页面状态；完整模式仍包含真实按钮点击。`optional-login-native.cjs` 供持有池租约时用CUA点击输入，不将人工完成标记作为点击本身的证据，仍核对实际页面、记录和磁盘保存。

用户确认界面、实际添加/对比/导入导出，以及iOS/Android登录和已购权益恢复仍需验收。本次没有新增实单、部署后端、合入main、上传正式版本或提交审核。合并前遵守AGENTS.md的用户UI审批门禁。

最终源代码审查补充两项关联边界：不同记录复用相同媒体ID时复制目标不可相同；尚无房源但已填写的未登录设置需关联，新账号可继承，已有账号设置保留。两项新增用例在修改前均失败（review-before.log），修复后包含在185项最终通过集内。

干净提交98d0bbe的只渲染验证run `63680e5cd4424c47a377be40ba4a7582` 已通过，clicked仍为false。随后只修改guest-storage的显式登录关联分支及对应测试；首页、设置和容量页的源代码、WXML/WXSS、初始guestStorage路径及测试环境未变。该run没有调用登录或关联函数，故截图对最终界面仍等价。最终正常构建恢复默认数据根目录；运行产物与证据清单记录在ignored artifacts中。
