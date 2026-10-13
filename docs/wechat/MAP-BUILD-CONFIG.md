# 地图预览构建配置修复（2026-10-13）

## 原因

用户此前在 iPhone 允许微信使用位置后，定位已正常。最新主线95a153e的统一预览包未注入天地图Key：实际 `dist/app.js` 为 `createPlaces(api, false ? "" : "")`。点击定位返回坐标后，附近查询的两个分支均因缺少Key而拒绝，最终合并为“地点查询失败，请重试或手动填写地址”。此错误不属于定位权限拒绝。

在隔离VM加载原预览包并调用公开测试坐标的nearby，复现相同提示，网络调用次数为0。业务定位/查询源码与此前可用版本一致，变化来自构建参数。现有 `TIANDITU_KEY` 环境变量需要手工传入，新worktree的普通build漏掉配置而仍成功，这是交付缺陷。

## 修复

- 构建读取环境Key、显式Key文件、worktree私有文件或用户级共享文件，按顺序选择。共享路径 `~/.config/rent-room/tianditu-browser-key`，权限0600，不提交。
- 配置缺失、指定文件不可读/为空时，在生成源码和清理dist前报错。不打印Key。
- 离线测试可显式允许无Key构建；这种产物不得用于地图验收或发布。
- 不修改 `getLocation`、权限、查询接口和界面；客户端Key仍只在忽略的构建产物中注入。

## 验证

基于main `1e095cf` 的独立分支 `codex/map-build-config`。

- 新回归 `map-build-config.test.js` 在旧源码下2失败、1通过：指定缺失配置仍成功构建；Key文件未进入包。日志 `apps/wechat/artifacts/map-build-before.log`。
- 修复后构建，再运行 `map-build-config`、`runtime`、`places`、`address-picker`：4文件26项通过，覆盖新worktree共享配置、优先级、空文件、离线显式选择、构建注入、既有运行时与查询逻辑。日志 `apps/wechat/artifacts/map-build-after.log`。
- 未设置Key环境变量的普通build确认共享配置进入dist，值不输出。官方wcc 9模板、wcsc 7样式通过。
- 用Node的fetch直接访问浏览器端Key接口返回HTTP403；这是非微信运行时的调用，不能替代微信wx.request成功证据，未加请求头绕过。日志 `apps/wechat/artifacts/built-map-network.log` 同时保留旧包复现证据。
- 实例池三槽均busy-or-quarantined，未接管/重启。修复预览包仍需iPhone点击定位，检查附近条目及“使用”地址回填。预览上传成功不代表此现场验收已通过。
