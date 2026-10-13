# 四步用户引导与 Figma 对齐

基线：2026-10-13 GitHub main `2ae6a7377293e6b0f4cd7f2503856c37015edcc6`。在 `codex/onboarding-figma` 隔离 worktree 实现。Figma Figwright `hop=e2e`；读取 `107:2833`、`107:3291` 及提示卡 `107:3232`、`107:3239`、`107:3246`、`107:3351`、演示行 `107:3360` 的实时结构、布局、文字、颜色和字体。

原实现只有底部说明 sheet，没有目标高亮、连接线、分层文案、左滑演示和设置重播。现在按四步原型实现锚定提示卡、60% 遮罩、白色高亮轮廓、统一“知道了”按钮；末步才显示可取消勾选的“不再自动显示”。保留最新清单导航布局，目标位置来自真实布局测量，不恢复旧原型背景。

前三步依次高亮房源、现场、询问签约。末步临时展开实际检查项，900ms 后用 450ms 动画显示问题、备注、影像图标，也支持左拖触发；仅确认按钮推进步骤。演示不会调用答案、问题、备注或媒体写入。完成后恢复分类折叠。设置“重新查看引导”不受自动引导关闭的影响；没有未归档房源时使用不落盘的临时清单。自定义模板使用可达字段兜底，确无字段时显示说明而不伪造检查项。偏好保存失败保留末步及原设置，允许重试。

## 自动验证

Node 24.21.0。构建前复制相同应用的锁定依赖到本任务独立 node_modules；未修改依赖或锁文件。最初离线安装缺少缓存，未把该环境失败计入产品回归。

新增回归先在未修改的基线构建上执行：

- `replays from settings even when automatic onboarding is disabled`：期望步骤 1，实际 0。
- `expands a real checklist item on step four without changing saved records`：步骤 4 没有展开的 field。
- `keeps step four open when opting out cannot be saved and allows retry`：保存失败仍结束为步骤 0，期望保留步骤 4。

三项均因对应产品行为失败，修复后通过。原始记录：`apps/wechat/artifacts/onboarding/before.log`。这轮前置失败使用 Node 25.9.0，最终验证使用 Node 24.21.0。

从 `apps/wechat` 执行（node 指向 Node 24.21.0）：

```sh
node scripts/build.mjs
node node_modules/vitest/vitest.mjs run tests/onboarding.test.js tests/onboarding-target.test.js tests/runtime.test.js tests/detail-navigation.test.js tests/detail-filter.test.js
node scripts/check.mjs
```

29 项通过。新增两文件共 12 项覆盖重播、无房源、四步推进、动画时序、手动左拖、保存失败重试、取消勾选、普通进入/自动关闭、隐藏/卸载取消定时器、折叠恢复与数据保留、自定义/空模板。既有 runtime 覆盖构建后的 Page 生命周期与共享 store；detail-navigation 和 detail-filter 覆盖修改生命周期及详情页后的切页/筛选状态。没有运行全量测试。官方 wcc 8 文件、wcsc 6 文件通过。日志：`artifacts/onboarding/after-final.log`、`artifacts/compile-result.json`。

VM/handler 测试只证明逻辑边界，不等于真实点击、手势或像素验收。真实截图、用户视觉批准和真机手势验收单独记录；没有批准前不得合并或发布。

## 最终提交与界面验收限制

产品与测试提交：`eba1d982550f6b91fa72b110a1283fc8c8260629`。29 项通过的工作树与该提交的产品源码、测试、构建配置、资源完全相同；提交只固定已有文件，随后没有改动上述输入。官方编译对应同一输入。

实际开发者工具采用实验实例池，使用独立 profile 和冻结工程，不改用户业务缓存：

- run `2b28ce17060c464189949cba9e4005c3`：App/Page 就绪，但截图脚本错误地用 navigateTo 进入 Tab 设置页，未到达被测引导；属于测试前置条件错误，不是产品失败。该冻结快照早于最终图标尺寸调整，不能作为最终画面证据。
- 修正脚本为 switchTab 并断言真实路由后，run `50267fc651a648908335aa80775728b3`：冻结提交 `eba1d98`，snapshot `c4e811bcc3d6665951887ec01ac5f28a5b88682b351240c946c7ef433adf00ac`；App Service health timeout，未进入测试回调，没有实际四步截图。冷启动基础设施仍处于实验状态。
- 原开发者工具窗口当前运行另一个任务 `media-captions`，只读检查后未切换工程、点击控件或抢占其会话。

上述 run 的原始 receipt、health/test 日志保留在本机 `/Volumes/mac2/codex-builds/wechat-instance-pool/runs/<runId>/`；该目录含私有运行 profile，不上传整目录。Figma 原型导出位于本任务 `apps/wechat/artifacts/onboarding/figma/`，不是应用运行截图。

结论：逻辑及官方编译通过，真实视觉、点击/拖动、安全区与大字体验收未完成，禁止宣称 merge-ready。尚未合并或发布。自动审批拒绝把源码推送到 `Hayden-Chang/rent_room`，明确要求用户授权该外部目的地后才能推送并创建 PR；没有改用其他方式绕过。

## 真机反馈：末步相机图标不可见

用户在扫码验收后指出第 4 步少一枚图标。根因是引导复用了实际左滑菜单的白色 `swipe-camera.png`，而演示行背景是白色；菜单中的该图标原本显示在紫色按钮上。实时 Figma `161:66589` 的相机图形为 `#667187`、22×22。直接从子节点 `I161:66589;161:5748` 导出 3× PNG，新增仅供引导使用的 `coach-media.png`，保留实际左滑菜单图标及行为。

新增 `onboarding-icons.test.js` 解码页面实际引用的三张 PNG，与白底做 alpha 合成并计算对比度。修复前相机满足 3:1 对比度的像素比例为 0，按预期失败；换成原型素材后通过。PNG 解码使用固定 devDependency `pngjs@7.0.0`，不进入业务包。

Node 24.21.0 执行 `vitest run tests/onboarding-icons.test.js tests/onboarding.test.js tests/onboarding-target.test.js`：13 项通过；官方 wcc 8 文件、wcsc 6 文件通过。原始失败和修复后日志位于 `apps/wechat/artifacts/onboarding/icon-fix/`。本轮仅改变引导媒体素材/样式与测试依赖，未改变 Page 生命周期、导航、筛选或持久化逻辑；相关既有测试证据保持等价。像素测试证明素材可见，不替代用户真机视觉确认。
