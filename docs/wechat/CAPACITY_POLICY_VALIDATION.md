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

提交、最终验证及渲染结果在交付时补记；网络不可达时不得声称已创建或合并 PR。
