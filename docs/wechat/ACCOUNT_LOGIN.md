# 微信登录与本地账号数据

## 本期行为（2026-10-19 审核整改）

- 首次打开直接提供未登录本机记录，首页没有登录遮罩，底部导航保持可用；免费套数按服务端公开规则（首次离线默认1套），可添加、编辑、检查、对比、归档及导入导出。首次使用只读取公开容量规则，不调用微信登录或后端身份接口。
- 「我的」提供可选微信登录入口。未登录时不渲染头像和昵称控件；登录后才显示自主设置入口，均不作为使用或登录前置条件。头像及昵称仍仅保存在本机。
- 容量页未登录时不自动查询账号权益。用户主动点击「微信登录后购买」或「微信登录并恢复容量」才开始登录；成功后重新打开容量页，核对权益后由用户再次点击购买，不在登录成功回调里自动下单。
- 登录前的未归属记录关联至验证通过的微信账号，复制影像后原子写入合并状态，保留原始文件；事务日志和已提交批次防止重试重复导入。已有同ID记录另分配ID以保留双方内容。合并后若超出当前容量，保留全部记录并限制继续新增或恢复。
- 冷启动时先准备未登录本机目录；曾选择保持登录的用户仍向自有后端确认当前微信身份，确认前不展示旧账号记录。验证失败回到免费本机记录，旧账号文件保留，须验证同一账号后才能读取。
- 同一次运行从照片或文件选择器返回时沿用当前数据会话，避免打断未完成的系统调用。退出先保存，失败则保持当前会话；成功退出保留账号文件并打开独立免费本机目录。同一账号再次登录可继续查看，其他账号不能取得此前账号的记录及已购容量。
- 旧版未归属根目录仍由首次成功验证的账号认领；绑定前备份状态文件，旧媒体路径保留，绑定失败不覆盖原文件。
- 不上传或同步看房记录和照片；账号编号不能用于推导云端数据访问权限。

## 实现边界

`account-session.js` 通过 `wx.login → wx.request → 自有后端 code2Session` 验证账号。磁盘 `login.json` 只记是否选择过登录，不存可信身份。`account-storage.js` 管理旧记录归属和账号目录；`guest-storage.js` 管理未登录目录与关联事务；`auth-page.js` 按当前账号或未登录目录守卫页面及事件，包括直接打开的页面。平台服务在退出时失效，旧页面/异步回调不能继续读写它。

旧根目录为 `USER_DATA_PATH/xunju`；首次认领的旧数据保留原路径，新的账号使用 `xunju/accounts/<accountId>`。未登录数据位于 `xunju/guests/<batchId>`；已认领目录不再被其他未登录会话使用。账号关联日志保存在目标目录，提交后的批次记入目标状态，原始未登录目录保留为恢复副本。目录隔离用于应用内账户访问控制，不是文件加密。

登录与容量统一使用 model_server 的独立 `rent-room-api` 服务，部署与接口见 [房源容量](CAPACITY.md)。不再维护第二个登录服务，也不使用 wx.cloud。`POST /api/rent-room/session` 返回 `{account, token, packs, limit, capacity}`（v2）；旧协议保留原字段；账号为服务端计算的 SHA-256 十六进制标识，令牌只留在内存，绝不写入本机文件或房源备份。

`WECHAT_API_URL=https://api.keeline.xyz/api/rent-room` 是唯一构建地址。首次会话同时取得账号与权益，购买/恢复沿用该令牌，不再次调用 wx.login。401 会撤销旧服务并返回可免费记录的首页；退出和账号切换清除待导入内容及新房源草稿。支付未开放时仍可以登录并使用免费容量。

## 定向验证映射

| 改动 | 验证 |
| --- | --- |
| 首次免费体验、主动登录与免费页可达性 | `tests/guest-runtime.test.js` |
| 关联中断、幂等、媒体复制失败与账号隔离 | `tests/guest-storage.test.js` |
| 登录/恢复/退出、路由守卫、旧回调、文件选择器返回 | `tests/account-runtime.test.js` |
| 账号目录、旧记录认领、失败保护、服务失效 | `tests/account-storage.test.js` |
| 本机头像/昵称持久化、失败保护、昵称检查、账号隔离 | `tests/account-profile.test.js`、`tests/account-runtime.test.js` |
| 登录按钮颜色和资料卡实际渲染 | `tests/e2e/account-profile-render.cjs`；身份/资料为夹具，不代表真机资料控件已验证 |
| HTTPS 配置及构建配置共存 | `tests/auth-build-config.test.js`、`tests/map-build-config.test.js` |
| 业务页面共享 service、保留原功能 | `tests/runtime.test.js`、`tests/root-group-runtime.test.js`、`tests/unanswered-group-runtime.test.js`、`tests/detail-navigation.test.js`、`tests/onboarding.test.js`、`tests/speed-test-page.test.js` |
| 文件与平台 adapter | `tests/platform.test.js` |
| 后端身份、令牌、订单隔离与支付默认关闭 | model_server 的 `business_api/tests/test_rent_room_capacity.py` |
| 实际按钮、失败重试、退出及重登保存、两账号隔离截图 | `tests/e2e/account-login.cjs`，通过固定实例池执行 |

页面原有测试使用明确的 `localPageFixture` 只验证页面功能；真实 App 登录生命周期由 account-runtime 单独覆盖。E2E 的微信 code、后端身份与原生确认弹框均为夹具，只有按钮和页面导航是真实操作。真实微信身份、请求合法域名、AppSecret、iOS/Android 真机仍须接通后验收。

2026-10-19 原生验证入口：`tests/e2e/optional-login.cjs` 读取真实渲染并尝试SDK按钮点击；`optional-login-native.cjs` 在持有池租约时等待CUA真实点击与输入。每次报告须明确点击是否完成，不把截图或导航API当作点击通过。
