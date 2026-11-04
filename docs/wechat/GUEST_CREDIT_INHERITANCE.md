# 游客消费继承（2026-11-04）

保留首次启动不请求微信身份的游客模式。游客成功新建消耗本机 `property-credits.json` 中的 `freeSpent`；登录同一账号时继承消费，免费额度不再次发放。房源导入与关联本身不产生一笔新消费；删除、归档和恢复不清除消费。

## 客户端与服务端契约

- 登录前冻结原账号迁移基数；游客关联先登记来源与归属，不立即复制内容。
- 初始化服务端钱包、尝试收尾已有新建事务后，对未确认的游客消费调用 `POST /api/rent-room/credits/guest-claims`，携带 v3 header、微信 session 和 `{guestId,freeSpent}`。
- 服务端在 SQLite 写事务中绑定游客批次与账号，按累计消费的增量扣除尚未使用的免费点数，最大扣到免费余额为零，不扣付费点数。相同／更旧请求重放不再扣点；跨账号绑定被拒绝。
- 仍有未确认的新建预留时，新的游客消费继承返回 409。先收尾原请求再重试，避免预留取消后免费点数重现。
- 客户端验证 `guestClaim:{guestId,freeSpent}` 回执，原子保存本机确认值。回包丢失或确认写盘失败时，下次按相同批次重试。
- 继承确认成功后复制最新游客房源、媒体和备注，再重新加载账号 service。失败仍保留游客数据；游客在失败后继续创建的房源及新增消费，在后续登录时一起关联。
- `guest-credit-claims.json` 独立于房源导出，记录来源及确认值。持续保留原游客目录，便于冷启动恢复和确认追加消费。

新客户端依赖配套 model_server 后端，需先部署后端再发布客户端。旧后端没有接口时登录返回失败、保留游客数据，不假报继承成功。旧客户端及 v1/v2/v3 既有响应字段不变；iOS 未改动。

该修复不引入静默微信登录或设备指纹，不能识别清除本机数据后未登录的历史身份，不追溯清理此前已经使用掉的额外额度。

## 回归证据

基线客户端 `bf0f9d4a`、后端 `b6417b4`。Node 24.22.2、Python 3.12 隔离虚拟环境，依赖使用各仓库锁定版本。

- 新增客户端用例在修复前 6 失败／1 通过，包括游客花 2 点后登录仍返回 2（预期 0），以及删除后免费余额重复发放。
- 客户端 13 个相关测试文件共 177 项通过：guest-credit-inheritance、credit-runtime、guest-storage、guest-runtime、account-runtime、credit-client、property-credits、billing、capacity-policy、capacity-navigation、example-session、account-storage、platform。
- 影响映射：登录编排对应 account/guest/credit runtime；持久化及数据关联对应 guest-storage、account-storage、platform、property-credits；接口/余额对应 billing、credit-client、capacity-policy/navigation；示例免扣对应 example-session。
- 后端 guest inheritance、credits、capacity 三个模块共 93 项通过，覆盖新增接口、持久化重启、并发重试、账号隔离、支付余额和旧协议兼容。capacity 模块顺带运行其配置与 provider 用例。
- 本机真实客户端→HTTP→FastAPI→SQLite 合约测试 5 个场景通过：游客已用 0/1/2、重复登录/重启、继承响应丢失后继续消费再登录、删除全部房源后登录。
- `npm run build` 和 `npm run check` 通过；官方 wcc 22 个 WXML、wcsc 24 个 WXSS 编译通过，主包 1,921,629 字节。新增测试脚本不进入 dist。

客户端日志位于任务 worktree `artifacts/guest-credit-inheritance/`；后端日志位于其 worktree `business_api/artifacts/guest-credit-inheritance/`。这些是本地证据，不提交产物。

合约测试启动（在后端 business_api 目录，必须隔离测试环境）：

```sh
PYTHONPATH=.:tests python -m uvicorn guest_credit_api_fixture:app --host 127.0.0.1 --port 18794
```

客户端执行（在 apps/wechat 目录）：

```sh
GUEST_CREDIT_TEST_API=http://127.0.0.1:18794/api/rent-room node tests/integration/guest-credit-api.mjs
```

身份由 FakeWeChat 提供，文件系统由隔离内存适配器提供；业务前后端代码和 SQLite 事务是真实实现。未执行真实微信登录、生产数据库迁移、支付、开发者工具 UI 或真机验收。此次只改变点数/登录事务，不修改页面布局、文案或 iOS UI。
