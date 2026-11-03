# 支付重试与诊断验证（2026-11-03）

## 用户确认的提示文案调整

用户在 2026-11-03 明确要求把两段待确认说明合并成一条红色提示：“支付结果正在确认，请勿重复购买”。组件在 pending 状态只渲染这一条，避免同屏叠加蓝色说明和红色长提示；非 pending 的错误仍使用对应错误文案。只修改组件模板和样式，支付状态处理与后端未改动。

本次增量验证：`property-credits-component.test.js` 和 `capacity-runtime.test.js` 共 **23 项通过**；wcc 22 文件、wcsc 24 文件通过，正常配置包体为 **1,919,539 字节**。其余付款/诊断代码与此前 117 项通过的候选完全相同，复用原结果，未重复运行全部相关用例。日志为 `copy-simplification-tests.log`、`copy-simplification-compile.log`。

当前[待确认预览](evidence/payment-retry-20261103/pending-recovery.png)来自共享池 run `5cbb285b8fed470085bd5ea116537ff7`，仅以测试桩准备页面状态，没有实际扣款。本次文案已获用户明确确认；先前真实点击/原生弹窗/手机支付的验证限制仍保留。

## 复现与修复

原生支付失败后，旧实现仍保存 pending requestId；服务端返回 unpaid 时一直保留本地 pending。刷新后重复购买被拦截，新版点数组件又直接禁用了 pending 按钮。HTTP 200 本身无法说明微信业务调用成功，旧日志也无法把原生错误和某笔订单对应起来。

- 对官方明确失败码，先保留 retryable 标记，再查单；只有服务端确认 unpaid 才解除本地等待，下一次点击创建新 requestId。查单失败仍保留原订单，重载后继续核对。
- 超时、未知、系统及重复订单等不确定结果不自动解除等待。按钮显示“核对付款并重试”；先查单，再提示用户核对是否已扣款或有待处理的苹果付款。用户确认后再次查单，仍为 unpaid 才发起新订单。若已 paid，则使用到账结果，不再创建订单。
- 用户取消确认时保留原 pending；正在处理时仍禁止连续点击。不会复用旧签名付款，不删除或关闭服务端旧订单，不依据客户端结果发放点数。
- 用户确认未扣款不等于支付渠道已关闭原订单；未知订单仍可能稍后结算。旧账本继续由服务端核对，不能宣称这个恢复入口绝对排除重复扣款。已经扣款或等待苹果确认时应继续查询。

## 诊断字段与兼容

服务端 v3 catalog 返回 `paymentDiagnostics:1` 才启用上报。白名单为原生阶段、errCode、脱敏 errMsg、耗时、机型、系统、微信/基础库/小程序版本。只在付款阶段记录，不增加页面或房源行为埋点。客户端最多保存 10 条待送事件，三秒独立请求、服务端回执去重；断网后在后续 catalog 刷新重送，不阻塞支付。

新服务端按已有账号和订单鉴权，最多 60 条/订单，诊断表保留 30 天。原生 success/fail 都不是支付事实，点数仍由服务端核对发放。旧服务端未声明支持时不发送诊断；历史失败不会凭空补出机型或原生错误码。

官方依据：[wx.requestVirtualPayment](https://developers.weixin.qq.com/miniprogram/dev/api/payment/wx.requestVirtualPayment.html)、[query_order](https://developers.weixin.qq.com/miniprogram/dev/server/API/VirtualPayment/api_query_order)。`268490002` 须结合具体 errmsg 分析，不能直接解释为用户未付款或订单不存在。

## 定向验证

基线 `745e7ef22f6be9b2c8bd0034093ef5248b0a7ba2`，独立分支 `codex/wechat-payment-retry`；最终提交 SHA 记录于 PR。未修改脏主工作区。

| 范围 | 证据 |
| --- | --- |
| 失败后重试、未知结果保护 | 新增回归在修复前失败，修复后通过；包含刷新/重载、确认取消、确认期间迟到付款、查单失败、数字取消码 |
| 诊断和平台接线 | 断网重送、字段白名单/脱敏、旧后端兼容；真实 App/platform 的机型版本采集和确认弹窗参数使用 mock 微信接口验证 |
| 页面与点数已有行为 | 下列 7 文件共 117 项通过；没有运行全量测试 |
| 构建 | 正常生产配置 build 通过；wcc 22 文件、wcsc 24 文件通过 |
| 包体 | 新代码曾使 ASCII 转义产物达到 2,100,484 字节，超过 2 MiB；esbuild 改为 UTF-8 输出后为 1,919,618 字节，保留所有资源及运行逻辑，官方检查通过 |
| 真实点击 | 未完成：SDK 元素选择器超时；本机 CUA 对租用窗口点击报 noWindowsAvailable，不能当作验收通过 |
| 页面预览 | 共享池中真实构建页面，以 handler + 微信网络/支付测试桩准备画面；仅检查显示，不是端到端点击或真实支付证据 |
| 手机支付 | iOS/Android 实机失败、重试、扣款和到账尚待验证 |

```sh
cd apps/wechat
node scripts/build.mjs
node node_modules/vitest/vitest.mjs run \
  tests/billing.test.js tests/payment-diagnostics.test.js \
  tests/property-credits-component.test.js tests/capacity-runtime.test.js \
  tests/account-runtime.test.js tests/property-credits.test.js tests/platform.test.js
node scripts/check.mjs
```

本地日志在 `apps/wechat/artifacts/payment-retry/`：`before.log`、`component-before.log` 保留修复前失败，`frontend-release.log` 为 117 项通过，`compile-release.log` 为编译/体积通过。工具为 Node 24.22.1、DevTools 2.01.2510290、基础库 3.17.3。

交互观察脚本为 `apps/wechat/tests/e2e/payment-retry.cjs`，只能通过固定共享池执行；默认等待 CUA 真实点击并断言，`--render-preview` 明确降级为状态预览并生成 `preview-only.json`，不能以 runner 的 passed 判定 E2E 通过。测试构建必须指定 `WECHAT_TEST_DATA_ROOT=xunju-test-payment-retry-20261103` 和假 API `WECHAT_API_URL=https://payment-fixture.invalid/api/rent-room`；通过入口 guard 确认隔离路径，所有网络、身份和原生付款均为测试桩，不实际扣款。随后重新正常构建，不能上传测试 dist。

原始工具失败记录保留在共享池 runs 的 `2657f60174e54a0db2b849fb2f4769d3` 和 `c1be99e77545405ea0da2bee2f8d5e7b`。第一轮预览 `5b9703b8e44b49efb7f538fc20540e24` 截图早于渲染完成，仅保留排查，不作为最终界面证据。

首次修复的稳定预览 run `b57066a12c1f40ba9254d6eef92a980e` 已逐张检查；[明确失败](evidence/payment-retry-20261103/failed-retry-enabled.png)仍保留该轮截图，待确认截图已更新至上方文案调整记录。SDK 截图不包含原生确认弹窗，CUA 截图连接又超时，弹窗视觉检查仍未完成；参数和取消行为已由定向测试覆盖。

## 交付边界

客户端和后端分别通过 PR 审查；后台先上线才能开始收集新诊断。当前没有部署、上传、合并或修改历史订单。按仓库 AGENTS.md，真实交互、受影响平台真机验证以及用户界面确认仍是后续验收门禁；此记录不表示它们已经通过。
