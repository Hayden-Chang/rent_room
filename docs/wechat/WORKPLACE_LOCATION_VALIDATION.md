# 上班地点独立页面验证

日期：2026-10-15。需求：设置中的上班地点进入独立页面，全局保存一个地点，复用房源地址的搜索、地图选点、定位和手动填写。

最新结论：核心桌面 UI 流程已通过，包含原生地图底图截图及独立读盘。定位拒绝使用测试夹具；真实 GPS、系统权限弹窗、原生地图拖动和用户视觉审批未覆盖。下文早期阻塞保留为历史记录，最终证据见末节。

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

## 原生操作补充记录

用户已明确授权仅对本任务独占的 3 号窗口使用 AppleScript / System Events。后续通过该方式显示窗口，`cua_repl` 曾恢复可用；以下交互均未调用页面 handler、setData 或直接修改 store。应用源码仍与 `8b30a821651739a15f40fd50ad697ae8e2e9ac6e` 相同。

实例池 run `82b47a27c9f443bfa4f584f7f926ed6f` 已正常完成、归还 idle；其 passed receipt 证明回调、冻结核验与清理成功，不代表下表未通过的 UI 操作通过。截图、观察 JSON、test.log 与 receipt 已归档到 `apps/wechat/artifacts/workplace-location/ui-20261015/native-v2/`。

| 操作 | 实际结果与证据 |
| --- | --- |
| 点击设置中的上班地点 | 进入 `pages/workplace/index`；`04-workplace-empty-real.png` |
| 实际键盘输入及中文粘贴 | 英文输入及中文地址进入页面与共享设置；`09-manual-typed-real.png`、`10-manual-chinese-real.png` |
| 原生返回设置页 | 摘要回显中文地址；`11-settings-summary-real.png`、`12-settings-summary-real.png` |
| 点击入口重开 | 手填地址仍显示；`13-reopened-manual-real.png` |
| 在搜索框实际输入“腾讯滨海大厦” | 线上天地图返回“深圳腾讯滨海大厦”等结果，未使用查询夹具；`14-search-results-real.png` |
| 点击搜索结果 | 原生坐标操作多次返回 `noWindowsAvailable`；System Events 点击后地址和坐标未改变，不能计为通过；`15-selected-system-real.png` |

本轮观察中 `disk` 读取未成功，故保存成功的当前证据限于页面/共享 store 与返回回显，不能声称已独立读盘验证。初始空状态没有 state.json 属于预期；后续已增加文件读取错误记录供继续验收。

窗口控制的限制仍存在：原生控制前后曾观察到窗口移到屏幕外；恢复位置能短暂恢复输入，但 `cua_repl` 后续仍出现 `noWindowsAvailable` / ScreenCaptureKit `-3812`，System Events 也出现 AppleEvent `-1712`。修改池副本应用标识的诊断方案被自动审批拒绝，未执行该安装修改；已准备仅核对租约/PID/窗口范围的 Swift / CoreGraphics 脚本，等待用户明确授权后方可执行。

剩余验收：搜索结果选择并保存坐标、独立读盘、返回重开后的坐标回显、修改地址后旧坐标失效、清空与未设置、定位失败仍可手填。用户视觉确认也尚未取得，PR 继续保留草稿。

## Swift 原生操作后的最终验收

用户已明确允许 Swift / CoreGraphics 仅操作本任务独占的 3 号窗口。原生事件校验当前租约、准确 PID、池 App 路径、项目窗口及坐标范围，通过窗口号投递真实鼠标和 Unicode 键盘事件。未调用页面业务 handler、setData 或直接改 store。ScreenCaptureKit 仅捕获该窗口内的手机预览区域，没有拼接、合成或修改界面截图。

应用及测试源码仍与 `8b30a821651739a15f40fd50ad697ae8e2e9ac6e` 相同；本次只增加验收文档，复用同一构建、31 项定向测试和官方编译证据。

| Run | 验收结果 |
| --- | --- |
| `98718919ccad4a62ab31a42d1b699aa4` | 真实设置入口、中文手填、返回摘要和重开；线上天地图搜索并点击结果；选点地址/GCJ-02 坐标落盘并重开回显；补充楼层保留坐标；改成其他地址使旧坐标失效；清空移除地址及全部锚点，设置回到未设置。无服务夹具。 |
| `4eede67c663e4b0d91d17129123d4d9d` | 仅 getLocation 使用 auth deny 夹具，其余为真实 UI、线上搜索和独立读盘。点击定位后显示拒绝提示，原地址/坐标保留；之后仍可中文手填并保存。 |
| `f15f2a74e9ce4b9db7b39280a0289fef` | 冷恢复后的下一次热复用，重复真实搜索选点，等待地图加载并取得 `04-native-phone-map.png`。主 agent 检查原生像素，确认道路底图、中心点、地址、搜索框和定位按钮正常显示。 |

独立读盘从本次租约和项目 AppID 对应的 `WeappSimulator/WeappFileSystem/<user>/<AppID>/usr/xunju/state.json` 读取真实 JSON，保存 SHA-256 与设置快照；验证房源仍为空、模板/引导等其他设置保持不变。自动化 evaluate 中直接调用 wx 文件接口会触发 `Function has non-object prototype 'undefined' in instanceof check`，因此没有把该接口的失败当成业务写盘失败，也没有用内存状态代替独立读盘。

截图、原生操作脚本、状态与文件断言分别位于本工作树的 `apps/wechat/artifacts/workplace-location/ui-20261015/native-v4/`、`native-v5/` 和 `native-v6/`。核心断言为 `workplace-native-assertions.json`、`workplace-denial-assertions.json`；底图像素检查为 `map-native-review.json`。早期截图未显示底图细节；等待加载并恢复原生主窗口后，原生与同轮 SDK 截图均确认道路底图正常，最终地图视觉证据以加载后的原生手机区域截图为准。

以上三个最终 UI run 均正常结束为 passed/idle。最后一轮热复用保持恢复后的 PID `75128`，App/截图/冻结核验/清理和归还成功；这不代表旧 Page 元素查询脚本通过。

另保留 run `6bae3b642eb54296a21890a26ad31f16` 的回调前连接失败：自动化端口未打开，未执行 UI 断言，池按设计隔离。使用固定 runner 的 recover 命令，仅恢复本任务控制器已退出的 3 号槽，按锁/PID/profile 核验后冷启动；维护 receipt `99cc0197d1714507a3ac741dc506fdef`、原失败 runtime/receipt/profile 全部保留。没有修改微信安装、应用标识或其他槽位。

核心桌面交互通过不等于真机验收：真实 GPS、操作系统权限弹窗、原生地图拖动、冷 App 进程重启与用户视觉确认仍未覆盖。旧 Page.getElement 自动 E2E 的超时记录继续保留，不声称该脚本通过。PR 保留草稿，未合并、未发布。
