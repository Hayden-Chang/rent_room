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
