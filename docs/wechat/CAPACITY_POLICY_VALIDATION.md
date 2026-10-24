# 免费容量配置：实现与验证（2026-10-24）

## 交付范围

前端以 PR #56 的 `codex/xiaoda-onboarding-20261023` 为临时集成目标，起点 `be53224e033f7222f4ea8f0aaf0185512218bb4d`；本任务分支 `codex/server-free-capacity-20261024`，不直接推送集成分支或 main。配套后端基于 model_server PR #95 的 `e2693cef687043b4aa17726197b3f9d92bf662ae`，独立分支 `codex/configurable-free-capacity-20261024`。不执行部署、实单支付或小程序发布。

v2 客户端从服务端读取免费套数，默认 1 套。无头旧版固定 2 套、v1 固定 1 套；新客户端接受旧服务端的合法历史总数，消除因 1/2 套协议差异导致的账号校验失败。公共规则缓存独立于账号购买权益；规则降低保留既有记录，只有新增/恢复/导入净增长受限。规则详情见 [容量契约](CAPACITY.md)。

## 自动化边界与影响映射

Node v24.19.0、锁定依赖；构建和测试均在本任务 worktree。`WECHAT_ALLOW_MISSING_MAP_KEY=1` 仅供离线验证，不上传该产物。

| 变更边界 | 选择器 |
| --- | --- |
| v2校验、旧后端兼容、0/非法配置、缓存、恢复登录失败、设置异步刷新、操作续接 | `tests/capacity-policy.test.js` |
| 容量计算、增长约束、超额保留 | `tests/capacity.test.js`；`tests/model.test.js -t 'durable store and migrations'` |
| 目录/权益/订单元数据，旧刷新与新购买串行 | `tests/billing.test.js` |
| 身份生命周期、访客迁移、不同账号/数据目录 | `tests/account-runtime.test.js`、`tests/guest-runtime.test.js`、`tests/guest-storage.test.js`、`tests/account-storage.test.js` |
| 平台持久化与导入消费者 | `tests/platform.test.js`、`tests/transfer.test.js`、`tests/transfer-page.test.js` |
| 构建后容量/设置页面及首次操作续接 | `tests/runtime.test.js`、`tests/capacity-runtime.test.js`、`tests/first-meeting-runtime.test.js`、`tests/settings-simplification.test.js` |
| 公开API构建配置 | `tests/capacity-config.test.js` |
| 修改后的 accountWx 夹具的其余直接消费者 | `tests/account-profile.test.js`、`tests/commute-page.test.js` |
| 实际渲染 | 池回调 `tests/e2e/capacity-policy-render.cjs`；SDK导航和公共响应夹具，只验证像素及局部运行时，不宣称真实点击/微信身份/付款 |

未执行全量本地测试。原 `guest-runtime` 中免费2套、首页直接创建和不请求任何网络的断言已与当前合同对齐：默认1套、新建名称页、允许公共目录请求且禁止自动登录/下单。测试补齐原有小搭布局所需的选择器夹具，未修改产品导航。

## 失败证据与修复

- `artifacts/capacity-policy/frontend-before.log`：新增首批7项修改前均失败，覆盖可配置容量、v2/旧响应登录、公开刷新、缓存及晚到请求。
- `restored-session-before.log`：记住的登录返回503、公开规则可用时，本地仍为1而非4；修复后等待身份检查结束，再刷新当前服务。
- `existing-first.log`：8个旧断言/夹具失败，其中默认免费套数和新建入口属于集成分支已有行为；已按实际源码核实后修正，保留原记录。
- 配套后端新增8项在修改前失败，修复后容量/规则/反馈85项通过。首轮既有后台补发测试一次2秒等待超时，单独两参数诊断及最终运行通过；原因未定位，原结果保留，不将复跑当成修复。

## 验证结果和证据

本机完整日志均保留在本 worktree `artifacts/capacity-policy/`，构建编译结果在 `apps/wechat/artifacts/compile-result.json`。

- 首轮受影响15文件：187通过、1失败（新测试误写恢复后路由为详情页，真实合同是返回归档页）。修正该观察，并修复恢复登录失败后的规则刷新后，规则/登录/访客3文件58项通过。
- 支付新增v2订单响应与公开刷新并发用例后，`billing.test.js` 26项通过。
- 存储迁移精确选择器8项通过，跳过无关清单12项。
- 官方编译：15页面，WXML 20文件、WXSS 21文件通过；主包2,050,017字节，小于2MiB。
- 编译、VM和HTTP夹具结果不证明实际微信登录、线上新配置、真实付款或退款。此轮只改额度协议和数据刷新，WXML/WXSS及页面布局没有变化。

最终提交、渲染和交付证据如下；本地通过不代表生产已生效。

### 最终提交验收

业务与测试冻结于 `4fe92fc1e6c2939dceb7baa86b7a92ed2bc35e91`。通过 `git archive` 提取该提交到 `/private/tmp/capacity-policy-final-4fe92fc`，使用同一锁定依赖和 Node24 独立构建：17个相关文件223项通过，存储迁移精确选择器8项通过，合计231；官方编译再次通过。日志为 `final-4fe92fc.log`、`final-store-4fe92fc.log`，没有运行全套测试。配套后端冻结于 `296f633`，85项证据与该提交业务代码相同。

[前端 PR #62](https://github.com/Hayden-Chang/rent_room/pull/62) 已创建。创建后主 agent 复核 head 与上述提交一致、19个变更文件均在范围内、目标为 #56 的 `codex/xiaoda-onboarding-20261023`、可自动合并；远端未配置 Checks（空列表不作为 CI 通过证据）。审查发现的恢复登录失败后漏刷公共规则已通过新增回归修复，未发现其他阻断代码问题。

用户再次明确授权“允许继续截图验证并完成合入”后，固定池 run `2e2a3fbfdf8045b6ae4b4cebb5cac82f` 在3号槽复用现有进程，测试和清理通过。截图已逐张核对：设置页显示1/4套；容量页显示1/4套；免费规则调为0后显示1/0套，原1套房源保留。截图及scope/receipt位于 `artifacts/capacity-policy/render/`。公共响应和初始房源是夹具，页面为真实开发者工具渲染，导航使用SDK；没有真实登录、点击购买或付款。布局和样式未改。

此前测试池请求出现自动审批超时；用户授权后的第一轮 `3e943de8aaf843bca78645f389deeaed` 因两个隔离槽及另一个正在使用的槽位而排队超时，保留失败receipt。随后在健康槽空闲时执行成功，没有停止其他任务或修复隔离槽。

渲染的 `sourceHead` 为同一业务提交4fe92fc，`sourceStatus` 仅为本验证文档修改；冻结输入哈希 `3cec18a00344e3dae48aecf41724d075dd7abccfe112d17d35f9bb8c3b1f5271`。渲染构建显式使用隔离数据根和夹具API，其余源码、生成输入及依赖相同。当前补记只改文档，业务/测试/构建输入与已验证提交完全相同，无需重复逻辑测试。配套后端为 [PR #96](https://github.com/Hayden-Chang/model_server/pull/96)，保留草稿，不部署。
