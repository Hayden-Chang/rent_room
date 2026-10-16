# 房源容量与房源包

用户确认口径：免费容量 2 套；¥1.99 每包增加 10 套，长期有效、可重复购买。容量为 `2 + 已确认且未退款的房源包数量 × 10`。

现网商品固定为 `room_capacity_10`，金额 `199` 分，OfferID `1450681249`，支付环境 `env=0`。客户端核对目录商品 ID 与支付签名中的 OfferID、商品、金额、数量、币种、环境和订单号，签名字符串原样交给微信。AppSecret、AppKey 及推送密钥只配置在服务端。

占用只计算未归档的房源，搜索、筛选不改变占用。归档成功保存后释放容量，删除已归档房源不再改变占用；还原时重新占用容量，名额不足则保留归档状态。归档或还原保存失败时回滚，记录和媒体不变。新建及 ZIP 导入中的未归档房源计入容量；导入的归档记录不占名额。覆盖导入按整批未归档数量的净增量检查：归档转未归档需占用容量，未归档转归档会释放容量；新增副本也按其归档状态计算。净增量超额时整批拒绝，写入媒体前先检查。

旧记录、上一次本机保存恢复、退款导致的超额记录都保留，可查看、编辑、备份和删除；容量不足仅限制继续新增。取消付款、结果未知或导入失败保留草稿和待导入数据。

## 服务边界

`model_server` 的独立 `rent-room-api` 服务承接 `/api/rent-room`，为登录、个人资料和容量提供同一微信会话，并使用独立 SQLite 订单账本。房源、答案和媒体继续保存在本机，不随支付上传。客户端 `purchases.json` 缓存最后确认的权益与待查询订单，独立于房源备份；同一次已登录运行离线保留最后确认容量；冷启动须重新验证身份，重新登录时采用服务端最新权益。微信账号对应的权益恢复不等于房源数据同步，也不代表多个设备共享房源列表。

构建时通过公开地址配置接入，例如：

```sh
WECHAT_API_URL=https://api.keeline.xyz/api/rent-room npm run build
```

微信后台须配置对应 request 合法域名。此地址是部署目标，不代表该端点已经上线。未配置时不能登录；容量页保留容量数字、商品价格、购买按钮与「刷新容量」，不再显示超额说明或额外的返回按钮；返回沿用系统导航。购买按钮保持紫色，仅处理期间禁用。点击后检查客户端支持情况及服务端商品状态，未开放或不支持时显示错误，不会模拟到账。后端未启用商户或 iOS 未开通时不发起支付。

支付调用 `wx.requestVirtualPayment`，签名字符串原样透传。前端成功回调不增加容量；由服务端查单核实金额、平台订单号与支付状态后确认。取消可再次购买；结果未知先保留订单并查询，避免重复付款。服务端支付通知、重复请求和退款的处理说明见配套 `model_server/docs/rent-room-capacity.md`。

配套后端在登录、权益刷新及每分钟后台任务中有界补查，订单保存下单商品和金额快照；旧 `house-capacity-10 / 190分` 订单按原金额核验。退款以验签解密后的最终结果和原支付单号核对，退款失败不扣容量，成功退款累计达到整单金额后回收该包。退款后的既有超额房源保留。

联调目标回调为 `https://api.keeline.xyz/api/rent-room/wechat/notify`，后台选择安全模式并配置匹配的 Token、EncodingAESKey。2026-10-16部署前已在独立 `private.env` 配置服务端密钥，并保存配置和SQLite在线备份。随后按用户明确授权部署后端联调版本、开启通用及iOS支付，公网目录为199分、每包10套；微信后台回调已由用户保存成功。只更新寻居容器，其他服务不变。首笔iPhone实单已由后端正常补查确认，用户报告容量为1/12；退出与换机权益恢复、重复通知和退款实单仍单独验收。原支付单查单兜底要求：用户收款完成的状态8、数值零的剩余金额、匹配的原金额/订单/平台单号和生产环境均满足才回收整包；商户扣款阶段5、部分退款和不完整结果不扣权益。

## 验证选择

### 付款框调起耗时排查（2026-10-16）

用户录屏中，微信「支付中」出现到苹果确认面板约 3 秒，取消后能自行恢复。小程序未调用 `showLoading` 显示该弹层；该段已进入 `requestVirtualPayment`。官方 API 只提供 success / fail / complete，没有付款框展示回调或预加载参数，不能将支付结束回调耗时当作弹框耗时。参考 [微信 API](https://developers.weixin.qq.com/miniprogram/dev/api/payment/wx.requestVirtualPayment.html)。

另外发现两处小程序前置等待：购买先等待整个后台权益刷新，再重复请求商品目录。购买现在复用同一会话内 30 秒以内的商品目录及进行中的目录请求，显式刷新仍重新核对目录；后台权益请求不再阻塞新购买，过期响应不能覆盖新容量或清除新错误。下单仍由服务端校验开关，客户端继续核对签名商品和金额、查询未决原订单及阻止重复付款，不预创建订单。

`getApp().service.billing.diagnostics()` 只在内存保留最近一次购买的阶段计时：`catalogReadyMs`、`previousOrderReadyMs`、`orderReadyMs`、`nativeInvokedMs`、`nativeReturnedMs`、`finishedMs` 均相对 `startedAt`。无账号、令牌、订单号或签名，不落盘、不上传。`nativeReturnedMs - nativeInvokedMs` 包含用户确认或取消的时间，不能用来宣称苹果面板耗时已测得。

新增两项回归在旧代码均失败，分别证明重复目录请求和慢刷新阻塞。受控服务测试注入 2 秒旧权益刷新、100ms 目录和 80ms 下单，调用微信前的等待从约 2188ms 降到 83ms；这是模拟链路的改进，不是真机苹果面板的前后对比。Mac 对公开目录的单次实测约 96ms；同样不能替代手机时序。后端下单仍可能等待同账号正在进行的服务端查单锁，本轮没有修改服务端锁或支付账本。

验证映射：`tests/billing.test.js` 覆盖目录复用/过期/失败、刷新竞态、签名、取消和未知结果；构建后的 `tests/capacity-runtime.test.js` 覆盖旧刷新不清除新错误；`tests/account-runtime.test.js` 覆盖共享服务、退出及账号隔离。实际手机付款框是否更早出现仍需同设备对比，未据模拟结果宣称三秒等待已消除。

| 修改边界 | 精确验证入口 |
| --- | --- |
| 容量、归档、删除、保存、导入和旧状态 | `tests/capacity.test.js`；`tests/model.test.js` 的 `durable store and migrations` |
| 微信文件与备份消费者 | `tests/platform.test.js`；`tests/files.test.js` |
| 订单恢复、结果未知、取消、金额与刷新竞态 | `tests/billing.test.js` |
| 构建地址配置 | `tests/capacity-config.test.js` |
| 构建后共享服务与页面编排 | `tests/runtime.test.js`；`tests/capacity-runtime.test.js` |
| 真实第三套拦截、归档排除及未开放提示 | 通过固定池 runner 执行 `tests/e2e/capacity.cjs` |

VM、模拟微信 API 的测试不代表真机付款；已发生的首笔iPhone付款不代表换机恢复或退款通过。UI 截图与用户审批、代码合入、后端部署和小程序发布分别验收。

2026-10-15 开发轮次：52 项定向逻辑/VM/文件测试通过；另有 12 项不相关源清单测试通过选择器排除。官方 wcc/wcsc 编译通过。真实工具能渲染列表和容量页面，但 SDK 元素查询在可见“添加”按钮处超时；原始失败保留。`CAPACITY_RENDER_ONLY=1` 是显式渲染夹具路径，仅提供实际像素，不证明点击、第三套导航或支付操作通过。当前仍待真实交互和用户 UI 审批。

## 本轮验证记录（2026-10-16）

- 商品/签名与未知支付恢复：`tests/billing.test.js`。新增未知付款、查单暂为unpaid后重复点击的回归在修改前失败；修复后保留原订单而不二次下单。
- 免费2套、归档/恢复与退款超额：`tests/capacity.test.js`、构建后的 `tests/capacity-runtime.test.js`。
- ZIP覆盖/新增副本和媒体写入前净增检查：`tests/transfer.test.js`；登录复用与账号隔离：`tests/account-runtime.test.js`；公开HTTPS地址约束：`tests/capacity-config.test.js`。选择上述六文件，未运行全量单测。
- 官方编译：构建后运行 `node scripts/check.mjs`，WXML/WXSS各14文件、12页面。
- 固定池渲染通过：run `1163697790f24a5b83272beeb7dfacf2`，已检查 `capacity-render.png` 的1.99元和按钮、占用1/2。身份、房源及导航均为夹具；不表示付款。
- 实际按钮用例 `tests/e2e/capacity.cjs` 在run `aa05d311e25640ea8b6b68e5ffe9a6e2` 查询已渲染的 `.add` 按钮时超时，后续支付点击未执行。失败receipt与截图保留；未用直接调用handler代替点击验收。
- 本地证据在 `apps/wechat/artifacts/virtual-payment/`；服务端测试及部署边界在配套model_server PR。渲染之后只改支付未知结果保护和文档，页面WXML/WXSS、商品常量及渲染夹具不变，截图仍可用于同一外观评审。

签名与回调核对依据：[腾讯支付参考](https://github.com/TencentCloudBase/skills/blob/main/skills/cloudbase-wechat-integration/references/virtual-payment.md)、[维护者对自建推送和退款契约的勘误](https://github.com/TencentCloudBase/CloudBase-AI-Toolkit/issues/1132)。随后取得[官方查单原文](https://developers.weixin.qq.com/miniprogram/dev/server/API/VirtualPayment/api_query_order)，已据明确的用户收款阶段及剩余金额补全全额退款兜底。仍不把mock或只读自检称作实单退款验收。用户已确认本轮容量页界面。

### 已到账后的错误提示恢复

自动刷新成功时清除上一轮错误；新的查询失败仍显示原因，已确认的12套容量保留。回归先复现旧提示未清除（1失败、1通过），修复后5项受影响页面测试通过。固定池run `7012d4db8c0d48d5bbb5f19973ce4d2f` 使用真实登录和已购1包权益，注入一次刷新失败及后续成功，通过SDK切页返回触发onShow，截图验证错误消失且容量仍为12；这是局部生命周期验证，不代表真实订单查询或原生点击付款。配套后端另补微信令牌被拒绝后的单次刷新重试，真实原订单查询单独复验，整个修复不新增购买。

### 合并验收范围（2026-10-16）

用户已在iPhone确认首笔¥1.99购买后显示1/12、错误提示消失，退出并重新登录后仍为1/12。服务端原订单连续两次真实查询返回paid、1包、总容量12；固定池run `6a1ee92279554aa69984baf588858e05` 使用真实wx.login和现网请求，应用auth服务退出重登后恢复12，没有新增订单或调用支付。开发者工具的原生按钮E2E曾因Page元素查询协议超时未完成，保留原失败；它不影响上述手机手动验收结论，也不记为自动通过。

用户明确要求暂缓退款及容量回收实单测试，并授权验证后合并前后端PR。**退款回收实单仍为未验收**；现有自动化退款用例不替代实单。换机恢复和Android实单也未验收。合入主线不代表新增部署、正式版上传、提审或发布。
