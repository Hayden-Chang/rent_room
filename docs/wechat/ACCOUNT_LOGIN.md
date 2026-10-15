# 微信登录与本地账号数据

## 本期行为

- 首次打开进入登录页，仅提供「微信登录」，不保留游客入口。
- 登录成功进入看房首页；「我的」显示默认头像、微信用户、账号编号和本机记录数量。无头像/昵称表单，无手机号授权。
- 冷启动时先向自有后端重新确认记住的微信账号，确认前不展示业务页面。登录失败可以重试，没有离线免验证入口。
- 同一次运行从照片选择器、文件选择器或后台返回时沿用已确认的登录状态，避免打断未完成的系统调用。退出后再次进入须点击登录。
- 退出先保存，失败则保持当前会话；成功退出保留本机数据。同一账号再次登录可继续查看，其他账号使用独立目录。
- 首次遇到旧版未归属记录，要求确认「归入当前微信账号」；取消则不登录。确认前备份状态文件，旧媒体仍在原位置，归属标记原子写入。
- 不上传或同步看房记录和照片；账号编号不能用于推导云端数据访问权限。

## 实现边界

`account-session.js` 通过 `wx.login → wx.request → 自有后端 code2Session` 验证账号。磁盘 `login.json` 只记是否选择过登录，不存可信身份。`account-storage.js` 管理旧记录归属和账号目录；`auth-page.js` 守卫所有业务路由与事件，包括直接打开的页面。平台服务在退出时失效，旧页面/异步回调不能继续读写它。

旧根目录为 `USER_DATA_PATH/xunju`；首次认领的旧数据保留原路径，新的账号使用 `xunju/accounts/<accountId>`。目录隔离用于应用内账户访问控制，不是文件加密。

登录与容量统一使用 model_server 的独立 `rent-room-api` 服务，部署与接口见 [房源容量](CAPACITY.md)。不再维护第二个登录服务，也不使用 wx.cloud。`POST /api/rent-room/session` 返回 `{account, token, packs, limit}`；账号为服务端计算的 SHA-256 十六进制标识，令牌只留在内存，绝不写入本机文件或房源备份。

`WECHAT_API_URL=https://api.keeline.xyz/api/rent-room` 是唯一构建地址。首次会话同时取得账号与权益，购买/恢复沿用该令牌，不再次调用 wx.login。401 会锁住旧服务并返回登录页；退出和账号切换清除待导入内容及新房源草稿。支付未开放时仍可以登录并使用免费容量。

## 定向验证映射

| 改动 | 验证 |
| --- | --- |
| 登录/恢复/退出、路由守卫、旧回调、文件选择器返回 | `tests/account-runtime.test.js` |
| 账号目录、旧记录认领、失败保护、服务失效 | `tests/account-storage.test.js` |
| HTTPS 配置及构建配置共存 | `tests/auth-build-config.test.js`、`tests/map-build-config.test.js` |
| 业务页面共享 service、保留原功能 | `tests/runtime.test.js`、`tests/root-group-runtime.test.js`、`tests/unanswered-group-runtime.test.js`、`tests/detail-navigation.test.js`、`tests/onboarding.test.js`、`tests/speed-test-page.test.js` |
| 文件与平台 adapter | `tests/platform.test.js` |
| 后端身份、令牌、订单隔离与支付默认关闭 | model_server 的 `business_api/tests/test_rent_room_capacity.py` |
| 实际按钮、失败重试、退出及重登保存、两账号隔离截图 | `tests/e2e/account-login.cjs`，通过固定实例池执行 |

页面原有测试使用明确的 `localPageFixture` 只验证页面功能；真实 App 登录生命周期由 account-runtime 单独覆盖。E2E 的微信 code、后端身份与原生确认弹框均为夹具，只有按钮和页面导航是真实操作。真实微信身份、请求合法域名、AppSecret、iOS/Android 真机仍须接通后验收。
