# 寻居微信登录服务

Node.js 24，无第三方运行时依赖。本期只确认微信身份，不存储用户档案、看房记录、照片或登录凭证。小程序使用默认头像和「微信用户」，不获取手机号、微信头像或昵称。

## 接口

`POST /api/rent-room/auth/wechat`，JSON `{ "code": "wx.login 返回的一次性凭证" }`。

服务器使用自己的 `WECHAT_APP_ID`、`WECHAT_APP_SECRET` 调用微信 `code2Session`；成功返回 `{ "accountId": "64 位小写十六进制编号" }`。编号由 `SHA256(appId + NUL + openid)` 生成；不接受客户端指定的 openid / accountId。code、AppSecret、session_key、unionid 不写入日志；session_key 和 unionid 不返回客户端、不持久化。

状态码：400 请求不合法、401 微信凭证无效、403 微信拒绝该用户登录、413 请求超限、415 非 JSON、429 服务繁忙、502 微信服务或配置不可用。仅允许 JSON POST；请求体上限 1 KiB，上游超时 8 秒，最多 8 个并发交换、单实例每分钟 240 次请求。`GET /health/live` 只验证进程存活，不证明 AppSecret 有效。

这个 accountId 是本地目录归属标识，**不是后续云端数据接口的访问凭证**。未来做云同步时，需要增加服务端会话、令牌验证和每条数据的账号权限，再实现记录/媒体上传、增量拉取和冲突处理；账号映射可以沿用，无需重新注册账号。

## 本机验证

```sh
node --test services/wechat-auth/server.test.mjs
```

测试通过回环 HTTP 调用真实 handler，微信响应使用夹具；不等于真实微信登录验证。

## 目标服务器与上线准备

2026-10-15 只读核对：SSH 别名 `monitor-srv`，HTTPS 域名 `api.keeline.xyz`；运行中的 Caddy 实际挂载 `/opt/model_server/Caddyfile.accounts`，Docker 网络为 `model-server_default`。普通 `Caddyfile` 不是当前入口。部署时须重新核对。

准备独立目录 `/opt/rent_room_auth`，仅放本目录的 `server.mjs`、`Dockerfile`、`.dockerignore`、`compose.yml` 和服务端 `.env`。从 `.env.example` 创建 `.env`，权限设为 600，AppSecret 由微信小程序后台取得后在服务器填写；不要发进聊天、写入客户端或提交 Git。不要改动模型服务已有密钥和账户配置。

部署与网关变更需获用户授权后执行：

1. 冻结通过审查的提交，记录现有 Caddy 配置和容器状态，备份实际挂载文件。
2. 在独立目录运行 `docker compose -f compose.yml up -d --build`。服务仅暴露 Docker 内部 8080，不占宿主公网端口。
3. 将 `Caddy.snippet` 插入生产站点已有 `@account` matcher / handle **之前**，避免 `/api/*` 被 Time Fragment 服务接走；不要覆盖整个 Caddyfile，不修改 staging 站点。
4. 用现有 Caddy 二进制校验候选配置，再加载经过验证的配置；回读挂载和运行时路由。Caddy 镜像没有 shell/cat，应从宿主机读配置。若替换了 bind mount 文件 inode，应按网关现有运维流程加载，不能假设容器自动读到新文件。
5. 核对新容器健康、公开接口的非法凭证拒绝响应和现有模型/账户入口，再由真实微信小程序执行一次登录。失败时只撤回新路由和新服务，保留旧服务配置及数据。

微信后台「开发管理 → 开发设置 → 服务器域名」须配置 `https://api.keeline.xyz` 为 request 合法域名；确认该域名满足微信备案和证书要求。开发者工具勾选跳过域名校验不作为真机验收。

客户端构建：

```sh
cd apps/wechat
WECHAT_AUTH_URL=https://api.keeline.xyz/api/rent-room/auth/wechat npm run build
```

未提供 `WECHAT_AUTH_URL` 的构建仍可编译，点击登录会明确失败，不会开启游客模式。发布前必须配置正确 URL 并完成真实登录验收。URL 中禁止放凭据、查询串或 fragment。

官方契约：[小程序登录](https://developers.weixin.qq.com/miniprogram/dev/framework/open-ability/login.html)、[code2Session](https://developers.weixin.qq.com/miniprogram/dev/server/API/user-login/api_code2session.html)、[服务器域名](https://developers.weixin.qq.com/miniprogram/dev/framework/ability/network.html)。
