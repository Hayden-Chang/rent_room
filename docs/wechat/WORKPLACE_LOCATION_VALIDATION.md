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
