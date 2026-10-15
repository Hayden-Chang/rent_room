# 上班地点独立页面验证

日期：2026-10-15。需求：设置中的上班地点进入独立页面，全局保存一个地点，复用房源地址的搜索、地图选点、定位和手动填写。

## 行为与数据

- `pages/settings` 打开 `pages/workplace`；返回设置时刷新地址摘要，长地址省略显示。
- 沿用自动保存。选点保存地址与 GCJ-02 坐标；仅手填时允许没有坐标。原有文字地址直接回显。
- 仅补充楼栋/房间时保留已确认位置；改为其他地址时不沿用旧坐标，恢复匹配地址可恢复原位置。清空地点会移除全部位置锚点。
- 使用应用已有 service/store；不修改房源、答案、备注、影像或其他设置。写盘失败保留会话输入，页面提示重试。
- 房源地址组件只增加可配置的空状态文案；原默认文案和搜索、选点逻辑沿用。
- 样式复用当前小程序表单和地图组件；本次 Figma 插件 ping 没有连接，原型服务 8876 没有运行，未声称与云端设计逐像素一致。

## 自动测试映射

以下路径相对于 `apps/wechat`。使用应用支持的 Node.js 24.19.0；没有运行全量单测或全量 E2E。

| 变更边界 | 精确选择 | 断言 |
| --- | --- | --- |
| 单地点设置与持久化 | `tests/workplace.test.js` | 替换与重载、旧文字兼容、坐标失效/恢复、清空、非法选点、磁盘失败及重试；保留其他设置和房源 |
| 设置入口与打包页面 | `tests/workplace-runtime.test.js` | 独立导航、设置摘要回显、手填/选点/清空、重开、错误提示及重试 |
| 复用地址组件 | `tests/address-picker.test.js`、`tests/address-bindings.test.js` | 既有搜索、定位拒绝、异步结果作废、地图拖动/缩放事件、选点绑定和权限恢复 |
| 应用启动与共享 store | `tests/runtime.test.js` | 构建后 App/Page 在无 Node/DOM 的 VM 中运行；现有页面共用 store |

命令（先构建，再测试构建产物）：

```sh
node scripts/build.mjs
node node_modules/vitest/vitest.mjs run tests/workplace.test.js tests/workplace-runtime.test.js tests/address-picker.test.js tests/address-bindings.test.js tests/runtime.test.js
node scripts/check.mjs
```

初次结果：5 文件、31 项通过；官方 wcc/wcsc 编译通过。完整输出保留在本 worktree 的 `apps/wechat/artifacts/workplace-location/`。最终提交记录和重跑结果以 PR 描述为准。

## 最小 UI 验收与当前限制

长期回归入口：`tests/e2e/workplace.cjs`，仅在固定实例池的可丢弃数据中执行；SDK 按 `WECHAT_AUTOMATOR_MODULE` 或 worktree 的固定锁定依赖加载。

计划通过真实输入/点击验证：设置进入独立页 → 手填 → 返回摘要 → 重开回显 → 拒绝定位仍保留文字 → 搜索并选择结果 → 地址/坐标落盘 → 重开 → 修改地址清除旧坐标 → 清空回到未设置。导航记录从点击到目标路由就绪的 SDK 观察耗时；地图查询和定位错误使用服务夹具，只证明页面交互，不证明天地图线上质量或真实 GPS。

本次使用固定 runner `/Volumes/mac2/codex-builds/wechat-instance-pool/runner/pool.py`，run ID `197a21c61b7c4d799bc6c8047c2ff4bf`。槽位 3 在执行回调前健康检查超时：`App service health timeout`；receipt 状态 `failed` / `quarantined`，进程由池保留。没有执行页面交互断言，没有实际截图，不把 VM 或编译成功作为 UI 通过。没有重试同一异常槽或修改共享池。

可用槽恢复后需执行上述 UI 脚本并检查真实截图。实际手机 GPS、原生权限/键盘和地图拖动仍需受影响平台验收。用户确认实际 UI 后方可合入；当前为待验收。

## 2026-10-15 工具池恢复后的实际渲染

用户明确要求维护工具池后，独立 PR #26 修复工程缓存根路径及工具自动落盘的默认 WXML 配置，固定入口已安装维护提交 `226a6d922b1e2ccae6f5beeaa82d72ddd7d2216d`。三个遗留隔离槽均按锁、控制器和 PID 身份检查恢复，旧 profile、runtime 和失败 receipt 保留。

应用源码仍为 `8b30a821651739a15f40fd50ad697ae8e2e9ac6e`。新增本节仅为文档，不改变构建、测试或应用行为；此前 31 项单测和官方编译证据可复用。

- 实际设置页：run `7bbf2aed65eb42f2a9594e41256c925f`，3 号槽同 PID 复用，SDK 打开设置作为前置条件后截图，已正常归还。
- 实际上班地点页：run `41f9af7a5f5b4be9b7b1c9f91f269e7f`，直接 SDK 导航仅作为渲染准备；断言路由为 `pages/workplace/index`、地址为空，取得 `workplace-empty-real.png`。没有用页面 handler 或 setData 准备页面效果。
- 截图及渲染断言位于本 worktree 的 `apps/wechat/artifacts/workplace-location/ui-20261015/`。可以确认手填、搜索框、定位按钮及上班位置空状态在当前代码中实际渲染。
- 工具池完整 App/截图/冻结/归还探测 run `e30564465e6f4dd5b95c916ce1fccf91` 为 `passed` / `idle`，2 号槽同 PID 复用。

保留的未通过项：旧 UI 脚本 run `c4106519b70446c5b9f41db96cf8ee34` 在元素查询处超时；后续逐项探测证明系统信息、App evaluate、currentPage 和截图均可用，`Page.getElement` 无响应。原生 `cua_repl` 对准确池 App 路径也返回 `timeoutReached`。已向用户请求明确允许 AppleScript / System Events 替代输入（该控制工具说明要求明确指定替代技术），等待期间没有采用该输入方式。

当前截图证明实际渲染，未证明设置入口点击、真实输入、搜索结果点击及操作后的落盘回显。完整交互验收和用户视觉确认仍待完成，PR 保留草稿。
